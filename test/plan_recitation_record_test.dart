import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/plan_recitation_record.dart';
import 'package:halaqah_teacher/services/plan_progress_service.dart';

void main() {
  test('plan recitation record preserves a connected session segment', () {
    final createdAt = DateTime(2026, 7, 22, 10);
    final record = PlanRecitationRecord(
      id: 'row-1',
      sessionId: 'session-1',
      planId: 'plan-1',
      studentId: 'student-1',
      surahId: 2,
      fromAyah: 10,
      toAyah: 20,
      segmentOrder: 1,
      date: DateTime(2026, 7, 22),
      qualityRating: 4,
      notes: 'تلاوة متقنة',
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    final restored = PlanRecitationRecord.fromMap(record.toMap());
    expect(restored.sessionId, 'session-1');
    expect(restored.segmentOrder, 1);
    expect(restored.ayahCount, 11);
    expect(restored.qualityRating, 4);
  });

  test('plan completion requires memorization, review, and recitation', () {
    const missingRecitation = SmartPlanProgress(
      requiredStudyDays: 5,
      requiredMemorization: 25,
      actualMemorization: 25,
      requiredReview: 50,
      actualReview: 50,
      requiredRecitation: 5,
      actualRecitation: 0,
    );
    const completed = SmartPlanProgress(
      requiredStudyDays: 5,
      requiredMemorization: 25,
      actualMemorization: 25,
      requiredReview: 50,
      actualReview: 50,
      requiredRecitation: 5,
      actualRecitation: 5,
    );

    expect(missingRecitation.isAccomplished, isFalse);
    expect(missingRecitation.completionPercent, 67);
    expect(completed.isAccomplished, isTrue);
    expect(completed.completionPercent, 100);
  });

  test('revision-only graduate plan does not require memorization', () {
    const completed = SmartPlanProgress(
      requiredStudyDays: 5,
      requiredMemorization: 0,
      actualMemorization: 0,
      requiredReview: 50,
      actualReview: 50,
      requiredRecitation: 5,
      actualRecitation: 5,
    );

    expect(completed.memorizationRatio, 1);
    expect(completed.completionPercent, 100);
    expect(completed.isAccomplished, isTrue);

    const notStarted = SmartPlanProgress(
      requiredStudyDays: 5,
      requiredMemorization: 0,
      actualMemorization: 0,
      requiredReview: 50,
      actualReview: 0,
      requiredRecitation: 5,
      actualRecitation: 0,
    );
    expect(notStarted.completionPercent, 0);
  });
}
