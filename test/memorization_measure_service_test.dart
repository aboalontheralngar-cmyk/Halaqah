import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/services/memorization_measure_service.dart';

void main() {
  final surah = Surah(
    number: 1,
    name: 'اختبار',
    totalAyahs: 5,
    juzStart: 1,
    pageStart: 1,
    ayahs: [
      _ayah(number: 1, page: 1, lines: 1.0),
      _ayah(number: 2, page: 1, lines: 1.5),
      _ayah(number: 3, page: 2, lines: 2.0),
      _ayah(number: 4, page: 2, lines: 1.0),
      _ayah(number: 5, page: 3, lines: 3.0),
    ],
  );

  group('calculateToAyah', () {
    test('uses the requested ayah count and respects the surah boundary', () {
      expect(
        MemorizationMeasureService.calculateToAyah(
          surah: surah,
          fromAyah: 4,
          planType: 'ayahs',
          planAmount: 3,
        ),
        5,
      );
    });

    test('counts complete page numbers from the starting ayah', () {
      expect(
        MemorizationMeasureService.calculateToAyah(
          surah: surah,
          fromAyah: 2,
          planType: 'pages',
          planAmount: 2,
        ),
        4,
      );
    });

    test('accumulates line estimates until the plan is reached', () {
      expect(
        MemorizationMeasureService.calculateToAyah(
          surah: surah,
          fromAyah: 2,
          planType: 'lines',
          planAmount: 3,
        ),
        3,
      );
    });

    test('supports hizb plans without leaving the selected surah', () {
      expect(
        MemorizationMeasureService.calculateToAyah(
          surah: surah,
          fromAyah: 2,
          planType: 'hizbs',
          planAmount: 1,
        ),
        5,
      );
    });
  });

  test('line plans do not collapse when source line metadata is zero', () {
    final zeroLineSurah = Surah(
      number: 2,
      name: 'قصيرة',
      totalAyahs: 2,
      juzStart: 30,
      pageStart: 604,
      ayahs: [
        _ayah(number: 1, page: 604, lines: 0),
        _ayah(number: 2, page: 604, lines: 0),
      ],
    );
    expect(
      MemorizationMeasureService.calculateAmount(
        surah: zeroLineSurah,
        fromAyah: 1,
        toAyah: 2,
        planType: 'lines',
      ),
      1,
    );
  });

  group('exceedsPlan', () {
    test('supports ayah, page, and line plans', () {
      expect(
        MemorizationMeasureService.exceedsPlan(
          surah: surah,
          fromAyah: 1,
          toAyah: 3,
          planType: 'ayahs',
          planAmount: 2,
        ),
        isTrue,
      );
      expect(
        MemorizationMeasureService.calculateAmount(
          surah: surah,
          fromAyah: 1,
          toAyah: 5,
          planType: 'hizbs',
        ),
        closeTo(8.5 / 150, 0.0001),
      );
      expect(
        MemorizationMeasureService.exceedsPlan(
          surah: surah,
          fromAyah: 1,
          toAyah: 5,
          planType: 'pages',
          planAmount: 2,
        ),
        isFalse,
      );
      expect(
        MemorizationMeasureService.exceedsPlan(
          surah: surah,
          fromAyah: 1,
          toAyah: 3,
          planType: 'lines',
          planAmount: 4,
        ),
        isTrue,
      );
    });

    test('does not count a touched page as a complete face', () {
      final amount = MemorizationMeasureService.calculateAmount(
        surah: surah,
        fromAyah: 1,
        toAyah: 2,
        planType: 'pages',
      );
      expect(amount, closeTo(2.5 / 15, 0.0001));
      expect(
        MemorizationMeasureService.exceedsPlan(
          surah: surah,
          fromAyah: 1,
          toAyah: 2,
          planType: 'pages',
          planAmount: 1,
        ),
        isFalse,
      );
    });
  });
}

Ayah _ayah({
  required int number,
  required int page,
  required double lines,
}) {
  return Ayah(
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
}
