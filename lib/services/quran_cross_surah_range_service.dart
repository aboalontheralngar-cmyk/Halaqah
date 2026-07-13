import '../models/ayah.dart';

enum QuranRangeBoundary { page, hizb }

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

  static QuranCrossSurahRange? toBoundary({
    required List<Surah> surahs,
    required int startSurahId,
    required int startAyah,
    required QuranRangeBoundary boundary,
  }) {
    final allAyahs = <Ayah>[
      for (final surah in surahs)
        for (final ayah in surah.ayahs)
          if (ayah.number > 0) ayah,
    ];
    final startIndex = allAyahs.indexWhere(
      (ayah) => ayah.surahNumber == startSurahId && ayah.number == startAyah,
    );
    if (startIndex < 0) return null;

    final start = allAyahs[startIndex];
    final boundaryValue = boundary == QuranRangeBoundary.page
        ? start.page
        : start.hizb;
    final selected = <Ayah>[];
    for (var index = startIndex; index < allAyahs.length; index++) {
      final ayah = allAyahs[index];
      final value = boundary == QuranRangeBoundary.page ? ayah.page : ayah.hizb;
      if (value != boundaryValue) break;
      selected.add(ayah);
    }
    if (selected.isEmpty) return null;

    final segments = <QuranRangeSegment>[];
    for (final ayah in selected) {
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
    return QuranCrossSurahRange(ayahs: selected, segments: segments);
  }
}
