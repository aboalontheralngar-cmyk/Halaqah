import '../models/ayah.dart';

enum QuranRangeBoundary { page, hizb }

enum QuranRangeUnit { ayahs, lines, pages, hizbs }

class QuranRangeSegment {
  final int surahId;
  final int fromAyah;
  final int toAyah;

  const QuranRangeSegment({
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
  });
}

class QuranCrossSurahRange {
  final List<Ayah> ayahs;
  final List<QuranRangeSegment> segments;

  const QuranCrossSurahRange({required this.ayahs, required this.segments});

  int get fromSurahId => ayahs.first.surahNumber;
  int get fromAyah => ayahs.first.number;
  int get toSurahId => ayahs.last.surahNumber;
  int get toAyah => ayahs.last.number;
}

class QuranCrossSurahRangeService {
  const QuranCrossSurahRangeService._();

  /// Builds a range from an already ordered list of ayahs.
  ///
  /// This is useful for an open recitation session after the teacher chooses
  /// the exact stopping point. The returned segments remain compatible with
  /// the per-surah rows used by the local and cloud databases.
  static QuranCrossSurahRange? fromAyahs(Iterable<Ayah> ayahs) {
    final selected = ayahs.where((ayah) => ayah.number > 0).toList();
    if (selected.isEmpty) return null;
    return QuranCrossSurahRange(
      ayahs: selected,
      segments: _segmentsFromAyahs(selected),
    );
  }

  /// Builds an explicit continuous range between two Quran endpoints.
  /// The endpoint order follows the student's memorization direction.
  static QuranCrossSurahRange? between({
    required List<Surah> surahs,
    required int startSurahId,
    required int startAyah,
    required int endSurahId,
    required int endAyah,
    Map<int, QuranRangeSegment> allowedRanges = const {},
    bool ascendingSurahs = true,
  }) {
    final orderedSurahs = List<Surah>.from(surahs)
      ..sort(
        (left, right) => ascendingSurahs
            ? left.number.compareTo(right.number)
            : right.number.compareTo(left.number),
      );
    final allAyahs = <Ayah>[
      for (final surah in orderedSurahs)
        for (final ayah in surah.ayahs)
          if (ayah.number > 0) ayah,
    ];
    final startIndex = allAyahs.indexWhere(
      (ayah) => ayah.surahNumber == startSurahId && ayah.number == startAyah,
    );
    final endIndex = allAyahs.indexWhere(
      (ayah) => ayah.surahNumber == endSurahId && ayah.number == endAyah,
    );
    if (startIndex < 0 || endIndex < startIndex) return null;
    final selected = allAyahs.sublist(startIndex, endIndex + 1);
    if (allowedRanges.isNotEmpty) {
      for (final ayah in selected) {
        final allowed = allowedRanges[ayah.surahNumber];
        if (allowed == null ||
            ayah.number < allowed.fromAyah ||
            ayah.number > allowed.toAyah) {
          return null;
        }
      }
    }
    return fromAyahs(selected);
  }

  static QuranRangeUnit unitFromPlanType(String value) {
    switch (value) {
      case 'lines':
        return QuranRangeUnit.lines;
      case 'pages':
        return QuranRangeUnit.pages;
      case 'hizbs':
        return QuranRangeUnit.hizbs;
      default:
        return QuranRangeUnit.ayahs;
    }
  }

  static QuranCrossSurahRange? toBoundary({
    required List<Surah> surahs,
    required int startSurahId,
    required int startAyah,
    required QuranRangeBoundary boundary,
    bool ascendingSurahs = true,
  }) {
    return toAmount(
      surahs: surahs,
      startSurahId: startSurahId,
      startAyah: startAyah,
      unit: boundary == QuranRangeBoundary.page
          ? QuranRangeUnit.pages
          : QuranRangeUnit.hizbs,
      amount: 1,
      ascendingSurahs: ascendingSurahs,
    );
  }

  /// Returns every ayah from the selected starting point to the end of the
  /// student's memorization direction. The UI can then stop the session at
  /// any ayah without being limited by the end of the current surah.
  static QuranCrossSurahRange? toEnd({
    required List<Surah> surahs,
    required int startSurahId,
    required int startAyah,
    bool ascendingSurahs = true,
  }) {
    final totalAyahs = surahs.fold<int>(
      0,
      (sum, surah) => sum + surah.totalAyahs,
    );
    return toAmount(
      surahs: surahs,
      startSurahId: startSurahId,
      startAyah: startAyah,
      unit: QuranRangeUnit.ayahs,
      amount: totalAyahs,
      ascendingSurahs: ascendingSurahs,
    );
  }

  /// Builds one continuous Quran range and splits it into database-compatible
  /// per-surah segments. Page, line, ayah, and hizb amounts may continue into
  /// the following surah instead of being silently truncated.
  ///
  /// When [allowedRanges] is provided, selection stops at the first ayah that
  /// is not available. This is used by revision so it can never leave the
  /// student's recorded memorized content or jump over a gap.
  static QuranCrossSurahRange? toAmount({
    required List<Surah> surahs,
    required int startSurahId,
    required int startAyah,
    required QuranRangeUnit unit,
    required int amount,
    Map<int, QuranRangeSegment> allowedRanges = const {},
    bool ascendingSurahs = true,
  }) {
    final orderedSurahs = List<Surah>.from(surahs)
      ..sort(
        (left, right) => ascendingSurahs
            ? left.number.compareTo(right.number)
            : right.number.compareTo(left.number),
      );
    final allAyahs = <Ayah>[
      for (final surah in orderedSurahs)
        for (final ayah in surah.ayahs)
          if (ayah.number > 0) ayah,
    ];
    final startIndex = allAyahs.indexWhere(
      (ayah) => ayah.surahNumber == startSurahId && ayah.number == startAyah,
    );
    if (startIndex < 0) return null;

    final safeAmount = amount < 1 ? 1 : amount;
    final selected = <Ayah>[];
    final distinctBoundaries = <int>{};
    var accumulatedLines = 0.0;

    for (var index = startIndex; index < allAyahs.length; index++) {
      final ayah = allAyahs[index];
      final allowed = allowedRanges[ayah.surahNumber];
      if (allowedRanges.isNotEmpty &&
          (allowed == null ||
              ayah.number < allowed.fromAyah ||
              ayah.number > allowed.toAyah)) {
        break;
      }

      if (unit == QuranRangeUnit.pages || unit == QuranRangeUnit.hizbs) {
        final boundary = unit == QuranRangeUnit.pages ? ayah.page : ayah.hizb;
        if (!distinctBoundaries.contains(boundary) &&
            distinctBoundaries.length >= safeAmount) {
          break;
        }
        distinctBoundaries.add(boundary);
      }

      selected.add(ayah);
      if (unit == QuranRangeUnit.ayahs && selected.length >= safeAmount) break;
      if (unit == QuranRangeUnit.lines) {
        accumulatedLines += ayah.lines;
        if (accumulatedLines + 0.001 >= safeAmount) break;
      }
    }
    if (selected.isEmpty) return null;

    return QuranCrossSurahRange(
      ayahs: selected,
      segments: _segmentsFromAyahs(selected),
    );
  }

  static List<QuranRangeSegment> _segmentsFromAyahs(List<Ayah> ayahs) {
    final segments = <QuranRangeSegment>[];
    for (final ayah in ayahs) {
      if (segments.isEmpty || segments.last.surahId != ayah.surahNumber) {
        segments.add(
          QuranRangeSegment(
            surahId: ayah.surahNumber,
            fromAyah: ayah.number,
            toAyah: ayah.number,
          ),
        );
      } else {
        final previous = segments.removeLast();
        segments.add(
          QuranRangeSegment(
            surahId: previous.surahId,
            fromAyah: previous.fromAyah,
            toAyah: ayah.number,
          ),
        );
      }
    }
    return segments;
  }
}
