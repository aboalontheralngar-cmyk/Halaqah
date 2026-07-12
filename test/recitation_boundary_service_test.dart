import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/services/recitation_boundary_service.dart';

Ayah ayah(int number, {required int page, required int hizb}) => Ayah(
      id: number,
      surahNumber: 1,
      number: number,
      text: 'آية',
      page: page,
      juz: 1,
      hizb: hizb,
      quarter: 1,
      lines: 1,
      difficulty: 1,
    );

void main() {
  final surah = Surah(
    number: 1,
    name: 'اختبار',
    totalAyahs: 8,
    juzStart: 1,
    pageStart: 1,
    ayahs: [
      ayah(1, page: 1, hizb: 1),
      ayah(2, page: 1, hizb: 1),
      ayah(3, page: 2, hizb: 1),
      ayah(4, page: 2, hizb: 1),
      ayah(5, page: 2, hizb: 2),
      ayah(6, page: 3, hizb: 2),
      ayah(7, page: 3, hizb: 2),
      ayah(8, page: 3, hizb: 2),
    ],
  );

  test('end of page stays on the starting ayah page', () {
    expect(RecitationBoundaryService.endOfPage(surah, 3), 5);
  });

  test('end of hizb stays on the starting ayah hizb', () {
    expect(RecitationBoundaryService.endOfHizb(surah, 3), 4);
  });

  test('invalid start is clamped into the surah', () {
    expect(RecitationBoundaryService.endOfPage(surah, 99), 8);
  });
}
