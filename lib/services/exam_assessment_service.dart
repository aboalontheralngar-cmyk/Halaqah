class ExamAssessmentService {
  const ExamAssessmentService._();

  static const double maximumScore = 10;

  static double calculateScore({
    required int memorizationErrors,
    required int tashkeelErrors,
    required int recitationErrors,
    required int promptCount,
  }) {
    final safeMemorization = memorizationErrors < 0 ? 0 : memorizationErrors;
    final safeTashkeel = tashkeelErrors < 0 ? 0 : tashkeelErrors;
    final safeRecitation = recitationErrors < 0 ? 0 : recitationErrors;
    final safePrompts = promptCount < 0 ? 0 : promptCount;
    final deductions = safeMemorization * 2 +
        safeTashkeel +
        safeRecitation +
        safePrompts;
    return (maximumScore - deductions).clamp(0, maximumScore).toDouble();
  }
}
