import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../models/settings.dart';
import 'audit_log_service.dart';
import 'backup_crypto_service.dart';
import 'backup_passphrase_store.dart';
import 'backup_policy_service.dart';
import 'database_service.dart';

class BackupPassphraseRequiredException implements Exception {
  const BackupPassphraseRequiredException();

  @override
  String toString() =>
      'يلزم إعداد عبارة حماية للنسخ الاحتياطية قبل تنفيذ العملية';
}

class AutomaticBackupResult {
  final bool attempted;
  final bool succeeded;
  final String? path;
  final String? error;

  const AutomaticBackupResult({
    required this.attempted,
    required this.succeeded,
    this.path,
    this.error,
  });
}

class BackupFileInspection {
  final bool encrypted;
  final bool legacy;
  final String? payloadVersion;
  final DateTime? createdAt;

  const BackupFileInspection({
    required this.encrypted,
    required this.legacy,
    this.payloadVersion,
    this.createdAt,
  });
}

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  static const String _payloadVersion = '3.0';
  static const int _maximumBackupBytes = 100 * 1024 * 1024;

  final DatabaseService _db = DatabaseService();
  final BackupCryptoService _crypto = const BackupCryptoService();
  final BackupPassphraseStore passphrases = BackupPassphraseStore();
  final AuditLogService _audit = AuditLogService();

  Future<String> exportBackup({
    bool automatic = false,
    String? passphrase,
  }) async {
    final effectivePassphrase = passphrase ?? await passphrases.read();
    if (effectivePassphrase == null || effectivePassphrase.isEmpty) {
      throw const BackupPassphraseRequiredException();
    }

    try {
      final tables = await _db.exportBackupTables();
      final createdAt = DateTime.now();
      final integrityDigest = sha256
          .convert(utf8.encode(jsonEncode(tables)))
          .toString();
      final payload = <String, dynamic>{
        'version': _payloadVersion,
        'date': createdAt.toUtc().toIso8601String(),
        'tables': tables,
        'integrity': <String, dynamic>{
          'algorithm': 'SHA-256',
          'digest': integrityDigest,
        },
      };
      final envelope = await _crypto.encrypt(
        clearText: const JsonEncoder.withIndent('  ').convert(payload),
        passphrase: effectivePassphrase,
        payloadVersion: _payloadVersion,
        createdAt: createdAt,
      );

      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss_SSS').format(createdAt);
      final kind = automatic ? 'auto_' : '';
      final filePath =
          '${directory.path}/halaqah_backup_${kind}$timestamp.halaqah';
      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope),
        flush: true,
      );

      final now = createdAt.toIso8601String();
      await _db.saveSetting('last_backup_at', now);
      if (automatic) await _db.saveSetting('last_automatic_backup_at', now);
      await _audit.record(
        eventType: automatic ? 'backup.auto_created' : 'backup.created',
        entityType: 'backup',
        entityId: file.path.split(Platform.pathSeparator).last,
        details: <String, dynamic>{
          'encrypted': true,
          'payload_version': _payloadVersion,
        },
      );
      return filePath;
    } catch (error) {
      await _audit.record(
        eventType: automatic ? 'backup.auto_failed' : 'backup.create_failed',
        entityType: 'backup',
        outcome: 'failure',
        details: <String, dynamic>{'error_type': error.runtimeType.toString()},
      );
      rethrow;
    }
  }

  Future<AutomaticBackupResult> performAutomaticBackupIfDue({
    HalaqahSettings? settings,
    DateTime? now,
  }) async {
    final currentSettings = settings ?? await _db.getSettings();
    final currentTime = now ?? DateTime.now();
    final lastRaw = await _db.getSetting('last_automatic_backup_at');
    final last = DateTime.tryParse(lastRaw ?? '');
    final due = BackupPolicyService.isAutomaticBackupDue(
      enabled: currentSettings.automaticBackupEnabled,
      scheduledHour: currentSettings.automaticBackupHour,
      now: currentTime,
      lastAutomaticBackup: last,
    );
    if (!due) {
      return const AutomaticBackupResult(attempted: false, succeeded: false);
    }
    try {
      final path = await exportBackup(automatic: true);
      await _pruneAutomaticBackups(
        currentSettings.automaticBackupRetentionCount,
      );
      await _db.saveSetting('last_automatic_backup_error', '');
      return AutomaticBackupResult(
        attempted: true,
        succeeded: true,
        path: path,
      );
    } catch (error) {
      await _db.saveSetting('last_automatic_backup_error', error.toString());
      return AutomaticBackupResult(
        attempted: true,
        succeeded: false,
        error: error.toString(),
      );
    }
  }

  Future<bool> shouldShowReminder({
    HalaqahSettings? settings,
    DateTime? now,
  }) async {
    final currentSettings = settings ?? await _db.getSettings();
    final currentTime = now ?? DateTime.now();
    final lastBackup = DateTime.tryParse(
      await _db.getSetting('last_backup_at') ?? '',
    );
    final lastReminder = DateTime.tryParse(
      await _db.getSetting('last_backup_reminder_at') ?? '',
    );
    return BackupPolicyService.isReminderDue(
      enabled: currentSettings.backupReminderEnabled,
      intervalDays: currentSettings.backupReminderIntervalDays,
      now: currentTime,
      lastBackup: lastBackup,
      lastReminder: lastReminder,
    );
  }

  Future<void> markReminderShown({DateTime? now}) => _db.saveSetting(
        'last_backup_reminder_at',
        (now ?? DateTime.now()).toIso8601String(),
      );

  Future<void> _pruneAutomaticBackups(int retentionCount) async {
    final keep = retentionCount.clamp(1, 90).toInt();
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('halaqah_backup_auto_'))
        .where(_isSupportedBackupFile)
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(keep)) {
      await file.delete();
      await _audit.record(
        eventType: 'backup.pruned',
        entityType: 'backup',
        entityId: file.path.split(Platform.pathSeparator).last,
      );
    }
  }

  Future<bool> importBackup(
    String filePath, {
    String? passphrase,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('ملف النسخة الاحتياطية غير موجود');
    }
    if (await file.length() > _maximumBackupBytes) {
      throw const FormatException('حجم ملف النسخة أكبر من الحد المسموح');
    }

    try {
      final encoded = await file.readAsString();
      final root = _decodeJsonObject(encoded);
      Map<String, dynamic> backup;
      if (_crypto.isEncryptedEnvelope(root)) {
        final effectivePassphrase = passphrase ?? await passphrases.read();
        if (effectivePassphrase == null || effectivePassphrase.isEmpty) {
          throw const BackupPassphraseRequiredException();
        }
        final clearText = await _crypto.decrypt(
          envelope: root,
          passphrase: effectivePassphrase,
        );
        backup = _decodeJsonObject(clearText);
      } else {
        backup = root;
      }

      _validatePayload(backup);
      await _db.restoreFromBackup(backup);
      await _db.saveSetting(
        'last_restore_at',
        DateTime.now().toIso8601String(),
      );
      await _audit.record(
        eventType: 'backup.restored',
        entityType: 'backup',
        entityId: file.path.split(Platform.pathSeparator).last,
        details: <String, dynamic>{
          'encrypted': _crypto.isEncryptedEnvelope(root),
          'payload_version': backup['version']?.toString(),
        },
      );
      return true;
    } catch (error) {
      await _audit.record(
        eventType: 'backup.restore_failed',
        entityType: 'backup',
        entityId: file.path.split(Platform.pathSeparator).last,
        outcome: 'failure',
        details: <String, dynamic>{'error_type': error.runtimeType.toString()},
      );
      rethrow;
    }
  }

  Future<BackupFileInspection> inspectBackup(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('ملف النسخة الاحتياطية غير موجود');
    }
    final root = _decodeJsonObject(await file.readAsString());
    if (_crypto.isEncryptedEnvelope(root)) {
      return BackupFileInspection(
        encrypted: true,
        legacy: false,
        payloadVersion: root['payload_version']?.toString(),
        createdAt: DateTime.tryParse(root['created_at']?.toString() ?? ''),
      );
    }
    return BackupFileInspection(
      encrypted: false,
      legacy: true,
      payloadVersion: root['version']?.toString(),
      createdAt: DateTime.tryParse(root['date']?.toString() ?? ''),
    );
  }

  Future<List<FileSystemEntity>> getBackupFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.contains('halaqah_backup_'))
        .where(_isSupportedBackupFile)
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  bool _isSupportedBackupFile(File file) =>
      file.path.endsWith('.halaqah') || file.path.endsWith('.json');

  Map<String, dynamic> _decodeJsonObject(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('ملف النسخة لا يحتوي على كائن صالح');
    }
    return Map<String, dynamic>.from(decoded);
  }

  void _validatePayload(Map<String, dynamic> backup) {
    final version = backup['version']?.toString();
    final hasTables = backup['tables'] is Map;
    final isModern = const <String>{'2.0', '2.1', _payloadVersion}
        .contains(version);
    final isLegacy = version != null && backup['students'] is List;
    if ((!isModern || !hasTables) && !isLegacy) {
      throw const FormatException('إصدار النسخة الاحتياطية غير مدعوم');
    }
    if (version == _payloadVersion) {
      final integrity = backup['integrity'];
      if (integrity is! Map ||
          integrity['algorithm'] != 'SHA-256' ||
          integrity['digest'] is! String) {
        throw const FormatException('بيانات تحقق النسخة الاحتياطية مفقودة');
      }
      final actual = sha256
          .convert(utf8.encode(jsonEncode(backup['tables'])))
          .toString();
      if (actual != integrity['digest']) {
        throw const FormatException('فشل التحقق من سلامة محتوى النسخة');
      }
    }
  }
}
