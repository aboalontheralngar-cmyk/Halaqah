import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/student_hold.dart';

void main() {
  test('hold is active only inside its range', () {
    final hold = StudentHold(
      studentId: 'student-1',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 12),
      reason: 'مراجعة إدارية',
    );

    expect(hold.isActiveAt(DateTime(2026, 7, 9)), isFalse);
    expect(hold.isActiveAt(DateTime(2026, 7, 10)), isTrue);
    expect(hold.isActiveAt(DateTime(2026, 7, 12)), isTrue);
    expect(hold.isActiveAt(DateTime(2026, 7, 13)), isFalse);
  });

  test('ended hold remains visible historically but not after its end day', () {
    final hold = StudentHold(
      studentId: 'student-1',
      startDate: DateTime(2026, 7, 10),
      endDate: DateTime(2026, 7, 20),
      reason: 'مراجعة إدارية',
      endedAt: DateTime(2026, 7, 12, 15),
    );

    expect(hold.isActiveAt(DateTime(2026, 7, 11)), isTrue);
    expect(hold.isActiveAt(DateTime(2026, 7, 12)), isTrue);
    expect(hold.isActiveAt(DateTime(2026, 7, 13)), isFalse);
  });
}
