import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/services/quran_cross_surah_range_service.dart';

void main() {
  final surahs = [
    _surah(1, pages: const [1, 2], hizbs: const [1, 1]),
    _surah(2, pages: const [2, 3], hizbs: const [1, 2]),
  ];

  test('page boundary may end in the following surah', () {
    final range = QuranCrossSurahRangeService.toBoundary(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      boundary: QuranRangeBoundary.page,
    );

    expect(range, isNotNull);
    expect(range!.toSurahId, 2);
    expect(range.toAyah, 1);
    expect(range.segments, hasLength(2));
  });

  test('hizb boundary stops before the next hizb', () {
    final range = QuranCrossSurahRangeService.toBoundary(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 1,
      boundary: QuranRangeBoundary.hizb,
    );

    expect(range, isNotNull);
    expect(range!.ayahs, hasLength(3));
    expect(range.toSurahId, 2);
    expect(range.toAyah, 1);
  });

  test('two-page amount continues through the following surah', () {
    final range = QuranCrossSurahRangeService.toAmount(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 1,
      unit: QuranRangeUnit.pages,
      amount: 2,
    );

    expect(range, isNotNull);
    expect(range!.segments, hasLength(2));
    expect(range.toSurahId, 2);
    expect(range.toAyah, 1);
  });

  test('line amount accumulates across a surah boundary', () {
    final range = QuranCrossSurahRangeService.toAmount(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      unit: QuranRangeUnit.lines,
      amount: 2,
    );

    expect(range, isNotNull);
    expect(range!.ayahs, hasLength(2));
    expect(range.toSurahId, 2);
    expect(range.toAyah, 1);
  });

  test('allowed memorized ranges stop before an unavailable ayah', () {
    final range = QuranCrossSurahRangeService.toAmount(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      unit: QuranRangeUnit.hizbs,
      amount: 1,
      allowedRanges: const {
        1: QuranRangeSegment(surahId: 1, fromAyah: 1, toAyah: 2),
      },
    );

    expect(range, isNotNull);
    expect(range!.segments, hasLength(1));
    expect(range.toSurahId, 1);
    expect(range.toAyah, 2);
  });

  test('descending surah order continues from surah two to surah one', () {
    final range = QuranCrossSurahRangeService.toAmount(
      surahs: surahs,
      startSurahId: 2,
      startAyah: 1,
      unit: QuranRangeUnit.ayahs,
      amount: 3,
      ascendingSurahs: false,
    );

    expect(range, isNotNull);
    expect(range!.segments.map((segment) => segment.surahId), [2, 1]);
    expect(range.toSurahId, 1);
    expect(range.toAyah, 1);
  });

  test('open range continues to the end of the selected direction', () {
    final range = QuranCrossSurahRangeService.toEnd(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
    );

    expect(range, isNotNull);
    expect(range!.ayahs, hasLength(3));
    expect(range.segments.map((segment) => segment.surahId), [1, 2]);
    expect(range.toSurahId, 2);
    expect(range.toAyah, 2);
  });

  test('teacher stop point is split into per-surah database segments', () {
    final range = QuranCrossSurahRangeService.fromAyahs([
      surahs[0].ayahs[1],
      surahs[1].ayahs[0],
      surahs[1].ayahs[1],
    ]);

    expect(range, isNotNull);
    expect(range!.segments, hasLength(2));
    expect(range.segments.first.fromAyah, 2);
    expect(range.segments.first.toAyah, 2);
    expect(range.segments.last.fromAyah, 1);
    expect(range.segments.last.toAyah, 2);
  });

  test('explicit from-to range may span multiple surahs', () {
    final range = QuranCrossSurahRangeService.between(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      endSurahId: 2,
      endAyah: 2,
    );

    expect(range, isNotNull);
    expect(range!.ayahs, hasLength(3));
    expect(range.segments.map((segment) => segment.surahId), [1, 2]);
    expect(range.segments.first.fromAyah, 2);
    expect(range.segments.last.toAyah, 2);
  });

  test('explicit range respects memorized ranges across surahs', () {
    final range = QuranCrossSurahRangeService.between(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      endSurahId: 2,
      endAyah: 2,
      allowedRanges: const {
        1: QuranRangeSegment(surahId: 1, fromAyah: 1, toAyah: 2),
        2: QuranRangeSegment(surahId: 2, fromAyah: 1, toAyah: 2),
      },
    );

    expect(range, isNotNull);
    expect(range!.segments.map((segment) => segment.surahId), [1, 2]);
  });

  test('explicit range rejects a gap in recorded memorization', () {
    final range = QuranCrossSurahRangeService.between(
      surahs: surahs,
      startSurahId: 1,
      startAyah: 2,
      endSurahId: 2,
      endAyah: 2,
      allowedRanges: const {
        1: QuranRangeSegment(surahId: 1, fromAyah: 1, toAyah: 2),
      },
    );

    expect(range, isNull);
  });

  test('explicit range follows descending surah direction', () {
    final range = QuranCrossSurahRangeService.between(
      surahs: surahs,
      startSurahId: 2,
      startAyah: 2,
      endSurahId: 1,
      endAyah: 2,
      ascendingSurahs: false,
    );

    expect(range, isNotNull);
    expect(range!.segments.map((segment) => segment.surahId), [2, 1]);
    expect(range.ayahs.map((ayah) => '${ayah.surahNumber}:${ayah.number}'), [
      '2:2',
      '1:1',
      '1:2',
    ]);
  });
}

Surah _surah(
  int number, {
  required List<int> pages,
  required List<int> hizbs,
}) {
  return Surah(
    number: number,
    name: 'سورة $number',
    totalAyahs: pages.length,
    juzStart: 1,
    pageStart: pages.first,
    ayahs: List.generate(
      pages.length,
      (index) => Ayah(
        id: number * 100 + index,
        surahNumber: number,
        number: index + 1,
        text: 'آية ${index + 1}',
        page: pages[index],
        juz: 1,
        hizb: hizbs[index],
        quarter: 1,
        lines: 1,
        difficulty: 1,
      ),
    ),
  );
}
