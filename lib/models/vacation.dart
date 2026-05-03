import 'package:uuid/uuid.dart';

class Vacation {
  final String id;
  final String studentId;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  bool approved;
  String? notes;
  DateTime createdAt;

  Vacation({
    String? id,
    required this.studentId,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.approved = true,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get durationDays => endDate.difference(startDate).inDays + 1;

  bool isDateInVacation(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return !dateOnly.isBefore(start) && !dateOnly.isAfter(end);
  }

  bool get isActive {
    final now = DateTime.now();
    return isDateInVacation(now);
  }

  bool get isPast {
    return DateTime.now().isAfter(endDate);
  }

  bool get isFuture {
    return DateTime.now().isBefore(startDate);
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'reason': reason,
        'approved': approved ? 1 : 0,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Vacation.fromMap(Map<String, dynamic> map) => Vacation(
        id: map['id'],
        studentId: map['student_id'],
        startDate: DateTime.parse(map['start_date']),
        endDate: DateTime.parse(map['end_date']),
        reason: map['reason'],
        approved: map['approved'] == 1,
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );
}

class VacationReason {
  static const String sick = 'sick';
  static const String travel = 'travel';
  static const String family = 'family';
  static const String exam = 'exam';
  static const String other = 'other';

  static String getLabel(String reason) {
    switch (reason) {
      case sick:
        return 'مرض';
      case travel:
        return 'سفر';
      case family:
        return 'ظرف عائلي';
      case exam:
        return 'امتحانات';
      case other:
        return 'أخرى';
      default:
        return reason;
    }
  }

  static List<Map<String, String>> getAll() {
    return [
      {'value': sick, 'label': 'مرض'},
      {'value': travel, 'label': 'سفر'},
      {'value': family, 'label': 'ظرف عائلي'},
      {'value': exam, 'label': 'امتحانات'},
      {'value': other, 'label': 'أخرى'},
    ];
  }
}
