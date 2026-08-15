import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';

import '../models/settings.dart';
import 'backup_policy_service.dart';
import 'backup_service.dart';
import 'database_service.dart';

const String backgroundBackupUniqueName =
    'halaqah.automatic-backup.daily.v1';
const String backgroundBackupTaskName = 'halaqahAutomaticBackup';

/// Entry point used by Android WorkManager in its background Dart isolate.
@pragma('vm:entry-point')
void halaqahBackgroundCallbackDispatcher() {
  Workmanager().executeTask((taskName, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    if (taskName != backgroundBackupTaskName) return true;

    final database = DatabaseService();
    final workerTime = DateTime.now();
    try {
      final result = await BackupService().performAutomaticBackupIfDue(
        now: workerTime,
      );
      await database.saveSetting(
        'last_background_backup_worker_at',
        workerTime.toIso8601String(),
      );
      await database.saveSetting(
        'last_background_backup_worker_status',
        result.attempted
            ? (result.succeeded ? 'success' : 'failed')
            : 'not_due',
      );
      return !result.attempted || result.succeeded;
    } catch (error) {
      await database.saveSetting(
        'last_background_backup_worker_at',
        workerTime.toIso8601String(),
      );
      await database.saveSetting(
        'last_background_backup_worker_status',
        'failed',
      );
      await database.saveSetting(
        'last_automatic_backup_error',
        error.toString(),
      );
      return false;
    }
  });
}

/// Keeps the Android system task aligned with the user's backup settings.
class BackgroundBackupScheduler {
  BackgroundBackupScheduler._();

  static const String _scheduleSignatureKey =
      'background_backup_schedule_signature';
  static const String _schedulerErrorKey =
      'last_background_backup_scheduler_error';
  static const String _schedulerUpdatedAtKey =
      'last_background_backup_scheduler_updated_at';

  static bool _initialized = false;

  static Future<void> initializeAndSynchronize() async {
    if (!Platform.isAndroid) return;
    final database = DatabaseService();
    try {
      await Workmanager().initialize(halaqahBackgroundCallbackDispatcher);
      _initialized = true;
      await synchronize();
    } catch (error) {
      await database.saveSetting(_schedulerErrorKey, error.toString());
    }
  }

  static Future<bool> synchronize({HalaqahSettings? settings}) async {
    if (!Platform.isAndroid || !_initialized) return false;

    final database = DatabaseService();
    try {
      final currentSettings = settings ?? await database.getSettings();
      final manager = Workmanager();

      if (!currentSettings.automaticBackupEnabled) {
        await manager.cancelByUniqueName(backgroundBackupUniqueName);
        await database.saveSetting(_scheduleSignatureKey, 'disabled');
        await database.saveSetting(_schedulerErrorKey, '');
        return false;
      }

      final safeHour =
          currentSettings.automaticBackupHour.clamp(0, 23).toInt();
      final signature = 'daily:$safeHour:v1';
      final savedSignature = await database.getSetting(_scheduleSignatureKey);
      final isScheduled =
          await manager.isScheduledByUniqueName(backgroundBackupUniqueName);

      if (savedSignature == signature && isScheduled) {
        await database.saveSetting(_schedulerErrorKey, '');
        return true;
      }

      await manager.cancelByUniqueName(backgroundBackupUniqueName);
      final now = DateTime.now();
      await manager.registerPeriodicTask(
        backgroundBackupUniqueName,
        backgroundBackupTaskName,
        frequency: const Duration(hours: 24),
        initialDelay: BackupPolicyService.delayUntilNextScheduledHour(
          scheduledHour: safeHour,
          now: now,
        ),
        inputData: <String, dynamic>{'scheduledHour': safeHour},
        tag: 'halaqah.backup',
      );
      await database.saveSetting(_scheduleSignatureKey, signature);
      await database.saveSetting(
        _schedulerUpdatedAtKey,
        now.toIso8601String(),
      );
      await database.saveSetting(_schedulerErrorKey, '');
      return true;
    } catch (error) {
      await database.saveSetting(_schedulerErrorKey, error.toString());
      return false;
    }
  }
}
