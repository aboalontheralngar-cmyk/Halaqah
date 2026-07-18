class RecitationPointsResult {
  final double actualAmount;
  final double planAmount;
  final int completionPoints;
  final int bonusPoints;

  const RecitationPointsResult({
    required this.actualAmount,
    required this.planAmount,
    required this.completionPoints,
    required this.bonusPoints,
  });

  double get completionRatio =>
      planAmount <= 0 ? 0 : actualAmount / planAmount;
  int get totalPoints => completionPoints + bonusPoints;
}

/// سياسة واحدة عادلة لكل وحدات المقرر: آيات أو أسطر أو صفحات.
///
/// تجمع الخدمة المنفذة لهذه السياسة جميع تسجيلات اليوم أولًا؛ لذا لا تتأثر
/// النتيجة بتقسيم التسميع على سورتين أو جلستين منفصلتين.
class RecitationPointsPolicy {
  const RecitationPointsPolicy._();

  static const int fullPlanPoints = 5;
  static const int maximumDailyPoints = 10;

  static RecitationPointsResult calculate({
    required double actualAmount,
    required double planAmount,
  }) {
    final safeActual = actualAmount.clamp(0, double.infinity).toDouble();
    final safePlan = planAmount <= 0 ? 1.0 : planAmount;
    final ratio = safeActual / safePlan;
    final completion = safeActual <= 0
        ? 0
        : (ratio.clamp(0, 1) * fullPlanPoints).floor();

    final bonus = ratio >= 2
        ? 5
        : ratio >= 1.5
            ? 2
            : ratio >= 1.25
                ? 1
                : 0;

    return RecitationPointsResult(
      actualAmount: safeActual,
      planAmount: safePlan,
      completionPoints: completion,
      bonusPoints: bonus,
    );
  }
}
