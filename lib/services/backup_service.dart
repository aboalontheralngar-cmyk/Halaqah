import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'database_service.dart';
import 'backup_policy_service.dart';
import '../models/settings.dart';

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

class BackupService {
  static final BackupService _instance = BackupService._internal();
  factory BackupService() => _instance;
  BackupService._internal();

  final DatabaseService _db = DatabaseService();

  Future<String> exportBackup({bool automatic = false}) async {
    final tables = await _db.exportBackupTables();
    
    final backup = {
      'version': '2.0',
      'date': DateTime.now().toIso8601String(),
      'tables': tables,
    };
    
    final jsonString = const JsonEncoder.withIndent('  ').convert(backup);
    
    final directory = await getApplicationDocumentsDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final kind = automatic ? 'auto_' : '';
    final filePath = '${directory.path}/halaqah_backup_${kind}$timestamp.json';
    
    final file = File(filePath);
    await file.writeAsString(jsonString);
    final now = DateTime.now().toIso8601String();
    await _db.saveSetting('last_backup_at', now);
    if (automatic) await _db.saveSetting('last_automatic_backup_at', now);
    
    return filePath;
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
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final file in files.skip(keep)) {
      await file.delete();
    }
  }

  Future<bool> importBackup(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return false;

      final jsonString = await file.readAsString();
      final backup = json.decode(jsonString) as Map<String, dynamic>;

      // Validate backup structure before touching the database
      final isVersion2 = backup['version'] == '2.0' && backup['tables'] is Map;
      final isLegacyVersion = backup['version'] != null && backup['students'] is List;
      if (!isVersion2 && !isLegacyVersion) {
        return false;
      }

      await _db.restoreFromBackup(backup);

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<FileSystemEntity>> getBackupFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final files = directory.listSync()
        .where((f) => f.path.contains('halaqah_backup_') && f.path.endsWith('.json'))
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }
}
