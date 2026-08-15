import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/ayah.dart';
import 'package:halaqah_teacher/models/memorization.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/services/memorized_content_service.dart';

Surah _surah(int number, int total) => Surah(
      number: number,
      name: 'سورة $number',
      totalAyahs: total,
      juzStart: 1,
      pageStart: 1,
      ayahs: List.generate(
        total,
        (i) => Ayah(
          id: number * 1000 + i + 1,
          surahNumber: number,
          number: i + 1,
          text: '',
          page: 1,
          juz: 1,
          hizb: 1,
          quarter: 1,
          lines: 1,
          difficulty: 0,
        ),
      ),
    );

void main() {
  final surahs = List.generate(114, (i) => _surah(i + 1, 10));

  test('ascending direction infers everything behind the first frontier', () {
    final student = Student(name: 'A', memorizationDirection: 'asc');
    final rows = [
      MemorizationProgress(
        studentId: student.id,
        surahId: 3,
        fromAyah: 4,
        toAyah: 7,
        date: DateTime(2026, 8, 12),
        qualityRating: 4,
      ),
    ];
    final ranges = MemorizedContentService.buildRanges(
      student: student,
      progress: rows,
      mushafProgress: const [],
      surahs: surahs,
    );
    expect(ranges[1]!.toAyah, 10);
    expect(ranges[2]!.toAyah, 10);
    expect(ranges[3]!.fromAyah, 1);
    expect(ranges[3]!.toAyah, 7);
  });

  test('descending direction infers higher-numbered surahs as memorized', () {
    final student = Student(name: 'D', memorizationDirection: 'desc');
    final rows = [
      MemorizationProgress(
        studentId: student.id,
        surahId: 112,
        fromAyah: 3,
        toAyah: 6,
        date: DateTime(2026, 8, 12),
        qualityRating: 4,
      ),
    ];
    final ranges = MemorizedContentService.buildRanges(
      student: student,
      progress: rows,
      mushafProgress: const [],
      surahs: surahs,
    );
    expect(ranges[114]!.toAyah, 10);
    expect(ranges[113]!.toAyah, 10);
    expect(ranges[112]!.fromAyah, 1);
    expect(ranges[112]!.toAyah, 6);
  });
}
