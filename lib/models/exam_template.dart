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
  final DateTime createdAt;

  ExamTemplateQuestion({
    String? id,
    required this.templateId,
    required this.questionOrder,
    required this.surahId,
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
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'template_id': templateId,
        'question_order': questionOrder,
        'surah_id': surahId,
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
        'created_at': createdAt.toIso8601String(),
      };

  factory ExamTemplateQuestion.fromMap(Map<String, dynamic> map) =>
      ExamTemplateQuestion(
        id: map['id'],
        templateId: map['template_id'],
        questionOrder: map['question_order'],
        surahId: map['surah_id'],
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
        createdAt: DateTime.parse(map['created_at']),
      );
}
