import 'dart:convert';

import 'package:uuid/uuid.dart';

/// برنامج قرآني محدد المدة له أيام دراسة ومقررات مستقلة للحفظ والمراجعة.
class QuranCourse {
  final String id;
  final String title;
  final String type; // memorization | revision | mixed
  final DateTime startDate;
  final DateTime endDate;
  final String memorizationUnit;
  final int memorizationAmount;
  final String revisionUnit;
  final int revisionAmount;
  final List<int> studyWeekdays; // DateTime.monday .. DateTime.sunday
  final String status; // planned | active | completed | cancelled
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuranCourse({
    String? id,
    required this.title,
    this.type = 'mixed',
    required this.startDate,
    required this.endDate,
    this.memorizationUnit = 'ayahs',
    this.memorizationAmount = 5,
    this.revisionUnit = 'pages',
    this.revisionAmount = 2,
    this.studyWeekdays = const [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ],
    this.status = 'planned',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get includesMemorization => type == 'memorization' || type == 'mixed';
  bool get includesRevision => type == 'revision' || type == 'mixed';

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title.trim(),
        'type': type,
        'start_date': _dateKey(startDate),
        'end_date': _dateKey(endDate),
        'memorization_unit': memorizationUnit,
        'memorization_amount': memorizationAmount,
        'revision_unit': revisionUnit,
        'revision_amount': revisionAmount,
        'study_weekdays': jsonEncode(studyWeekdays),
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory QuranCourse.fromMap(Map<String, dynamic> map) => QuranCourse(
        id: map['id']?.toString(),
        title: map['title']?.toString() ?? '',
        type: map['type']?.toString() ?? 'mixed',
        startDate: DateTime.parse(map['start_date'].toString()),
        endDate: DateTime.parse(map['end_date'].toString()),
        memorizationUnit:
            map['memorization_unit']?.toString() ?? 'ayahs',
        memorizationAmount: (map['memorization_amount'] as num?)?.toInt() ?? 5,
        revisionUnit: map['revision_unit']?.toString() ?? 'pages',
        revisionAmount: (map['revision_amount'] as num?)?.toInt() ?? 2,
        studyWeekdays: _decodeWeekdays(map['study_weekdays']),
        status: map['status']?.toString() ?? 'planned',
        notes: map['notes']?.toString(),
        createdAt: DateTime.parse(map['created_at'].toString()),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.parse(map['created_at'].toString()),
      );

  QuranCourse copyWith({
    String? title,
    String? type,
    DateTime? startDate,
    DateTime? endDate,
    String? memorizationUnit,
    int? memorizationAmount,
    String? revisionUnit,
    int? revisionAmount,
    List<int>? studyWeekdays,
    String? status,
    String? notes,
    bool clearNotes = false,
  }) =>
      QuranCourse(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        startDate: startDate ?? this.startDate,
        endDate: endDate ?? this.endDate,
        memorizationUnit: memorizationUnit ?? this.memorizationUnit,
        memorizationAmount: memorizationAmount ?? this.memorizationAmount,
        revisionUnit: revisionUnit ?? this.revisionUnit,
        revisionAmount: revisionAmount ?? this.revisionAmount,
        studyWeekdays: studyWeekdays ?? this.studyWeekdays,
        status: status ?? this.status,
        notes: clearNotes ? null : (notes ?? this.notes),
        createdAt: createdAt,
        updatedAt: DateTime.now(),
      );

  static List<int> _decodeWeekdays(dynamic value) {
    if (value is List) {
      return value.map((item) => (item as num).toInt()).toList();
    }
    try {
      final decoded = jsonDecode(value?.toString() ?? '[]');
      if (decoded is List) {
        return decoded.map((item) => (item as num).toInt()).toList();
      }
    } catch (_) {}
    return const [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
    ];
  }

  static String _dateKey(DateTime value) =>
      DateTime(value.year, value.month, value.day).toIso8601String().split('T').first;
}

class QuranCourseEnrollment {
  final String id;
  final String courseId;
  final String studentId;
  final DateTime enrolledAt;
  final String status; // active | completed | withdrawn
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  QuranCourseEnrollment({
    String? id,
    required this.courseId,
    required this.studentId,
    DateTime? enrolledAt,
    this.status = 'active',
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        enrolledAt = enrolledAt ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'course_id': courseId,
        'student_id': studentId,
        'enrolled_at': enrolledAt.toIso8601String(),
        'status': status,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory QuranCourseEnrollment.fromMap(Map<String, dynamic> map) =>
      QuranCourseEnrollment(
        id: map['id']?.toString(),
        courseId: map['course_id'].toString(),
        studentId: map['student_id'].toString(),
        enrolledAt: DateTime.parse(map['enrolled_at'].toString()),
        status: map['status']?.toString() ?? 'active',
        notes: map['notes']?.toString(),
        createdAt: DateTime.parse(map['created_at'].toString()),
        updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
            DateTime.parse(map['created_at'].toString()),
      );
}
