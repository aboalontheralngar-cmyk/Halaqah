class BackupPolicyService {
  const BackupPolicyService._();

  static bool isAutomaticBackupDue({
    required bool enabled,
    required int scheduledHour,
    required DateTime now,
    DateTime? lastAutomaticBackup,
  }) {
    final safeHour = scheduledHour.clamp(0, 23).toInt();
    if (!enabled || now.hour < safeHour) return false;
    if (lastAutomaticBackup == null) return true;
    return !_sameDay(now, lastAutomaticBackup);
  }

  static bool isReminderDue({
    required bool enabled,
    required int intervalDays,
    required DateTime now,
    DateTime? lastBackup,
    DateTime? lastReminder,
  }) {
    if (!enabled) return false;
    final safeInterval = intervalDays.clamp(1, 30).toInt();
    if (lastBackup != null && now.difference(lastBackup).inDays < safeInterval) {
      return false;
    }
    if (lastReminder != null && now.difference(lastReminder).inDays < safeInterval) {
      return false;
    }
    return true;
  }

  static bool _sameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
