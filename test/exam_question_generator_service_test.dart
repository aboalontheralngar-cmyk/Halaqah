import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/services/exam_question_generator_service.dart';

void main() {
  final surahs = [
    _surah(1, juz: 1, hizb: 1, difficulty: 1),
    _surah(2, juz: 2, hizb: 3, difficulty: 2),
  ];

  test('filters questions by juz and difficulty without duplicates', () {
    final questions = ExamQuestionGeneratorService.generate(
      surahs: surahs,
      category: 'juz',
      questionCount: 4,
      approximateLines: 2,
      fromJuz: 2,
      toJuz: 2,
      difficulty: 2,
      random: Random(1),
    );

    expect(questions, hasLength(4));
    expect(questions.every((question) => question['surah_id'] == 2), isTrue);
    expect(questions.map((question) => question['key']).toSet(), hasLength(4));
  });

  test('honors the memorized-surah allowlist and previous question keys', () {
    final questions = ExamQuestionGeneratorService.generate(
      surahs: surahs,
      category: 'memorized',
      questionCount: 10,
      approximateLines: 1,
      allowedSurahIds: {1},
      excludedQuestionKeys: {'1:1', '1:2'},
      random: Random(2),
    );

    expect(questions, hasLength(4));
    expect(questions.every((question) => question['surah_id'] == 1), isTrue);
    expect(questions.map((question) => question['key']), isNot(contains('1:1')));
  });

  test('limits a surah question to the requested ayah range', () {
    final questions = ExamQuestionGeneratorService.generate(
      surahs: surahs,
      category: 'surah',
      questionCount: 10,
      approximateLines: 1,
      selectedSurahId: 1,
      fromAyah: 3,
      toAyah: 4,
      random: Random(3),
    );

    expect(questions.map((question) => question['ayah_number']).toSet(), {3, 4});
  });
}

Surah _surah(
  int number, {
  required int juz,
  required int hizb,
  required int difficulty,
}) {
  const total = 6;
  return Surah(
    number: number,
    name: 'سورة $number',
    totalAyahs: total,
    juzStart: juz,
    pageStart: number,
    ayahs: List.generate(
      total,
      (index) => Ayah(
        id: number * 100 + index,
        surahNumber: number,
        number: index + 1,
        text: 'نص الآية ${index + 1}',
        page: number,
        juz: juz,
        hizb: hizb,
        quarter: 1,
        lines: 1,
        difficulty: difficulty,
      ),
    ),
  );
}
