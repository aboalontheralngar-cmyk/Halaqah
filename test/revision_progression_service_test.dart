import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/models/memorization.dart';
import 'package:halaqah_teacher/services/revision_progression_service.dart';

Surah surah(int id, int ayahs) => Surah(
      number: id,
      name: 'سورة $id',
      totalAyahs: ayahs,
      juzStart: 1,
      pageStart: 1,
      ayahs: List.generate(
        ayahs,
        (index) => Ayah(
          id: index + 1,
          surahNumber: id,
          number: index + 1,
          text: 'آية',
          page: 1,
          juz: 1,
          hizb: 1,
          quarter: 1,
          lines: 1,
          difficulty: 1,
        ),
      ),
    );

MemorizationProgress revision(int surahId, int toAyah, DateTime createdAt) =>
    MemorizationProgress(
      studentId: 'student',
      surahId: surahId,
      fromAyah: 1,
      toAyah: toAyah,
      date: createdAt,
      isRevision: true,
      createdAt: createdAt,
    );

void main() {
  final surahs = {1: surah(1, 7), 2: surah(2, 5), 3: surah(3, 6)};
  Surah? lookup(int id) => surahs[id];

  test('continues after the last reviewed ayah in the same surah', () {
    final next = RevisionProgressionService.nextStartingPoint(
      memorizedSurahIds: [1, 2, 3],
      progress: [revision(2, 3, DateTime(2026, 7, 12))],
      ascending: true,
      getSurah: lookup,
    );
    expect(next, {'surahId': 2, 'fromAyah': 4});
  });

  test('moves to the next memorized surah after completion', () {
    final next = RevisionProgressionService.nextStartingPoint(
      memorizedSurahIds: [1, 2, 3],
      progress: [revision(2, 5, DateTime(2026, 7, 12))],
      ascending: true,
      getSurah: lookup,
    );
    expect(next, {'surahId': 3, 'fromAyah': 1});
  });

  test('wraps according to descending revision order', () {
    final next = RevisionProgressionService.nextStartingPoint(
      memorizedSurahIds: [1, 2, 3],
      progress: [revision(1, 7, DateTime(2026, 7, 12))],
      ascending: false,
      getSurah: lookup,
    );
    expect(next, {'surahId': 3, 'fromAyah': 1});
  });
}
