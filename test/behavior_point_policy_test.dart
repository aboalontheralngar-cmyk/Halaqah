import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/behavior_point_policy.dart';

void main() {
  test('accepts matching positive and negative signs', () {
    expect(
      BehaviorPointPolicy.validate(
        type: 'positive',
        points: 5,
        reason: 'زيادة عن المقرر',
        studentStatus: 'active',
      ),
      isNull,
    );
    expect(
      BehaviorPointPolicy.validate(
        type: 'negative',
        points: -3,
        reason: 'عدم لبس الثوب',
        studentStatus: 'active',
      ),
      isNull,
    );
  });

  test('rejects sign mismatch and archived students', () {
    expect(
      BehaviorPointPolicy.validate(
        type: 'negative',
        points: 3,
        reason: 'مخالفة',
        studentStatus: 'active',
      ),
      isNotNull,
    );
    expect(
      BehaviorPointPolicy.validate(
        type: 'positive',
        points: 3,
        reason: 'مكافأة',
        studentStatus: 'expelled',
      ),
      isNotNull,
    );
  });
}
