import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/backup_policy_service.dart';

void main() {
  test('automatic backup runs once on the first launch after schedule', () {
    final now = DateTime(2026, 7, 12, 8);
    expect(
      BackupPolicyService.isAutomaticBackupDue(
        enabled: true,
        scheduledHour: 2,
        now: now,
        lastAutomaticBackup: DateTime(2026, 7, 11, 8),
      ),
      isTrue,
    );
    expect(
      BackupPolicyService.isAutomaticBackupDue(
        enabled: true,
        scheduledHour: 2,
        now: now,
        lastAutomaticBackup: DateTime(2026, 7, 12, 3),
      ),
      isFalse,
    );
  });

  test('automatic backup waits until the configured hour', () {
    expect(
      BackupPolicyService.isAutomaticBackupDue(
        enabled: true,
        scheduledHour: 2,
        now: DateTime(2026, 7, 12, 1, 59),
      ),
      isFalse,
    );
  });

  test('reminder respects both backup and reminder intervals', () {
    final now = DateTime(2026, 7, 12, 8);
    expect(
      BackupPolicyService.isReminderDue(
        enabled: true,
        intervalDays: 3,
        now: now,
        lastBackup: DateTime(2026, 7, 8),
        lastReminder: DateTime(2026, 7, 9),
      ),
      isTrue,
    );
    expect(
      BackupPolicyService.isReminderDue(
        enabled: true,
        intervalDays: 3,
        now: now,
        lastBackup: DateTime(2026, 7, 11),
      ),
      isFalse,
    );
  });
}
