import '../models/ayah.dart';

class MemorizationMeasureService {
  const MemorizationMeasureService._();

  static int calculateToAyah({
    required Surah surah,
    required int fromAyah,
    required String planType,
    required int planAmount,
  }) {
    final safeFrom = fromAyah.clamp(1, surah.totalAyahs).toInt();
    final safeAmount = planAmount < 1 ? 1 : planAmount;

    if (planType == 'ayahs') {
      return (safeFrom + safeAmount - 1)
          .clamp(1, surah.totalAyahs)
          .toInt();
    }

    if (planType == 'pages') {
      final startAyah = surah.getAyah(safeFrom);
      if (startAyah == null) return safeFrom;
      final targetEndPage = startAyah.page + safeAmount - 1;
      var targetToAyah = safeFrom;
      for (var number = safeFrom; number <= surah.totalAyahs; number++) {
        final ayah = surah.getAyah(number);
        if (ayah == null || ayah.page > targetEndPage) break;
        targetToAyah = number;
      }
      return targetToAyah;
    }

    if (planType == 'lines') {
      var lines = 0.0;
      var targetToAyah = safeFrom;
      for (var number = safeFrom; number <= surah.totalAyahs; number++) {
        final ayah = surah.getAyah(number);
        if (ayah == null) continue;
        lines += ayah.lines;
        targetToAyah = number;
        if (lines >= safeAmount) break;
      }
      return targetToAyah;
    }

    return safeFrom;
  }

  static double calculateAmount({
    required Surah surah,
    required int fromAyah,
    required int toAyah,
    required String planType,
  }) {
    final safeFrom = fromAyah.clamp(1, surah.totalAyahs).toInt();
    final safeTo = toAyah.clamp(safeFrom, surah.totalAyahs).toInt();
    final ayahs = surah.getAyahRange(safeFrom, safeTo);

    if (planType == 'pages') {
      return ayahs.map((ayah) => ayah.page).toSet().length.toDouble();
    }
    if (planType == 'lines') {
      return ayahs.fold<double>(0, (sum, ayah) => sum + ayah.lines);
    }
    return ayahs.length.toDouble();
  }

  static bool exceedsPlan({
    required Surah surah,
    required int fromAyah,
    required int toAyah,
    required String planType,
    required int planAmount,
  }) {
    final completed = calculateAmount(
      surah: surah,
      fromAyah: fromAyah,
      toAyah: toAyah,
      planType: planType,
    );
    return completed > planAmount + 0.001;
  }
}
