import '../models/ayah.dart';
import '../models/memorization.dart';

class DailyExcellenceService {
  const DailyExcellenceService._();

  static double calculateActualAmount({
    required List<MemorizationProgress> progress,
    required Map<int, Surah> surahs,
    required String unit,
  }) {
    final uniqueAyahs = <String, Ayah>{};
    for (final row in progress.where((item) => !item.isRevision)) {
      final surah = surahs[row.surahId];
      if (surah == null) continue;
      final from = row.fromAyah.clamp(1, surah.totalAyahs).toInt();
      final to = row.toAyah.clamp(from, surah.totalAyahs).toInt();
      for (final ayah in surah.getAyahRange(from, to)) {
        uniqueAyahs['${row.surahId}:${ayah.number}'] = ayah;
      }
    }
    if (unit == 'pages') {
      return uniqueAyahs.values.map((ayah) => ayah.page).toSet().length.toDouble();
    }
    if (unit == 'lines') {
      return uniqueAyahs.values.fold<double>(0, (sum, ayah) => sum + ayah.lines);
    }
    return uniqueAyahs.length.toDouble();
  }

  static bool qualifies({
    required double actualAmount,
    required double planAmount,
  }) =>
      actualAmount > planAmount + 0.001;

  static double exceededBy({
    required double actualAmount,
    required double planAmount,
  }) =>
      (actualAmount - planAmount).clamp(0, double.infinity).toDouble();
}
