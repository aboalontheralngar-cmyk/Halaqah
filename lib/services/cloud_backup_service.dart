import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'audit_log_service.dart';
import 'backup_service.dart';
import 'database_service.dart';

class CloudBackupEntry {
  final String name;
  final String remotePath;

  const CloudBackupEntry({required this.name, required this.remotePath});
}

class CloudBackupService {
  CloudBackupService({
    SupabaseClient? client,
    BackupService? backupService,
    DatabaseService? database,
  })  : _client = client ?? Supabase.instance.client,
        _backup = backupService ?? BackupService(),
        _database = database ?? DatabaseService();

  static const String bucket = 'halaqah-backups';
  final SupabaseClient _client;
  final BackupService _backup;
  final DatabaseService _database;
  final AuditLogService _audit = AuditLogService();

  Future<CloudBackupEntry> createAndUpload({int retentionCount = 30}) async {
    final localPath = await _backup.exportBackup();
    return uploadExisting(localPath, retentionCount: retentionCount);
  }

  Future<CloudBackupEntry> uploadExisting(
    String localPath, {
    int retentionCount = 30,
  }) async {
    final scope = await _scope();
    final file = File(localPath);
    if (!await file.exists() || !file.path.endsWith('.halaqah')) {
      throw FileSystemException('ملف النسخة المشفرة غير موجود');
    }
    final fileName = file.path.split(Platform.pathSeparator).last;
    final remotePath = '${scope.prefix}/$fileName';
    try {
      await _client.storage.from(bucket).upload(
            remotePath,
            file,
            fileOptions: const FileOptions(
              cacheControl: 'no-store',
              upsert: false,
              contentType: 'application/octet-stream',
            ),
          );
      await _record(
        eventType: 'backup.cloud_uploaded',
        entityId: remotePath,
        centerId: scope.centerId,
        halaqaId: scope.halaqaId,
      );
      await _prune(scope, retentionCount);
      return CloudBackupEntry(name: fileName, remotePath: remotePath);
    } catch (error) {
      await _record(
        eventType: 'backup.cloud_upload_failed',
        entityId: remotePath,
        centerId: scope.centerId,
        halaqaId: scope.halaqaId,
        outcome: 'failure',
        details: <String, dynamic>{'error_type': error.runtimeType.toString()},
      );
      rethrow;
    }
  }

  /// Lists every encrypted backup owned by the signed-in account.
  ///
  /// Backups are normally stored under `<user>/<center>/<file>`. After an
  /// Android uninstall the local `sync_center_id` is gone, so limiting the
  /// listing to the current local center can make a perfectly valid disaster
  /// recovery backup appear to be missing. Recovery therefore discovers all
  /// center folders below the authenticated user's private root and keeps the
  /// current center first when it is known.
  Future<List<CloudBackupEntry>> listBackups() async {
    final userId = _authenticatedUserId();
    final storage = _client.storage.from(bucket);
    final entriesByPath = <String, CloudBackupEntry>{};

    Future<void> collectPrefix(String prefix) async {
      final objects = await storage.list(path: prefix);
      for (final item in objects) {
        if (!item.name.endsWith('.halaqah')) continue;
        final remotePath = '$prefix/${item.name}';
        entriesByPath[remotePath] = CloudBackupEntry(
          name: item.name,
          remotePath: remotePath,
        );
      }
    }

    final configuredCenter =
        (await _database.getSetting('sync_center_id'))?.trim() ?? '';
    if (configuredCenter.isNotEmpty) {
      try {
        await collectPrefix('$userId/$configuredCenter');
      } catch (_) {
        // Recovery discovery below is the fallback for stale/missing scope.
      }
    }

    try {
      final rootObjects = await storage.list(path: userId);
      for (final item in rootObjects) {
        final childName = item.name.trim();
        if (childName.isEmpty) continue;

        // Older/manual layouts may have placed a backup directly below the
        // user root. Keep supporting them.
        if (childName.endsWith('.halaqah')) {
          final remotePath = '$userId/$childName';
          entriesByPath[remotePath] = CloudBackupEntry(
            name: childName,
            remotePath: remotePath,
          );
          continue;
        }

        try {
          await collectPrefix('$userId/$childName');
        } catch (_) {
          // Ignore an unrelated/non-folder object and continue discovering
          // other recovery folders owned by this account.
        }
      }
    } catch (_) {
      // If the current scoped folder was readable, keep those entries rather
      // than turning a recoverable backup into a hard failure.
      if (entriesByPath.isEmpty) rethrow;
    }

    final entries = entriesByPath.values.toList()
      ..sort((a, b) => b.name.compareTo(a.name));
    return entries;
  }

  Future<void> _prune(_CloudScope scope, int retentionCount) async {
    final keep = retentionCount.clamp(3, 90).toInt();
    final objects = await _client.storage.from(bucket).list(path: scope.prefix);
    final names = objects
        .where((item) => item.name.endsWith('.halaqah'))
        .map((item) => item.name)
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final oldPaths = names
        .skip(keep)
        .map((name) => '${scope.prefix}/$name')
        .toList();
    if (oldPaths.isEmpty) return;
    await _client.storage.from(bucket).remove(oldPaths);
    await _record(
      eventType: 'backup.cloud_pruned',
      entityId: scope.prefix,
      centerId: scope.centerId,
      halaqaId: scope.halaqaId,
      details: <String, dynamic>{'deleted_count': oldPaths.length},
    );
  }

  Future<String> download(CloudBackupEntry entry) async {
    final userId = _authenticatedUserId();
    _validateEntryUserScope(entry, userId);
    final scope = await _scope();
    final bytes = await _client.storage.from(bucket).download(entry.remotePath);
    final directory = await getApplicationDocumentsDirectory();
    final safeName = _safeFileName(entry.name);
    final localFile = File('${directory.path}/$safeName');
    await localFile.writeAsBytes(bytes, flush: true);
    await _record(
      eventType: 'backup.cloud_downloaded',
      entityId: entry.remotePath,
      centerId: scope.centerId,
      halaqaId: scope.halaqaId,
    );
    return localFile.path;
  }

  Future<void> delete(CloudBackupEntry entry) async {
    final userId = _authenticatedUserId();
    _validateEntryUserScope(entry, userId);
    final scope = await _scope();
    await _client.storage.from(bucket).remove(<String>[entry.remotePath]);
    await _record(
      eventType: 'backup.cloud_deleted',
      entityId: entry.remotePath,
      centerId: scope.centerId,
      halaqaId: scope.halaqaId,
    );
  }

  Future<_CloudScope> _scope() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يلزم تسجيل الدخول قبل استخدام النسخ السحابي');
    }
    final centerId = await _database.getSetting('sync_center_id');
    final halaqaId = await _database.getSetting('sync_halaqah_id');
    final normalizedCenter = centerId?.isNotEmpty == true ? centerId! : 'unassigned';
    return _CloudScope(
      centerId: centerId?.isNotEmpty == true ? centerId : null,
      halaqaId: halaqaId?.isNotEmpty == true ? halaqaId : null,
      prefix: '${user.id}/$normalizedCenter',
    );
  }

  String _authenticatedUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('يلزم تسجيل الدخول قبل استخدام النسخ السحابي');
    }
    return user.id;
  }

  void _validateEntryUserScope(CloudBackupEntry entry, String userId) {
    if (!entry.remotePath.startsWith('$userId/') ||
        entry.name.contains('/') ||
        entry.name.contains(r'\')) {
      throw const FormatException('مسار النسخة السحابية غير صالح');
    }
  }

  String _safeFileName(String name) {
    final normalized = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    if (!normalized.endsWith('.halaqah')) {
      throw const FormatException('امتداد النسخة السحابية غير مدعوم');
    }
    return normalized;
  }

  Future<void> _record({
    required String eventType,
    required String entityId,
    String? centerId,
    String? halaqaId,
    String outcome = 'success',
    Map<String, dynamic> details = const <String, dynamic>{},
  }) async {
    await _audit.record(
      eventType: eventType,
      entityType: 'backup',
      entityId: entityId,
      outcome: outcome,
      details: details,
    );
    try {
      await _client.rpc(
        'write_audit_event',
        params: <String, dynamic>{
          'p_event_type': eventType,
          'p_entity_type': 'backup',
          'p_entity_id': null,
          'p_center_id': centerId,
          'p_halaqa_id': halaqaId,
          'p_outcome': outcome,
          'p_metadata': <String, dynamic>{
            'object_path': entityId,
            ...details,
          },
        },
      );
    } catch (_) {
      // The local audit record is authoritative while the P6.2 migration has
      // not yet been applied. Cloud backup itself must not be rolled back.
    }
  }
}

class _CloudScope {
  final String prefix;
  final String? centerId;
  final String? halaqaId;

  const _CloudScope({
    required this.prefix,
    this.centerId,
    this.halaqaId,
  });
}
