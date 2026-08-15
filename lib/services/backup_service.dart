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
import 'offline_exchange_policy.dart';

class BackupPassphraseRequiredException implements Exception {
  const BackupPassphraseRequiredException();

  @override
  String toString() =>
      'يلزم إعداد عبارة حماية للنسخ الاحتياطية قبل تنفيذ العملية';
}

class OfflineExchangePackageException implements Exception {
  final String message;

  const OfflineExchangePackageException(this.message);

  @override
  String toString() => message;
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

    return _exportEncryptedPackage(
      automatic: automatic,
      passphrase: effectivePassphrase,
      purpose: 'backup',
    );
  }

  Future<String> exportDeviceExchange({
    required String passphrase,
    DateTime? now,
  }) async {
    final createdAt = now ?? DateTime.now();
    return _exportEncryptedPackage(
      automatic: false,
      passphrase: passphrase,
      purpose: 'device_exchange',
      createdAt: createdAt,
      expiresAt: createdAt.add(OfflineExchangePolicy.validity),
    );
  }

  Future<String> _exportEncryptedPackage({
    required bool automatic,
    required String passphrase,
    required String purpose,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) async {
    final isExchange = purpose == 'device_exchange';
    try {
      final tables = isExchange
          ? await _db.exportDeviceExchangeTables()
          : await _db.exportBackupTables();
      final packageCreatedAt = createdAt ?? DateTime.now();
      final integrityDigest = sha256
          .convert(utf8.encode(jsonEncode(tables)))
          .toString();
      final payload = <String, dynamic>{
        'version': _payloadVersion,
        'purpose': purpose,
        'date': packageCreatedAt.toUtc().toIso8601String(),
        if (expiresAt != null)
          'expires_at': expiresAt.toUtc().toIso8601String(),
        'tables': tables,
        'integrity': <String, dynamic>{
          'algorithm': 'SHA-256',
          'digest': integrityDigest,
        },
      };
      final envelope = await _crypto.encrypt(
        clearText: const JsonEncoder.withIndent('  ').convert(payload),
        passphrase: passphrase,
        payloadVersion: _payloadVersion,
        createdAt: packageCreatedAt,
      );

      final directory = await getApplicationDocumentsDirectory();
      final timestamp =
          DateFormat('yyyy-MM-dd_HH-mm-ss_SSS').format(packageCreatedAt);
      final kind = isExchange
          ? 'exchange_'
          : automatic
              ? 'backup_auto_'
              : 'backup_';
      final filePath =
          '${directory.path}/halaqah_${kind}$timestamp.halaqah';
      final file = File(filePath);
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(envelope),
        flush: true,
      );

      final createdAtText = packageCreatedAt.toIso8601String();
      if (!isExchange) {
        await _db.saveSetting('last_backup_at', createdAtText);
        if (automatic) {
          await _db.saveSetting(
            'last_automatic_backup_at',
            createdAtText,
          );
        }
      }
      await _audit.record(
        eventType: isExchange
            ? 'offline_exchange.created'
            : automatic
                ? 'backup.auto_created'
                : 'backup.created',
        entityType: isExchange ? 'device_exchange' : 'backup',
        entityId: file.path.split(Platform.pathSeparator).last,
        details: <String, dynamic>{
          'encrypted': true,
          'payload_version': _payloadVersion,
          'purpose': purpose,
          if (expiresAt != null)
            'expires_at': expiresAt.toUtc().toIso8601String(),
        },
      );
      return filePath;
    } catch (error) {
      await _audit.record(
        eventType: isExchange
            ? 'offline_exchange.create_failed'
            : automatic
                ? 'backup.auto_failed'
                : 'backup.create_failed',
        entityType: isExchange ? 'device_exchange' : 'backup',
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

  Future<String> createPreSyncBackup() async {
    final settings = await _db.getSettings();
    final path = await exportBackup(automatic: true);
    await _pruneAutomaticBackups(settings.automaticBackupRetentionCount);
    return path;
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

  Future<Map<String, int>> mergeBackup(
    String filePath, {
    required String passphrase,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('ملف التبادل غير موجود');
    }
    if (await file.length() > _maximumBackupBytes) {
      throw const FormatException('حجم ملف التبادل أكبر من الحد المسموح');
    }
    try {
      final root = _decodeJsonObject(await file.readAsString());
      if (!_crypto.isEncryptedEnvelope(root)) {
        throw const FormatException(
          'تبادل الأجهزة يقبل الملفات المشفرة الحديثة فقط',
        );
      }
      final clearText = await _crypto.decrypt(
        envelope: root,
        passphrase: passphrase,
      );
      final backup = _decodeJsonObject(clearText);
      _validatePayload(backup);
      if (backup['purpose'] != 'device_exchange') {
        throw const OfflineExchangePackageException(
          'هذا الملف نسخة احتياطية وليس حزمة تبادل بين الأجهزة',
        );
      }
      final createdAt = DateTime.tryParse(
        backup['date']?.toString() ?? '',
      );
      final expiresAt = DateTime.tryParse(
        backup['expires_at']?.toString() ?? '',
      );
      if (createdAt == null ||
          expiresAt == null ||
          !OfflineExchangePolicy.isWithinValidityWindow(
            createdAt: createdAt,
            expiresAt: expiresAt,
          )) {
        throw const OfflineExchangePackageException(
          'انتهت صلاحية حزمة التبادل؛ أنشئ حزمة جديدة من الجهاز المرسل',
        );
      }
      final result = await _db.mergeFromBackup(backup);
      await _audit.record(
        eventType: 'offline_exchange.merged',
        entityType: 'device_exchange',
        entityId: file.path.split(Platform.pathSeparator).last,
        details: result,
      );
      return result;
    } catch (error) {
      await _audit.record(
        eventType: 'offline_exchange.failed',
        entityType: 'device_exchange',
        entityId: file.path.split(Platform.pathSeparator).last,
        outcome: 'failure',
        details: <String, dynamic>{
          'error_type': error.runtimeType.toString(),
        },
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
