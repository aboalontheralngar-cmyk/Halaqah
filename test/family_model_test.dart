import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/family.dart';
import 'package:halaqah_teacher/models/family_guardian.dart';
import 'package:halaqah_teacher/models/student.dart';

void main() {
  test('family has a stable short code independent from its name', () {
    final family = Family(
      id: '1234abcd-5678-90ef-1234-567890abcdef',
      name: 'عائلة متشابهة',
      referenceName: 'الجد الأول',
    );

    expect(family.displayCode, 'FAM-1234ABCD');
    expect(family.toMap()['reference_name'], 'الجد الأول');
  });

  test('family prefers the global cloud code and preserves it in SQLite maps', () {
    final family = Family(
      id: '1234abcd-5678-90ef-1234-567890abcdef',
      name: 'عائلة البوابة',
      familyCode: 'A1B2C3D4E5F60718293A',
    );

    expect(family.displayCode, 'FAM-A1B2C-3D4E5-F6071-8293A');
    expect(family.toMap()['family_code'], 'A1B2C3D4E5F60718293A');
    expect(Family.fromMap(family.toMap()).familyCode, family.familyCode);
  });

  test('guardian preserves primary contact and relationship contract', () {
    final guardian = FamilyGuardian(
      id: 'guardian-1',
      familyId: 'family-1',
      name: 'ولي الاختبار',
      phone: '777000000',
      relationship: 'grandfather',
      isPrimary: true,
    );

    expect(guardian.relationshipLabel, 'الجد');
    expect(guardian.toMap()['is_primary'], 1);
    expect(FamilyGuardian.fromMap(guardian.toMap()).isPrimary, isTrue);
  });

  test('student family can be assigned and explicitly cleared', () {
    final student = Student(name: 'طالب', familyId: 'family-1');

    expect(student.copyWith().familyId, 'family-1');
    expect(student.copyWith(clearFamily: true).familyId, isNull);
  });
}
