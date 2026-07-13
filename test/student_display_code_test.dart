import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/student.dart';

void main() {
  test('student display code is stable, short, and does not expose database id', () {
    final student = Student(
      id: 'database-row-secret-id',
      name: 'طالب الاختبار',
      qrCode: 'a1b2-c3d4-e5f6-7890',
    );

    expect(student.displayCode, 'HAL-A1B2C3D4');
    expect(student.displayCode, isNot(contains(student.id)));
  });

  test('student display code safely pads legacy short QR values', () {
    final student = Student(name: 'طالب قديم', qrCode: 'ab-12');

    expect(student.displayCode, 'HAL-AB120000');
  });
}
