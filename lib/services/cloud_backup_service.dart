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

  Future<List<CloudBackupEntry>> listBackups() async {
    final scope = await _scope();
    final objects = await _client.storage.from(bucket).list(path: scope.prefix);
    final entries = objects
        .where((item) => item.name.endsWith('.halaqah'))
        .map(
          (item) => CloudBackupEntry(
            name: item.name,
            remotePath: '${scope.prefix}/${item.name}',
          ),
        )
        .toList()
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
    final scope = await _scope();
    _validateEntryScope(entry, scope.prefix);
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
    final scope = await _scope();
    _validateEntryScope(entry, scope.prefix);
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

  void _validateEntryScope(CloudBackupEntry entry, String prefix) {
    if (!entry.remotePath.startsWith('$prefix/') ||
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
