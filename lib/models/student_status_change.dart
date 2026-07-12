import 'package:uuid/uuid.dart';

class StudentStatusChange {
  final String id;
  final String studentId;
  final String previousStatus;
  final String newStatus;
  final String reason;
  final String? notes;
  final DateTime changedAt;

  StudentStatusChange({
    String? id,
    required this.studentId,
    required this.previousStatus,
    required this.newStatus,
    required this.reason,
    this.notes,
    DateTime? changedAt,
  })  : id = id ?? const Uuid().v4(),
        changedAt = changedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'previous_status': previousStatus,
        'new_status': newStatus,
        'reason': reason,
        'notes': notes,
        'changed_at': changedAt.toIso8601String(),
      };

  factory StudentStatusChange.fromMap(Map<String, dynamic> map) =>
      StudentStatusChange(
        id: map['id']?.toString(),
        studentId: map['student_id'].toString(),
        previousStatus: map['previous_status']?.toString() ?? 'active',
        newStatus: map['new_status']?.toString() ?? 'active',
        reason: map['reason']?.toString() ?? 'تغيير حالة الطالب',
        notes: map['notes']?.toString(),
        changedAt: DateTime.tryParse(map['changed_at']?.toString() ?? '') ??
            DateTime.now(),
      );
}
