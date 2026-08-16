class RecitationPointsResult {
  final double actualAmount;
  final double planAmount;
  final double completionPoints;
  final double bonusPoints;
  final double workloadPoints;

  const RecitationPointsResult({
    required this.actualAmount,
    required this.planAmount,
    required this.completionPoints,
    required this.bonusPoints,
    this.workloadPoints = 0,
  });

  double get completionRatio =>
      planAmount <= 0 ? 0 : (actualAmount / planAmount).clamp(0, double.infinity);
  double get cappedCompletionRatio => completionRatio.clamp(0, 1).toDouble();
  int get completionPercent => (cappedCompletionRatio * 100).round();
  double get totalPoints => completionPoints + bonusPoints + workloadPoints;
}

/// سياسة النقاط التلقائية للحفظ اليومي.
///
/// مكافأة الإتمام نسبية إلى ما سُمّع فعليًا من المقرر بدل حجب كل النقاط
/// حتى بلوغ 100%. Build 78 يحفظ الكسر الحقيقي افتراضيًا (مثل 2.5)،
/// ويُبقي أوضاع التقريب القديمة اختيارية لمن يريد الأقرب أو لأسفل أو لأعلى،
/// مع منع تجاوز مكافأة الإتمام المحددة.
class RecitationPointsPolicy {
  const RecitationPointsPolicy._();

  static const int defaultCompletionReward = 5;
  static const int defaultExtraReward = 2;

  static RecitationPointsResult calculate({
    required double actualAmount,
    required double planAmount,
    String unit = 'ayahs',
    int completionReward = defaultCompletionReward,
    int extraReward = defaultExtraReward,
    String roundingMode = 'exact',
  }) {
    final safeActual = actualAmount.clamp(0, double.infinity).toDouble();
    final safePlan = planAmount <= 0 ? 1.0 : planAmount;
    final safeCompletionReward = completionReward.clamp(0, 1000).toInt();
    final safeExtraReward = extraReward.clamp(0, 1000).toInt();
    final ratio = (safeActual / safePlan).clamp(0, 1).toDouble();
    final completed = safeActual + 0.000001 >= safePlan;
    final exceeded = safeActual > safePlan + 0.000001;

    final rawReward = safeCompletionReward * ratio;
    double proportionalReward = switch (roundingMode) {
      'floor' => rawReward.floorToDouble(),
      'ceil' => rawReward.ceilToDouble(),
      'nearest' => rawReward.roundToDouble(),
      _ => (rawReward * 100).roundToDouble() / 100,
    };
    // في الوضع الدقيق لا نفرض نقطة كاملة على إنجاز صغير؛ 5 أسطر من مقرر
    // كبير تأخذ نسبتها الحقيقية. أوضاع التقريب القديمة تبقى اختيارية.
    if (roundingMode != 'exact' &&
        safeActual > 0 &&
        safeCompletionReward > 0 &&
        proportionalReward == 0) {
      proportionalReward = 1;
    }
    proportionalReward = proportionalReward
        .clamp(0, safeCompletionReward)
        .toDouble();

    return RecitationPointsResult(
      actualAmount: safeActual,
      planAmount: safePlan,
      completionPoints: proportionalReward,
      bonusPoints: completed && exceeded ? safeExtraReward.toDouble() : 0,
      workloadPoints: 0,
    );
  }
}
