import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/services/mandatory_revision_schedule_service.dart';

void main() {
  Surah buildSurah(int pageCount) {
    final ayahs = <Ayah>[];
    var number = 1;
    for (var page = 1; page <= pageCount; page++) {
      for (var i = 0; i < 2; i++) {
        ayahs.add(Ayah(
          id: number,
          surahNumber: 1,
          number: number,
          text: 'آية $number',
          page: page,
          juz: 1,
          hizb: 1,
          quarter: 1,
          lines: 1,
          difficulty: 1,
        ));
        number++;
      }
    }
    return Surah(
      number: 1,
      name: 'اختبار',
      totalAyahs: ayahs.length,
      juzStart: 1,
      pageStart: 1,
      ayahs: ayahs,
    );
  }

  test('five or more pages are distributed over at most five days', () {
    final surah = buildSurah(10);
    final chunks = List.generate(
      5,
      (day) => MandatoryRevisionScheduleService.chunkForDay(
        surah: surah,
        fromAyah: 1,
        toAyah: 20,
        completedDays: day,
      )!,
    );
    expect(chunks.map((chunk) => chunk.fromPage).toList(), [1, 3, 5, 7, 9]);
    expect(chunks.map((chunk) => chunk.toPage).toList(), [2, 4, 6, 8, 10]);
    expect(chunks.last.totalDays, 5);
  });

  test('short surah does not create empty mandatory days', () {
    final surah = buildSurah(2);
    final first = MandatoryRevisionScheduleService.chunkForDay(
      surah: surah,
      fromAyah: 1,
      toAyah: 4,
      completedDays: 0,
    );
    final second = MandatoryRevisionScheduleService.chunkForDay(
      surah: surah,
      fromAyah: 1,
      toAyah: 4,
      completedDays: 1,
    );
    final done = MandatoryRevisionScheduleService.chunkForDay(
      surah: surah,
      fromAyah: 1,
      toAyah: 4,
      completedDays: 2,
    );
    expect(first!.fromPage, 1);
    expect(second!.fromPage, 2);
    expect(second.totalDays, 2);
    expect(done, isNull);
  });
}
