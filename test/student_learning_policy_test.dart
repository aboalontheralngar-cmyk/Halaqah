import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/services/student_learning_policy.dart';
import 'package:halaqah_teacher/utils/quran_data.dart';

void main() {
  test('completed Quran total creates a revision-only student', () {
    final student = Student(
      name: 'طالب خاتم',
      totalMemorized: QuranData.totalAyahs,
    );

    expect(StudentLearningPolicy.hasCompletedQuran(student), isTrue);
    expect(StudentLearningPolicy.canReceiveNewMemorization(student), isFalse);
    expect(StudentLearningPolicy.canReceiveRevision(student), isTrue);
  });

  test('graduated status remains revision-only with legacy totals', () {
    final student = Student(
      name: 'طالب متخرج',
      status: 'graduated',
      totalMemorized: 0,
    );

    expect(StudentLearningPolicy.hasCompletedQuran(student), isTrue);
    expect(StudentLearningPolicy.canReceiveNewMemorization(student), isFalse);
    expect(StudentLearningPolicy.canReceiveRevision(student), isTrue);
  });

  test('active learner remains available for both streams', () {
    final student = Student(name: 'طالب مستمر', totalMemorized: 1000);

    expect(StudentLearningPolicy.hasCompletedQuran(student), isFalse);
    expect(StudentLearningPolicy.canReceiveNewMemorization(student), isTrue);
    expect(StudentLearningPolicy.canReceiveRevision(student), isTrue);
  });
}
