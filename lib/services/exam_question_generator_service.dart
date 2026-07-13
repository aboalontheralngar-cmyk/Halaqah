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
    Set<int> allowedQuarterIds = const {},
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
    final allAyahs = <({Surah surah, Ayah ayah})>[
      for (final surah in surahs)
        for (final ayah in surah.ayahs)
          if (ayah.number > 0) (surah: surah, ayah: ayah),
    ];
    final candidates = <int>[];

    for (var index = 0; index < allAyahs.length; index++) {
      final item = allAyahs[index];
      if (!_isAllowed(
        item.surah,
        item.ayah,
        category: category,
        allowedSurahIds: allowedSurahIds,
        allowedQuarterIds: allowedQuarterIds,
        selectedSurahId: selectedSurahId,
        fromAyah: fromAyah,
        toAyah: toAyah,
        fromJuz: fromJuz,
        toJuz: toJuz,
        fromHizb: fromHizb,
        toHizb: toHizb,
      )) {
        continue;
      }
      if (difficulty > 0 && item.ayah.difficulty != difficulty) continue;

      final key = '${item.surah.number}:${item.ayah.number}';
      if (!excludedQuestionKeys.contains(key)) candidates.add(index);
    }

    candidates.shuffle(random ?? Random.secure());
    return candidates.take(questionCount).map((startIndex) {
      final start = allAyahs[startIndex];
      final answer = _collectAnswer(
        allAyahs,
        startIndex,
        approximateLines,
        category: category,
        allowedSurahIds: allowedSurahIds,
        allowedQuarterIds: allowedQuarterIds,
        selectedSurahId: selectedSurahId,
        fromAyah: fromAyah,
        toAyah: toAyah,
        fromJuz: fromJuz,
        toJuz: toJuz,
        fromHizb: fromHizb,
        toHizb: toHizb,
      );
      final end = answer.last;
      return <String, dynamic>{
        'key': '${start.surah.number}:${start.ayah.number}',
        'surah_id': start.surah.number,
        'surah_name': start.surah.name,
        'ayah_number': start.ayah.number,
        'to_surah_id': end.surah.number,
        'to_surah_name': end.surah.name,
        'to_ayah': end.ayah.number,
        'page': start.ayah.page,
        'juz': start.ayah.juz,
        'hizb': start.ayah.hizb,
        'quarter': start.ayah.quarter,
        'difficulty': start.ayah.difficulty,
        'question_type': 'recite_from',
        'start_text': start.ayah.text.split(' ').take(5).join(' '),
        'full_text': answer.map((item) => item.ayah.text).join(' '),
        'lines': answer.fold<double>(
          0,
          (sum, item) => sum + (item.ayah.lines <= 0 ? 0.5 : item.ayah.lines),
        ),
        'is_assessed': false,
        'memorization_errors': 0,
        'tashkeel_errors': 0,
        'recitation_errors': 0,
        'prompt_count': 0,
        'question_score': 0.0,
      };
    }).toList();
  }

  static List<({Surah surah, Ayah ayah})> _collectAnswer(
    List<({Surah surah, Ayah ayah})> allAyahs,
    int startIndex,
    double approximateLines, {
    required String category,
    required Set<int> allowedSurahIds,
    required Set<int> allowedQuarterIds,
    required int? selectedSurahId,
    required int fromAyah,
    required int? toAyah,
    required int fromJuz,
    required int toJuz,
    required int fromHizb,
    required int toHizb,
  }) {
    final answer = <({Surah surah, Ayah ayah})>[];
    final target = approximateLines <= 0 ? 1.0 : approximateLines;
    var lines = 0.0;

    for (var index = startIndex; index < allAyahs.length; index++) {
      final item = allAyahs[index];
      if (!_isAllowed(
        item.surah,
        item.ayah,
        category: category,
        allowedSurahIds: allowedSurahIds,
        allowedQuarterIds: allowedQuarterIds,
        selectedSurahId: selectedSurahId,
        fromAyah: fromAyah,
        toAyah: toAyah,
        fromJuz: fromJuz,
        toJuz: toJuz,
        fromHizb: fromHizb,
        toHizb: toHizb,
      )) {
        break;
      }
      answer.add(item);
      lines += item.ayah.lines <= 0 ? 0.5 : item.ayah.lines;
      if (lines >= target) break;
    }
    return answer;
  }

  static bool _isAllowed(
    Surah surah,
    Ayah ayah, {
    required String category,
    required Set<int> allowedSurahIds,
    required Set<int> allowedQuarterIds,
    required int? selectedSurahId,
    required int fromAyah,
    required int? toAyah,
    required int fromJuz,
    required int toJuz,
    required int fromHizb,
    required int toHizb,
  }) {
    switch (category) {
      case 'memorized':
        return allowedSurahIds.contains(surah.number);
      case 'surah':
        return surah.number == selectedSurahId &&
            ayah.number >= fromAyah &&
            ayah.number <= (toAyah ?? surah.totalAyahs);
      case 'juz':
        return ayah.juz >= fromJuz && ayah.juz <= toJuz;
      case 'hizb':
        return ayah.hizb >= fromHizb && ayah.hizb <= toHizb;
      case 'mushaf':
        return allowedQuarterIds.contains(ayah.quarter);
      default:
        return false;
    }
  }
}
