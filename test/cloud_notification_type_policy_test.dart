import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/sync/cloud_notification_type_policy.dart';

void main() {
  test('Build83 cloud notification policy preserves current app types', () {
    for (final type in cloudNotificationTypes) {
      expect(normalizeCloudNotificationType(type), type);
    }
  });

  test('legacy notification fallback cannot violate the old cloud CHECK', () {
    for (final type in cloudNotificationTypes) {
      expect(
        legacyCloudNotificationTypes,
        contains(legacyCompatibleCloudNotificationType(type)),
      );
    }
    expect(normalizeCloudNotificationType('future_type'), 'general');
  });
}
