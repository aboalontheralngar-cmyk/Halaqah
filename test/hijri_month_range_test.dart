import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/utils/helpers.dart';

void main() {
  test('recent Hijri month dropdown values are stable and unique', () {
    final ranges = Helpers.recentHijriMonths(
      anchor: DateTime(2026, 7, 22),
      count: 24,
    );
    final keys = ranges.map((range) => range.key).toList();

    expect(ranges, hasLength(24));
    expect(keys.toSet(), hasLength(keys.length));
    expect(
      ranges.every((range) => !range.endDate.isBefore(range.startDate)),
      isTrue,
    );
  });
}
