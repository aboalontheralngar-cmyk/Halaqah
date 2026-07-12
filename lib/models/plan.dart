import 'package:uuid/uuid.dart';

class SmartPlan {
  final String id;
  final String studentId;
  final String period; // 'weekly', 'monthly'
  final DateTime startDate;
  final DateTime endDate;
  final String unit; // 'ayahs', 'pages', 'lines'
  final int newAmount;
  final int reviewAmount;
  final String status; // 'active', 'completed', 'cancelled'
  final String testStatus; // 'not_required', 'pending', 'passed', 'failed'
  final String? completionExamId;
  final DateTime? completedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  SmartPlan({
    String? id,
    required this.studentId,
    required this.period,
    required this.startDate,
    required this.endDate,
    this.unit = 'ayahs',
    this.newAmount = 5,
    this.reviewAmount = 10,
    this.status = 'active',
    this.testStatus = 'not_required',
    this.completionExamId,
    this.completedAt,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';
  bool get isWaitingForExam =>
      isCompleted && const ['pending', 'failed'].contains(testStatus);

  SmartPlan copyWith({
    String? period,
    DateTime? startDate,
    DateTime? endDate,
    String? unit,
    int? newAmount,
    int? reviewAmount,
    String? status,
    String? testStatus,
    String? completionExamId,
    bool clearCompletionExam = false,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    String? notes,
    bool clearNotes = false,
    DateTime? updatedAt,
  }) =>
      SmartPlan(
        id: id,
        studentId: studentId,
        period: period ?? this.period,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        unit: unit ?? this.unit,
        newAmount: newAmount ?? this.newAmount,
        reviewAmount: reviewAmount ?? this.reviewAmount,
        status: status ?? this.status,
        testStatus: testStatus ?? this.testStatus,
        completionExamId:
            clearCompletionExam ? null : (completionExamId ?? this.completionExamId),
        completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
        notes: clearNotes ? null : (notes ?? this.notes),
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'period': period,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'unit': unit,
        'new_amount': newAmount,
        'review_amount': reviewAmount,
        'status': status,
        'test_status': testStatus,
        'completion_exam_id': completionExamId,
        'completed_at': completedAt?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SmartPlan.fromMap(Map<String, dynamic> map) => SmartPlan(
        id: map['id'],
        studentId: map['student_id'],
        period: map['period'],
        startDate: DateTime.parse(map['start_date']),
        endDate: DateTime.parse(map['end_date']),
        unit: map['unit'] ?? 'ayahs',
        newAmount: map['new_amount'] ?? 5,
        reviewAmount: map['review_amount'] ?? 10,
        status: map['status'] ?? 'active',
        testStatus: map['test_status'] ?? 'not_required',
        completionExamId: map['completion_exam_id'],
        completedAt: map['completed_at'] == null
            ? null
            : DateTime.tryParse(map['completed_at'].toString()),
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: map['updated_at'] == null
            ? DateTime.parse(map['created_at'])
            : DateTime.parse(map['updated_at']),
      );
}
