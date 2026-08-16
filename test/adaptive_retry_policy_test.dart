import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/sync/adaptive_retry_policy.dart';

void main() {
  group('AdaptiveRetryPolicy', () {
    test('backs off exponentially up to maximum delay', () {
      final policy = AdaptiveRetryPolicy(
        initialDelay: const Duration(seconds: 10),
        maximumDelay: const Duration(seconds: 40),
      );

      expect(policy.takeNextDelay(), const Duration(seconds: 10));
      expect(policy.takeNextDelay(), const Duration(seconds: 20));
      expect(policy.takeNextDelay(), const Duration(seconds: 40));
      expect(policy.takeNextDelay(), const Duration(seconds: 40));
    });

    test('reset returns to the initial delay', () {
      final policy = AdaptiveRetryPolicy(
        initialDelay: const Duration(seconds: 15),
        maximumDelay: const Duration(minutes: 2),
      );

      policy.takeNextDelay();
      policy.takeNextDelay();
      policy.reset();

      expect(policy.nextDelay, const Duration(seconds: 15));
      expect(policy.takeNextDelay(), const Duration(seconds: 15));
    });
  });
}
