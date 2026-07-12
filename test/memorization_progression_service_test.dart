import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/models/memorization.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/services/memorization_progression_service.dart';

void main() {
  final surahs = <int, Surah>{
    1: _surah(1, 7),
    2: _surah(2, 6),
    113: _surah(113, 5),
    114: _surah(114, 6),
  };
  Surah? lookup(int id) => surahs[id];

  test('starts from An-Nas for the short-surah direction', () {
    final result = MemorizationProgressionService.nextStartingPoint(
      student: Student(
        name: 'طالب',
        memorizationDirection: 'desc',
        planType: 'ayahs',
        planAmount: 2,
      ),
      progress: const [],
      getSurah: lookup,
    );

    expect(result, {'surahId': 114, 'fromAyah': 1, 'toAyah': 2});
  });

  test('moves to the next surah after completing the current surah', () {
    final student = Student(
      id: 's1',
      name: 'طالب',
      memorizationDirection: 'desc',
      planType: 'ayahs',
      planAmount: 2,
    );
    final result = MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: [_progress(student.id, 114, 1, 6)],
      getSurah: lookup,
    );

    expect(result, {'surahId': 113, 'fromAyah': 1, 'toAyah': 2});
  });

  test('uses the furthest memorized point, not the newest edited row', () {
    final student = Student(
      id: 's1',
      name: 'طالب',
      memorizationDirection: 'desc',
      planType: 'ayahs',
      planAmount: 2,
    );
    final result = MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: [
        _progress(student.id, 114, 1, 6, day: 2),
        _progress(student.id, 113, 1, 2, day: 1),
      ],
      getSurah: lookup,
    );

    expect(result, {'surahId': 113, 'fromAyah': 3, 'toAyah': 4});
  });

  test('moves from Al-Fatihah toward Al-Baqarah in the long-surah direction', () {
    final student = Student(
      id: 's1',
      name: 'طالب',
      memorizationDirection: 'asc',
      planType: 'ayahs',
      planAmount: 3,
    );
    final result = MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: [_progress(student.id, 1, 1, 7)],
      getSurah: lookup,
    );

    expect(result, {'surahId': 2, 'fromAyah': 1, 'toAyah': 3});
  });

  test('does not wrap to the beginning after completing the Quran', () {
    final student = Student(
      id: 's1',
      name: 'طالب',
      memorizationDirection: 'desc',
    );
    final result = MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: [_progress(student.id, 1, 1, 7)],
      getSurah: lookup,
    );

    expect(result, isNull);
  });
}

Surah _surah(int number, int totalAyahs) {
  return Surah(
    number: number,
    name: 'سورة $number',
    totalAyahs: totalAyahs,
    juzStart: 1,
    pageStart: 1,
    ayahs: List.generate(
      totalAyahs,
      (index) => Ayah(
        id: index + 1,
        surahNumber: number,
        number: index + 1,
        text: 'آية ${index + 1}',
        page: 1,
        juz: 1,
        hizb: 1,
        quarter: 1,
        lines: 1,
        difficulty: 1,
      ),
    ),
  );
}

MemorizationProgress _progress(
  String studentId,
  int surahId,
  int fromAyah,
  int toAyah, {
  int day = 1,
}) {
  return MemorizationProgress(
    studentId: studentId,
    surahId: surahId,
    fromAyah: fromAyah,
    toAyah: toAyah,
    date: DateTime(2026, 1, day),
  );
}
