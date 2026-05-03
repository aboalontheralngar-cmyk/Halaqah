import 'package:uuid/uuid.dart';

class DailyRecord {
  final String id;
  final String studentId;
  final DateTime date;
  String attendance;
  DateTime? arrivalTime;
  String? absenceReason;
  String? absenceNote;
  bool memorizationDone;
  bool revisionDone;
  int memorizationAmount;
  int revisionAmount;
  String? memorizationNote;
  String? revisionNote;
  String? notes;
  DateTime createdAt;
  DateTime updatedAt;

  DailyRecord({
    String? id,
    required this.studentId,
    required this.date,
    this.attendance = 'absent',
    this.arrivalTime,
    this.absenceReason,
    this.absenceNote,
    this.memorizationDone = false,
    this.revisionDone = false,
    this.memorizationAmount = 0,
    this.revisionAmount = 0,
    this.memorizationNote,
    this.revisionNote,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date.toIso8601String().split('T')[0],
        'attendance': attendance,
        'arrival_time': arrivalTime?.toIso8601String(),
        'absence_reason': absenceReason,
        'absence_note': absenceNote,
        'memorization_done': memorizationDone ? 1 : 0,
        'revision_done': revisionDone ? 1 : 0,
        'memorization_amount': memorizationAmount,
        'revision_amount': revisionAmount,
        'memorization_note': memorizationNote,
        'revision_note': revisionNote,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory DailyRecord.fromMap(Map<String, dynamic> map) => DailyRecord(
        id: map['id'],
        studentId: map['student_id'],
        date: DateTime.parse(map['date']),
        attendance: map['attendance'] ?? 'absent',
        arrivalTime: map['arrival_time'] != null
            ? DateTime.parse(map['arrival_time'])
            : null,
        absenceReason: map['absence_reason'],
        absenceNote: map['absence_note'],
        memorizationDone: map['memorization_done'] == 1,
        revisionDone: map['revision_done'] == 1,
        memorizationAmount: map['memorization_amount'] ?? 0,
        revisionAmount: map['revision_amount'] ?? 0,
        memorizationNote: map['memorization_note'],
        revisionNote: map['revision_note'],
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );

  DailyRecord copyWith({
    String? attendance,
    DateTime? arrivalTime,
    String? absenceReason,
    String? absenceNote,
    bool? memorizationDone,
    bool? revisionDone,
    int? memorizationAmount,
    int? revisionAmount,
    String? memorizationNote,
    String? revisionNote,
    String? notes,
  }) {
    return DailyRecord(
      id: id,
      studentId: studentId,
      date: date,
      attendance: attendance ?? this.attendance,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      absenceReason: absenceReason ?? this.absenceReason,
      absenceNote: absenceNote ?? this.absenceNote,
      memorizationDone: memorizationDone ?? this.memorizationDone,
      revisionDone: revisionDone ?? this.revisionDone,
      memorizationAmount: memorizationAmount ?? this.memorizationAmount,
      revisionAmount: revisionAmount ?? this.revisionAmount,
      memorizationNote: memorizationNote ?? this.memorizationNote,
      revisionNote: revisionNote ?? this.revisionNote,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
