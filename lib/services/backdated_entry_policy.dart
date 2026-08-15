class BackdatedEntryPolicy {
  const BackdatedEntryPolicy._();

  /// Teacher-facing grace period: today plus the previous three calendar days.
  static const int maxBackdateDays = 3;

  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static DateTime earliestAllowed(DateTime now) =>
      dateOnly(now).subtract(const Duration(days: maxBackdateDays));

  static bool isAllowed(DateTime value, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    final target = dateOnly(value);
    return !target.isAfter(today) && !target.isBefore(earliestAllowed(today));
  }

  static int daysAgo(DateTime value, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    return today.difference(dateOnly(value)).inDays;
  }
}
