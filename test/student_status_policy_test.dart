import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/student_status_policy.dart';

void main() {
  test('separates operational and archived statuses', () {
    expect(StudentStatusPolicy.isArchived('active'), isFalse);
    expect(StudentStatusPolicy.isArchived('suspended'), isFalse);
    expect(StudentStatusPolicy.isArchived('expelled'), isTrue);
    expect(StudentStatusPolicy.isArchived('graduated'), isTrue);
    expect(StudentStatusPolicy.isArchived('inactive'), isTrue);
  });

  test('requires a real transition and a documented reason', () {
    expect(
      StudentStatusPolicy.validateTransition(
        previousStatus: 'active',
        newStatus: 'expelled',
        reason: 'تجاوز حد الغياب',
      ),
      isNull,
    );
    expect(
      StudentStatusPolicy.validateTransition(
        previousStatus: 'active',
        newStatus: 'active',
        reason: 'لا تغيير',
      ),
      isNotNull,
    );
    expect(
      StudentStatusPolicy.validateTransition(
        previousStatus: 'expelled',
        newStatus: 'active',
        reason: '  ',
      ),
      isNotNull,
    );
  });
}
