import 'package:uuid/uuid.dart';

class CompetitionEvent {
  final String id;
  final String title;
  final String category;
  final double maximumScore;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  CompetitionEvent({
    String? id,
    required this.title,
    required this.category,
    this.maximumScore = 100,
    this.status = 'active',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  CompetitionEvent copyWith({
    String? title,
    String? category,
    double? maximumScore,
    String? status,
  }) =>
      CompetitionEvent(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        maximumScore: maximumScore ?? this.maximumScore,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'category': category,
        'maximum_score': maximumScore,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompetitionEvent.fromMap(Map<String, dynamic> map) =>
      CompetitionEvent(
        id: map['id'],
        title: map['title'],
        category: map['category'] ?? 'عام',
        maximumScore:
            (map['maximum_score'] as num?)?.toDouble() ?? 100,
        status: map['status'] ?? 'active',
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );
}

class CompetitionResult {
  final String id;
  final String eventId;
  final String studentId;
  final String? templateId;
  final int obviousErrors;
  final int subtleErrors;
  final int promptCount;
  final int stopCount;
  final int tajweedErrors;
  final double score;
  final String? notes;
  final DateTime assessedAt;
  final DateTime updatedAt;

  CompetitionResult({
    String? id,
    required this.eventId,
    required this.studentId,
    this.templateId,
    this.obviousErrors = 0,
    this.subtleErrors = 0,
    this.promptCount = 0,
    this.stopCount = 0,
    this.tajweedErrors = 0,
    required this.score,
    this.notes,
    DateTime? assessedAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        assessedAt = assessedAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'event_id': eventId,
        'student_id': studentId,
        'template_id': templateId,
        'obvious_errors': obviousErrors,
        'subtle_errors': subtleErrors,
        'prompt_count': promptCount,
        'stop_count': stopCount,
        'tajweed_errors': tajweedErrors,
        'score': score,
        'notes': notes,
        'assessed_at': assessedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompetitionResult.fromMap(Map<String, dynamic> map) =>
      CompetitionResult(
        id: map['id'],
        eventId: map['event_id'],
        studentId: map['student_id'],
        templateId: map['template_id'],
        obviousErrors: map['obvious_errors'] ?? 0,
        subtleErrors: map['subtle_errors'] ?? 0,
        promptCount: map['prompt_count'] ?? 0,
        stopCount: map['stop_count'] ?? 0,
        tajweedErrors: map['tajweed_errors'] ?? 0,
        score: (map['score'] as num?)?.toDouble() ?? 0,
        notes: map['notes'],
        assessedAt: DateTime.parse(map['assessed_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );
}
