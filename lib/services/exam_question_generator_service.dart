import 'dart:math';

import '../models/ayah.dart';

class ExamQuestionGeneratorService {
  const ExamQuestionGeneratorService._();

  static List<Map<String, dynamic>> generate({
    required List<Surah> surahs,
    required String category,
    required int questionCount,
    required double approximateLines,
    Set<int> allowedSurahIds = const {},
    int? selectedSurahId,
    int fromAyah = 1,
    int? toAyah,
    int fromJuz = 1,
    int toJuz = 30,
    int fromHizb = 1,
    int toHizb = 60,
    int difficulty = 0,
    Set<String> excludedQuestionKeys = const {},
    Random? random,
  }) {
    final candidates = <({Surah surah, Ayah ayah})>[];

    for (final surah in surahs) {
      if (category == 'memorized' && !allowedSurahIds.contains(surah.number)) {
        continue;
      }
      if (category == 'surah' && surah.number != selectedSurahId) continue;

      for (final ayah in surah.ayahs) {
        if (ayah.number < 1) continue;
        if (category == 'surah' &&
            (ayah.number < fromAyah || ayah.number > (toAyah ?? surah.totalAyahs))) {
          continue;
        }
        if (category == 'juz' && (ayah.juz < fromJuz || ayah.juz > toJuz)) {
          continue;
        }
        if (category == 'hizb' &&
            (ayah.hizb < fromHizb || ayah.hizb > toHizb)) {
          continue;
        }
        if (difficulty > 0 && ayah.difficulty != difficulty) continue;

        final key = '${surah.number}:${ayah.number}';
        if (excludedQuestionKeys.contains(key)) continue;
        candidates.add((surah: surah, ayah: ayah));
      }
    }

    candidates.shuffle(random ?? Random.secure());
    return candidates.take(questionCount).map((candidate) {
      final endAyah = _findAnswerEnd(
        candidate.surah,
        candidate.ayah.number,
        approximateLines,
        category: category,
        selectedToAyah: toAyah,
        fromJuz: fromJuz,
        toJuz: toJuz,
        fromHizb: fromHizb,
        toHizb: toHizb,
      );
      final answerAyahs = candidate.surah.getAyahRange(
        candidate.ayah.number,
        endAyah,
      );
      return <String, dynamic>{
        'key': '${candidate.surah.number}:${candidate.ayah.number}',
        'surah_id': candidate.surah.number,
        'surah_name': candidate.surah.name,
        'ayah_number': candidate.ayah.number,
        'to_ayah': endAyah,
        'page': candidate.ayah.page,
        'juz': candidate.ayah.juz,
        'hizb': candidate.ayah.hizb,
        'difficulty': candidate.ayah.difficulty,
        'question_type': 'recite_from',
        'start_text': candidate.ayah.text.split(' ').take(5).join(' '),
        'full_text': answerAyahs.map((ayah) => ayah.text).join(' '),
        'lines': answerAyahs.fold<double>(0, (sum, ayah) => sum + ayah.lines),
      };
    }).toList();
  }

  static int _findAnswerEnd(
    Surah surah,
    int startAyah,
    double approximateLines, {
    required String category,
    required int? selectedToAyah,
    required int fromJuz,
    required int toJuz,
    required int fromHizb,
    required int toHizb,
  }) {
    var lines = 0.0;
    var endAyah = startAyah;
    final target = approximateLines <= 0 ? 1.0 : approximateLines;
    for (var number = startAyah; number <= surah.totalAyahs; number++) {
      final ayah = surah.getAyah(number);
      if (ayah == null) continue;
      if (category == 'surah' && number > (selectedToAyah ?? surah.totalAyahs)) {
        break;
      }
      if (category == 'juz' && (ayah.juz < fromJuz || ayah.juz > toJuz)) {
        break;
      }
      if (category == 'hizb' &&
          (ayah.hizb < fromHizb || ayah.hizb > toHizb)) {
        break;
      }
      lines += ayah.lines <= 0 ? 0.5 : ayah.lines;
      endAyah = number;
      if (lines >= target) break;
    }
    return endAyah;
  }
}
