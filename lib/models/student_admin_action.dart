import 'package:uuid/uuid.dart';

class StudentAdminActionType {
  const StudentAdminActionType._();

  static const warning = 'warning';
  static const notice = 'notice';
  static const pledge = 'pledge';
  static const guardianContact = 'guardian_contact';
  static const administrative = 'administrative';
  static const other = 'other';

  static const labels = <String, String>{
    warning: 'إنذار',
    notice: 'تنبيه',
    pledge: 'تعهد',
    guardianContact: 'تواصل مع ولي الأمر',
    administrative: 'إجراء إداري',
    other: 'أخرى',
  };

  static String label(String value) => labels[value] ?? 'إجراء إداري';
}

class StudentAdminAction {
  final String id;
  final String studentId;
  final String actionType;
  final DateTime date;
  final String details;
  final String? followUp;
  final bool resolved;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudentAdminAction({
    String? id,
    required this.studentId,
    required this.actionType,
    required this.date,
    required this.details,
    this.followUp,
    this.resolved = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'action_type': actionType,
        'date': date.toIso8601String().split('T').first,
        'details': details,
        'follow_up': followUp,
        'resolved': resolved ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory StudentAdminAction.fromMap(Map<String, dynamic> map) =>
      StudentAdminAction(
        id: map['id'],
        studentId: map['student_id'],
        actionType: map['action_type'],
        date: DateTime.parse(map['date']),
        details: map['details'],
        followUp: map['follow_up'],
        resolved: map['resolved'] == 1 || map['resolved'] == true,
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );
}
