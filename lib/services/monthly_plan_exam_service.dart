import 'dart:convert';

import '../models/ayah.dart';
import '../models/memorization.dart';
import 'memorized_content_service.dart';

class MonthlyPlanExamQuestion {
  final String section; // memorization | review
  final int index;
  final int surahId;
  final int fromAyah;
  final int toAyah;
  final String surahName;

  const MonthlyPlanExamQuestion({
    required this.section,
    required this.index,
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
    required this.surahName,
  });

  String get label => 'س$index — $surahName: $fromAyah–$toAyah';

  Map<String, dynamic> toJson() => {
        'section': section,
        'index': index,
        'surah_id': surahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'surah_name': surahName,
      };
}

class MonthlyPlanExamBreakdown {
  final List<int> memorizationQuestionScores;
  final List<int> reviewQuestionScores;
  final int memorizationPlanScore;
  final int reviewPlanScore;

  const MonthlyPlanExamBreakdown({
    required this.memorizationQuestionScores,
    required this.reviewQuestionScores,
    required this.memorizationPlanScore,
    required this.reviewPlanScore,
  });

  int get memorizationQuestions =>
      memorizationQuestionScores.fold(0, (sum, value) => sum + value);
  int get reviewQuestions =>
      reviewQuestionScores.fold(0, (sum, value) => sum + value);
  int get total => memorizationQuestions + reviewQuestions +
      memorizationPlanScore + reviewPlanScore;

  Map<String, dynamic> toJson() => {
        'memorization_questions': memorizationQuestionScores,
        'review_questions': reviewQuestionScores,
        'memorization_plan': memorizationPlanScore,
        'review_plan': reviewPlanScore,
        'total': total,
      };
}

class MonthlyPlanExamService {
  const MonthlyPlanExamService._();

  static int planComponentScore(double ratio) =>
      (ratio.clamp(0, 1).toDouble() * 20).round().clamp(0, 20).toInt();

  static List<MonthlyPlanExamQuestion> buildQuestions({
    required String section,
    required List<Surah> surahs,
    required Map<int, MemorizedAyahRange> fallbackRanges,
    required List<MemorizationProgress> periodProgress,
    int count = 3,
  }) {
    final surahById = {for (final surah in surahs) surah.number: surah};
    final candidates = <({int surahId, int from, int to})>[];
    final matching = periodProgress.where(
      (row) => section == 'review' ? row.isRevision : !row.isRevision,
    );
    for (final row in matching) {
      candidates.add((
        surahId: row.surahId,
        from: row.fromAyah,
        to: row.toAyah,
      ));
    }
    if (candidates.isEmpty) {
      for (final entry in fallbackRanges.entries) {
        candidates.add((
          surahId: entry.key,
          from: entry.value.fromAyah,
          to: entry.value.toAyah,
        ));
      }
    }
    if (candidates.isEmpty || count <= 0) return const [];

    candidates.sort((a, b) {
      final bySurah = a.surahId.compareTo(b.surahId);
      return bySurah != 0 ? bySurah : a.from.compareTo(b.from);
    });
    final questions = <MonthlyPlanExamQuestion>[];
    final usedStarts = <String>{};

    for (var i = 0; i < count; i++) {
      final sourceIndex = count == 1
          ? candidates.length ~/ 2
          : ((i * (candidates.length - 1)) / (count - 1)).round();
      final candidate = candidates[sourceIndex];
      final total = surahById[candidate.surahId]?.totalAyahs ?? candidate.to;
      final from = candidate.from.clamp(1, total).toInt();
      final to = candidate.to.clamp(from, total).toInt();
      final span = to - from + 1;

      // Spread the three questions through the available range. A five-ayah
      // window is used when possible; short ranges stay valid and may overlap.
      var start = span <= 5
          ? from
          : (from + ((i + 1) * (span - 1) / (count + 1)).floor())
              .clamp(from, to)
              .toInt();
      var key = '${candidate.surahId}:$start';
      if (usedStarts.contains(key) && span > 1) {
        for (var offset = 1; offset < span; offset++) {
          final alternative = (from + ((start - from + offset) % span))
              .clamp(from, to)
              .toInt();
          final alternativeKey = '${candidate.surahId}:$alternative';
          if (!usedStarts.contains(alternativeKey)) {
            start = alternative;
            key = alternativeKey;
            break;
          }
        }
      }
      usedStarts.add(key);
      final end = (start + 4).clamp(start, to).toInt();

      questions.add(MonthlyPlanExamQuestion(
        section: section,
        index: i + 1,
        surahId: candidate.surahId,
        fromAyah: start,
        toAyah: end,
        surahName:
            surahById[candidate.surahId]?.name ?? 'سورة ${candidate.surahId}',
      ));
    }
    return questions;
  }

  static String encodeNotes({
    required String planId,
    required MonthlyPlanExamBreakdown breakdown,
    required List<MonthlyPlanExamQuestion> questions,
    String? templateId,
    String? teacherNotes,
  }) => jsonEncode({
        'schema': 'monthly_plan_v2',
        'plan_id': planId,
        if (templateId != null) 'template_id': templateId,
        'breakdown': breakdown.toJson(),
        'questions': questions.map((question) => question.toJson()).toList(),
        if ((teacherNotes ?? '').trim().isNotEmpty)
          'teacher_notes': teacherNotes!.trim(),
      });
}
