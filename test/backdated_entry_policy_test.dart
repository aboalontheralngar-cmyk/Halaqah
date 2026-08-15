import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/backdated_entry_policy.dart';

void main() {
  final now = DateTime(2026, 8, 12, 18, 0);

  test('allows today and exactly three previous calendar days', () {
    for (var days = 0; days <= 3; days++) {
      expect(
        BackdatedEntryPolicy.isAllowed(
          DateTime(2026, 8, 12).subtract(Duration(days: days)),
          now: now,
        ),
        isTrue,
      );
    }
  });

  test('rejects older than three days and future dates', () {
    expect(BackdatedEntryPolicy.isAllowed(DateTime(2026, 8, 8), now: now), isFalse);
    expect(BackdatedEntryPolicy.isAllowed(DateTime(2026, 8, 13), now: now), isFalse);
  });
}
