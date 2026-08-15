import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/student.dart';

void main() {
  test('student display code is stable and separate from database and QR ids', () {
    final student = Student(
      id: 'database-row-secret-id',
      name: 'طالب الاختبار',
      qrCode: 'a1b2-c3d4-e5f6-7890',
      studentCode: '12ab34cd56ef78ab90cd',
    );

    expect(student.displayCode, 'HAL-12AB3-4CD56-EF78A-B90CD');
    expect(student.displayCode, isNot(contains(student.id)));
    expect(student.displayCode, isNot(contains('A1B2-C3D4')));
  });

  test('student code safely migrates legacy rows without a public code', () {
    final student = Student(name: 'طالب قديم', qrCode: 'ab-12');

    expect(student.displayCode, 'HAL-AB120-00000-00000-00000');
  });
}
