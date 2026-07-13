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
