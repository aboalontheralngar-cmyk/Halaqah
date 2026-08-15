import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/monthly_plan_exam_service.dart';

void main() {
  test('monthly plan components are capped at twenty points', () {
    expect(MonthlyPlanExamService.planComponentScore(0), 0);
    expect(MonthlyPlanExamService.planComponentScore(.5), 10);
    expect(MonthlyPlanExamService.planComponentScore(1), 20);
    expect(MonthlyPlanExamService.planComponentScore(2), 20);
  });

  test('breakdown total is exactly out of one hundred', () {
    const result = MonthlyPlanExamBreakdown(
      memorizationQuestionScores: [10, 9, 8],
      reviewQuestionScores: [10, 10, 9],
      memorizationPlanScore: 18,
      reviewPlanScore: 16,
    );
    expect(result.total, 90);
    expect(result.memorizationQuestions, 27);
    expect(result.reviewQuestions, 29);
  });


  test('monthly exam notes retain the structured template link', () {
    const breakdown = MonthlyPlanExamBreakdown(
      memorizationQuestionScores: [10, 10, 10],
      reviewQuestionScores: [9, 8, 7],
      memorizationPlanScore: 20,
      reviewPlanScore: 18,
    );
    const question = MonthlyPlanExamQuestion(
      section: 'memorization',
      index: 1,
      surahId: 2,
      fromAyah: 1,
      toAyah: 5,
      surahName: 'البقرة',
    );
    final decoded = jsonDecode(MonthlyPlanExamService.encodeNotes(
      planId: 'plan-1',
      templateId: 'template-1',
      breakdown: breakdown,
      questions: const [question],
    )) as Map<String, dynamic>;

    expect(decoded['schema'], 'monthly_plan_v2');
    expect(decoded['template_id'], 'template-1');
    expect(decoded['plan_id'], 'plan-1');
  });

}
