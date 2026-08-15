import 'dart:math' as math;

class ReviewPlanRecommendation {
  final int memorizedAyahs;
  final int estimatedMemorizedPages;
  final int dailyPages;
  final int dailyAyahs;
  final int dailyLines;
  final int dailyHizbs;
  final String tierLabel;

  const ReviewPlanRecommendation({
    required this.memorizedAyahs,
    required this.estimatedMemorizedPages,
    required this.dailyPages,
    required this.dailyAyahs,
    required this.dailyLines,
    required this.dailyHizbs,
    required this.tierLabel,
  });

  int amountForUnit(String unit) {
    switch (unit) {
      case 'pages':
        return dailyPages;
      case 'lines':
        return dailyLines;
      case 'hizbs':
        return dailyHizbs;
      default:
        return dailyAyahs;
    }
  }
}

/// سياسة افتراضية قابلة للتفسير: يراجع الطالب محفوظَه في دورة تقارب 30 يومًا،
/// مع حد أدنى عملي، ثم تزداد الكمية تدريجيًا كلما كبر محفوظُه.
class ReviewPlanPolicy {
  const ReviewPlanPolicy._();

  static const int _quranAyahs = 6236;
  static const int _quranPages = 604;

  static ReviewPlanRecommendation recommend(int totalMemorizedAyahs) {
    final safeAyahs = totalMemorizedAyahs.clamp(0, _quranAyahs).toInt();
    final pages = safeAyahs == 0
        ? 0
        : math.max(1, (safeAyahs * _quranPages / _quranAyahs).ceil());
    final dailyPages = math.max(1, (pages / 30).ceil()).clamp(1, 20).toInt();
    final ayahsPerPage = _quranAyahs / _quranPages;
    final dailyAyahs = math.max(5, (dailyPages * ayahsPerPage).round());

    final memorizedJuz = pages / 20;
    final tierLabel = memorizedJuz <= 5
        ? 'حتى خمسة أجزاء'
        : memorizedJuz <= 10
            ? 'من خمسة إلى عشرة أجزاء'
            : memorizedJuz <= 15
                ? 'من عشرة إلى خمسة عشر جزءًا'
                : memorizedJuz <= 20
                    ? 'أكثر من نصف المصحف'
                    : 'مرحلة الإتقان والختم';

    return ReviewPlanRecommendation(
      memorizedAyahs: safeAyahs,
      estimatedMemorizedPages: pages,
      dailyPages: dailyPages,
      dailyAyahs: dailyAyahs,
      dailyLines: dailyPages * 15,
      // الحزب يقارب عشر صفحات؛ الحد الأدنى حزب واحد عند اختيار هذه الوحدة.
      dailyHizbs: math.max(1, (dailyPages / 10).ceil()),
      tierLabel: tierLabel,
    );
  }
}
