import 'package:uuid/uuid.dart';

class ExamTemplate {
  final String id;
  final String studentId;
  final String title;
  final String category;
  final String criteriaJson;
  final int questionsCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamTemplate({
    String? id,
    required this.studentId,
    required this.title,
    required this.category,
    required this.criteriaJson,
    required this.questionsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'title': title,
        'category': category,
        'criteria_json': criteriaJson,
        'questions_count': questionsCount,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory ExamTemplate.fromMap(Map<String, dynamic> map) => ExamTemplate(
        id: map['id'],
        studentId: map['student_id'],
        title: map['title'],
        category: map['category'],
        criteriaJson: map['criteria_json'] ?? '{}',
        questionsCount: map['questions_count'] ?? 0,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );
}

class ExamTemplateQuestion {
  final String id;
  final String templateId;
  final int questionOrder;
  final int surahId;
  final int toSurahId;
  final int fromAyah;
  final int toAyah;
  final String questionType;
  final String promptText;
  final String answerText;
  final int page;
  final int juz;
  final int hizb;
  final int difficulty;
  final double lines;
  final bool isAssessed;
  final int memorizationErrors;
  final int tashkeelErrors;
  final int recitationErrors;
  final int promptCount;
  final double questionScore;
  final DateTime createdAt;

  ExamTemplateQuestion({
    String? id,
    required this.templateId,
    required this.questionOrder,
    required this.surahId,
    int? toSurahId,
    required this.fromAyah,
    required this.toAyah,
    this.questionType = 'recite_from',
    required this.promptText,
    required this.answerText,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.difficulty,
    required this.lines,
    this.isAssessed = false,
    this.memorizationErrors = 0,
    this.tashkeelErrors = 0,
    this.recitationErrors = 0,
    this.promptCount = 0,
    this.questionScore = 0,
    DateTime? createdAt,
  })  : toSurahId = toSurahId ?? surahId,
        id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'template_id': templateId,
        'question_order': questionOrder,
        'surah_id': surahId,
        'to_surah_id': toSurahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'question_type': questionType,
        'prompt_text': promptText,
        'answer_text': answerText,
        'page': page,
        'juz': juz,
        'hizb': hizb,
        'difficulty': difficulty,
        'lines': lines,
        'is_assessed': isAssessed ? 1 : 0,
        'memorization_errors': memorizationErrors,
        'tashkeel_errors': tashkeelErrors,
        'recitation_errors': recitationErrors,
        'prompt_count': promptCount,
        'question_score': questionScore,
        'created_at': createdAt.toIso8601String(),
      };

  factory ExamTemplateQuestion.fromMap(Map<String, dynamic> map) =>
      ExamTemplateQuestion(
        id: map['id'],
        templateId: map['template_id'],
        questionOrder: map['question_order'],
        surahId: map['surah_id'],
        toSurahId: map['to_surah_id'] ?? map['surah_id'],
        fromAyah: map['from_ayah'],
        toAyah: map['to_ayah'],
        questionType: map['question_type'] ?? 'recite_from',
        promptText: map['prompt_text'] ?? '',
        answerText: map['answer_text'] ?? '',
        page: map['page'] ?? 0,
        juz: map['juz'] ?? 0,
        hizb: map['hizb'] ?? 0,
        difficulty: map['difficulty'] ?? 0,
        lines: (map['lines'] as num?)?.toDouble() ?? 0,
        isAssessed: map['is_assessed'] == true || map['is_assessed'] == 1,
        memorizationErrors: map['memorization_errors'] ?? 0,
        tashkeelErrors: map['tashkeel_errors'] ?? 0,
        recitationErrors: map['recitation_errors'] ?? 0,
        promptCount: map['prompt_count'] ?? 0,
        questionScore: (map['question_score'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(map['created_at']),
      );
}
