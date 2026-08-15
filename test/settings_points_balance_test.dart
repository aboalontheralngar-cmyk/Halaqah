import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/settings.dart';

void main() {
  test('absence remains worse than combined common daily penalties', () {
    final settings = HalaqahSettings(pointsConfig: {
      'late_penalty': -2,
      'incomplete_penalty': -3,
      'no_thobe': -3,
      'unexcused_absence': -2,
    });
    final combined = settings.pointsConfig['late_penalty']!.abs() +
        settings.pointsConfig['incomplete_penalty']!.abs() +
        settings.pointsConfig['no_thobe']!.abs();
    expect(settings.pointsConfig['unexcused_absence']!.abs(), greaterThan(combined));
  });
}
