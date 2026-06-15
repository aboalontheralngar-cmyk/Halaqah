import 'package:uuid/uuid.dart';

class NotificationLog {
  final String id;
  final String studentId;
  final String type; // 'low_performance', 'repeated_absence', 'plan_completed', 'dismissal_warning', 'general'
  final String title;
  final String body;
  bool read;
  final DateTime createdAt;

  NotificationLog({
    String? id,
    required this.studentId,
    required this.type,
    required this.title,
    required this.body,
    this.read = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'type': type,
        'title': title,
        'body': body,
        'read': read ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory NotificationLog.fromMap(Map<String, dynamic> map) => NotificationLog(
        id: map['id'],
        studentId: map['student_id'],
        type: map['type'],
        title: map['title'],
        body: map['body'],
        read: map['read'] == 1,
        createdAt: DateTime.parse(map['created_at']),
      );
}
