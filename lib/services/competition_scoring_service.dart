class CompetitionScoringService {
  const CompetitionScoringService._();

  static const double obviousErrorDeduction = 3;
  static const double subtleErrorDeduction = 1;
  static const double promptDeduction = 4;
  static const double stopDeduction = 2;
  static const double tajweedErrorDeduction = 0.5;

  static double calculate({
    double maximumScore = 100,
    required int obviousErrors,
    required int subtleErrors,
    required int promptCount,
    required int stopCount,
    required int tajweedErrors,
  }) {
    final deductions =
        obviousErrors.clamp(0, 999) * obviousErrorDeduction +
            subtleErrors.clamp(0, 999) * subtleErrorDeduction +
            promptCount.clamp(0, 999) * promptDeduction +
            stopCount.clamp(0, 999) * stopDeduction +
            tajweedErrors.clamp(0, 999) * tajweedErrorDeduction;
    return (maximumScore - deductions)
        .clamp(0, maximumScore)
        .toDouble();
  }
}
