import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/models/memorization.dart';
import 'package:halaqah_teacher/services/daily_excellence_service.dart';

void main() {
  final surah = Surah(
    number: 1,
    name: 'اختبار',
    totalAyahs: 4,
    juzStart: 1,
    pageStart: 1,
    ayahs: [
      _ayah(1, 1, 1),
      _ayah(2, 1, 1.5),
      _ayah(3, 2, 2),
      _ayah(4, 2, 1),
    ],
  );

  test('deduplicates overlapping daily recitation ranges', () {
    final progress = [
      _progress(1, 3),
      _progress(3, 4),
    ];
    expect(
      DailyExcellenceService.calculateActualAmount(
        progress: progress,
        surahs: {1: surah},
        unit: 'ayahs',
      ),
      4,
    );
    expect(
      DailyExcellenceService.calculateActualAmount(
        progress: progress,
        surahs: {1: surah},
        unit: 'pages',
      ),
      2,
    );
    expect(
      DailyExcellenceService.calculateActualAmount(
        progress: progress,
        surahs: {1: surah},
        unit: 'lines',
      ),
      5.5,
    );
    expect(
      DailyExcellenceService.calculateActualAmount(
        progress: progress,
        surahs: {1: surah},
        unit: 'hizbs',
      ),
      1,
    );
  });

  test('touching a page does not count as completing a full face', () {
    final partial = [_progress(1, 1)];
    final amount = DailyExcellenceService.calculateActualAmount(
      progress: partial,
      surahs: {1: surah},
      unit: 'pages',
    );
    expect(amount, closeTo(1 / 2.5, 0.0001));
    expect(DailyExcellenceService.qualifies(actualAmount: amount, planAmount: 1), isFalse);
  });

  test('a complete face is exactly one and does not look like an overrun', () {
    final fullFirstPage = [_progress(1, 2)];
    final amount = DailyExcellenceService.calculateActualAmount(
      progress: fullFirstPage,
      surahs: {1: surah},
      unit: 'pages',
    );
    expect(amount, 1);
    expect(
      DailyExcellenceService.qualifies(actualAmount: amount, planAmount: 1),
      isFalse,
    );
  });

  test('uses a safe line estimate when source line metadata is missing', () {
    final shortSurah = Surah(
      number: 2,
      name: 'قصيرة',
      totalAyahs: 2,
      juzStart: 30,
      pageStart: 604,
      ayahs: [
        Ayah(
          id: 1,
          surahNumber: 2,
          number: 1,
          text: 'آية 1',
          page: 604,
          juz: 30,
          hizb: 60,
          quarter: 240,
          lines: 0,
          difficulty: 1,
        ),
        Ayah(
          id: 2,
          surahNumber: 2,
          number: 2,
          text: 'آية 2',
          page: 604,
          juz: 30,
          hizb: 60,
          quarter: 240,
          lines: 0,
          difficulty: 1,
        ),
      ],
    );
    final progress = [
      MemorizationProgress(
        studentId: 'student',
        surahId: 2,
        fromAyah: 1,
        toAyah: 2,
        date: DateTime(2026, 8, 8),
      ),
    ];
    expect(
      DailyExcellenceService.calculateActualAmount(
        progress: progress,
        surahs: {2: shortSurah},
        unit: 'lines',
      ),
      1,
    );
  });

  test('requires a real increase above the plan', () {
    expect(
      DailyExcellenceService.qualifies(actualAmount: 5, planAmount: 5),
      isFalse,
    );
    expect(
      DailyExcellenceService.qualifies(actualAmount: 6, planAmount: 5),
      isTrue,
    );
    expect(
      DailyExcellenceService.exceededBy(actualAmount: 8, planAmount: 5),
      3,
    );
  });
}

MemorizationProgress _progress(int from, int to) => MemorizationProgress(
      studentId: 'student',
      surahId: 1,
      fromAyah: from,
      toAyah: to,
      date: DateTime(2026, 7, 12),
    );

Ayah _ayah(int number, int page, double lines) => Ayah(
      id: number,
      surahNumber: 1,
      number: number,
      text: 'آية $number',
      page: page,
      juz: 1,
      hizb: 1,
      quarter: 1,
      lines: lines,
      difficulty: 1,
    );
