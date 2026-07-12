import 'package:uuid/uuid.dart';

class StudentHold {
  final String id;
  final String studentId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final String? notes;
  final DateTime? endedAt;
  final DateTime createdAt;

  StudentHold({
    String? id,
    required this.studentId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.notes,
    this.endedAt,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool isActiveAt(DateTime date) {
    final target = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    if (target.isBefore(start) || target.isAfter(end)) return false;
    if (endedAt == null) return true;
    final endedDay = DateTime(endedAt!.year, endedAt!.month, endedAt!.day);
    return !target.isAfter(endedDay);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'reason': reason,
        'notes': notes,
        'ended_at': endedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory StudentHold.fromMap(Map<String, dynamic> map) => StudentHold(
        id: map['id'],
        studentId: map['student_id'],
        startDate: DateTime.parse(map['start_date']),
        endDate: DateTime.parse(map['end_date']),
        reason: map['reason'],
        notes: map['notes'],
        endedAt: map['ended_at'] == null ? null : DateTime.parse(map['ended_at']),
        createdAt: DateTime.parse(map['created_at']),
      );
}
