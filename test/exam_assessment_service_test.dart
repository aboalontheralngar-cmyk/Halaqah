import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/exam_assessment_service.dart';

void main() {
  test('applies the documented digital assessment deductions', () {
    final score = ExamAssessmentService.calculateScore(
      memorizationErrors: 1,
      tashkeelErrors: 2,
      recitationErrors: 1,
      promptCount: 1,
    );

    expect(score, 4);
  });

  test('never produces a negative score', () {
    final score = ExamAssessmentService.calculateScore(
      memorizationErrors: 20,
      tashkeelErrors: 20,
      recitationErrors: 20,
      promptCount: 20,
    );

    expect(score, 0);
  });
}
