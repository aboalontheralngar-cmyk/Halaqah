class RecitationPointsResult {
  final double actualAmount;
  final double planAmount;
  final int completionPoints;
  final int bonusPoints;
  final int workloadPoints;

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
  int get totalPoints => completionPoints + bonusPoints + workloadPoints;
}

/// سياسة النقاط التلقائية للحفظ اليومي.
///
/// مكافأة الإتمام نسبية إلى ما سُمّع فعليًا من المقرر بدل حجب كل النقاط
/// حتى بلوغ 100%. Build 76 يجعل سياسة تحويل الكسر إلى نقطة صحيحة قابلة
/// للضبط: الأقرب، لأسفل، أو لأعلى، مع ضمان نقطة واحدة عند وجود إنجاز فعلي
/// إذا كانت مكافأة الإتمام أكبر من صفر، ومنع تجاوز مكافأة الإتمام.
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
    String roundingMode = 'nearest',
  }) {
    final safeActual = actualAmount.clamp(0, double.infinity).toDouble();
    final safePlan = planAmount <= 0 ? 1.0 : planAmount;
    final safeCompletionReward = completionReward.clamp(0, 1000).toInt();
    final safeExtraReward = extraReward.clamp(0, 1000).toInt();
    final ratio = (safeActual / safePlan).clamp(0, 1).toDouble();
    final completed = safeActual + 0.000001 >= safePlan;
    final exceeded = safeActual > safePlan + 0.000001;

    final rawReward = safeCompletionReward * ratio;
    var proportionalReward = switch (roundingMode) {
      'floor' => rawReward.floor(),
      'ceil' => rawReward.ceil(),
      _ => rawReward.round(),
    };
    if (safeActual > 0 && safeCompletionReward > 0 && proportionalReward == 0) {
      proportionalReward = 1;
    }
    proportionalReward = proportionalReward.clamp(0, safeCompletionReward).toInt();

    return RecitationPointsResult(
      actualAmount: safeActual,
      planAmount: safePlan,
      completionPoints: proportionalReward,
      bonusPoints: completed && exceeded ? safeExtraReward : 0,
      workloadPoints: 0,
    );
  }
}
