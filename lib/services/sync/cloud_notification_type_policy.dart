const Set<String> cloudNotificationTypes = <String>{
  'low_performance',
  'repeated_absence',
  'plan_completed',
  'dismissal_warning',
  'general',
  'surah_completed',
  'consecutive_no_recitation',
  'student_expelled',
};

const Set<String> legacyCloudNotificationTypes = <String>{
  'low_performance',
  'repeated_absence',
  'plan_completed',
  'dismissal_warning',
  'general',
};

String normalizeCloudNotificationType(String value) {
  final normalized = value.trim();
  return cloudNotificationTypes.contains(normalized) ? normalized : 'general';
}

/// Compatibility bridge for databases that still carry the pre-Build83
/// notifications CHECK constraint. Build83 SQL expands the constraint, but a
/// stale deployment must not stop the whole device upload while it is being
/// upgraded.
String legacyCompatibleCloudNotificationType(String value) {
  final normalized = normalizeCloudNotificationType(value);
  if (legacyCloudNotificationTypes.contains(normalized)) return normalized;
  switch (normalized) {
    case 'consecutive_no_recitation':
      return 'low_performance';
    case 'student_expelled':
      return 'dismissal_warning';
    case 'surah_completed':
      return 'general';
    default:
      return 'general';
  }
}
