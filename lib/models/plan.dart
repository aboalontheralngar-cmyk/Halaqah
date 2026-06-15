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
  final String? notes;
  final DateTime createdAt;

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
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

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
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
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
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );
}
