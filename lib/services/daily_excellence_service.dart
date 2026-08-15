import '../models/ayah.dart';
import '../models/memorization.dart';

class DailyExcellenceService {
  const DailyExcellenceService._();

  static Map<int, double>? _fullQuranPageWeights;
  static Map<int, double>? _fullQuranHizbWeights;

  static double _lineWeight(Ayah ayah) => ayah.lines <= 0 ? 0.5 : ayah.lines;

  static Map<int, double> _groupWeights(
    Iterable<Ayah> ayahs,
    int Function(Ayah) groupOf,
  ) {
    final result = <int, double>{};
    for (final ayah in ayahs) {
      final group = groupOf(ayah);
      if (group <= 0) continue;
      result[group] = (result[group] ?? 0) + _lineWeight(ayah);
    }
    return result;
  }

  static Map<int, double> _referenceWeights({
    required Map<int, Surah> surahs,
    required bool byPage,
  }) {
    // Production calls pass the complete Quran corpus. Cache those denominators
    // once so a student list does not rescan all 6236 ayahs for every row.
    if (surahs.length >= 114) {
      if (byPage && _fullQuranPageWeights != null) return _fullQuranPageWeights!;
      if (!byPage && _fullQuranHizbWeights != null) return _fullQuranHizbWeights!;
      final allAyahs = surahs.values.expand((surah) => surah.ayahs);
      final computed = _groupWeights(
        allAyahs,
        byPage ? (ayah) => ayah.page : (ayah) => ayah.hizb,
      );
      if (byPage) {
        _fullQuranPageWeights = computed;
      } else {
        _fullQuranHizbWeights = computed;
      }
      return computed;
    }

    return _groupWeights(
      surahs.values.expand((surah) => surah.ayahs),
      byPage ? (ayah) => ayah.page : (ayah) => ayah.hizb,
    );
  }

  static double _fractionalGroupAmount({
    required Iterable<Ayah> selectedAyahs,
    required Map<int, Surah> surahs,
    required bool byPage,
  }) {
    final selected = _groupWeights(
      selectedAyahs,
      byPage ? (ayah) => ayah.page : (ayah) => ayah.hizb,
    );
    if (selected.isEmpty) return 0;
    final reference = _referenceWeights(surahs: surahs, byPage: byPage);
    var total = 0.0;
    for (final entry in selected.entries) {
      final denominator = reference[entry.key] ?? 0;
      if (denominator <= 0) continue;
      total += (entry.value / denominator).clamp(0.0, 1.0).toDouble();
    }
    return total;
  }

  static double calculateActualAmount({
    required List<MemorizationProgress> progress,
    required Map<int, Surah> surahs,
    required String unit,
    bool isRevision = false,
  }) {
    final uniqueAyahs = <String, Ayah>{};
    for (final row in progress.where((item) => item.isRevision == isRevision)) {
      final surah = surahs[row.surahId];
      if (surah == null) continue;
      final from = row.fromAyah.clamp(1, surah.totalAyahs).toInt();
      final to = row.toAyah.clamp(from, surah.totalAyahs).toInt();
      for (final ayah in surah.getAyahRange(from, to)) {
        uniqueAyahs['${row.surahId}:${ayah.number}'] = ayah;
      }
    }

    if (unit == 'pages') {
      // A face is counted relative to the Quran ayahs that actually belong to
      // that page. Finishing exactly one face therefore returns exactly 1.0,
      // while touching a few ayahs remains fractional and cannot earn a bonus.
      return _fractionalGroupAmount(
        selectedAyahs: uniqueAyahs.values,
        surahs: surahs,
        byPage: true,
      );
    }
    if (unit == 'hizbs') {
      // The same principle is used for a hizb: selected Quran-line weight over
      // the complete hizb weight, capped at one for each hizb.
      return _fractionalGroupAmount(
        selectedAyahs: uniqueAyahs.values,
        surahs: surahs,
        byPage: false,
      );
    }

    final totalLines = uniqueAyahs.values.fold<double>(
      0,
      (sum, ayah) => sum + _lineWeight(ayah),
    );
    if (unit == 'lines') return totalLines;
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
