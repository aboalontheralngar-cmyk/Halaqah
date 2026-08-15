import 'package:uuid/uuid.dart';

class DailyActivityType {
  const DailyActivityType._();

  static const lecture = 'lecture';
  static const activity = 'activity';
  static const league = 'league';
  static const dinner = 'dinner';
  static const sport = 'sport';
  static const culturalCompetition = 'cultural_competition';
  static const other = 'other';

  static const labels = <String, String>{
    lecture: 'محاضرة',
    activity: 'نشاط',
    league: 'دوري',
    dinner: 'عشاء',
    sport: 'رياضة',
    culturalCompetition: 'مسابقة ثقافية',
    other: 'أخرى',
  };

  static String label(String? value) => labels[value] ?? 'نشاط';
}

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
  bool talaqqinDone;
  int memorizationAmount;
  int revisionAmount;
  int talaqqinAmount;
  String? memorizationNote;
  String? revisionNote;
  String? talaqqinNote;
  String? activityType;
  String? activityNote;
  bool recitationExempt;
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
    this.talaqqinDone = false,
    this.memorizationAmount = 0,
    this.revisionAmount = 0,
    this.talaqqinAmount = 0,
    this.memorizationNote,
    this.revisionNote,
    this.talaqqinNote,
    this.activityType,
    this.activityNote,
    this.recitationExempt = false,
    this.notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get hasActivity => activityType != null && activityType!.isNotEmpty;

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
        'talaqqin_done': talaqqinDone ? 1 : 0,
        'memorization_amount': memorizationAmount,
        'revision_amount': revisionAmount,
        'talaqqin_amount': talaqqinAmount,
        'memorization_note': memorizationNote,
        'revision_note': revisionNote,
        'talaqqin_note': talaqqinNote,
        'activity_type': activityType,
        'activity_note': activityNote,
        'recitation_exempt': recitationExempt ? 1 : 0,
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
        talaqqinDone: map['talaqqin_done'] == 1,
        memorizationAmount: map['memorization_amount'] ?? 0,
        revisionAmount: map['revision_amount'] ?? 0,
        talaqqinAmount: map['talaqqin_amount'] ?? 0,
        memorizationNote: map['memorization_note'],
        revisionNote: map['revision_note'],
        talaqqinNote: map['talaqqin_note'],
        activityType: map['activity_type'],
        activityNote: map['activity_note'],
        recitationExempt: map['recitation_exempt'] == 1 ||
            map['recitation_exempt'] == true,
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
        updatedAt: DateTime.parse(map['updated_at']),
      );

  DailyRecord copyWith({
    String? attendance,
    DateTime? arrivalTime,
    bool clearArrivalTime = false,
    String? absenceReason,
    bool clearAbsenceReason = false,
    String? absenceNote,
    bool clearAbsenceNote = false,
    bool? memorizationDone,
    bool? revisionDone,
    bool? talaqqinDone,
    int? memorizationAmount,
    int? revisionAmount,
    int? talaqqinAmount,
    String? memorizationNote,
    String? revisionNote,
    String? talaqqinNote,
    String? activityType,
    bool clearActivityType = false,
    String? activityNote,
    bool clearActivityNote = false,
    bool? recitationExempt,
    String? notes,
  }) {
    return DailyRecord(
      id: id,
      studentId: studentId,
      date: date,
      attendance: attendance ?? this.attendance,
      arrivalTime: clearArrivalTime ? null : (arrivalTime ?? this.arrivalTime),
      absenceReason:
          clearAbsenceReason ? null : (absenceReason ?? this.absenceReason),
      absenceNote: clearAbsenceNote ? null : (absenceNote ?? this.absenceNote),
      memorizationDone: memorizationDone ?? this.memorizationDone,
      revisionDone: revisionDone ?? this.revisionDone,
      talaqqinDone: talaqqinDone ?? this.talaqqinDone,
      memorizationAmount: memorizationAmount ?? this.memorizationAmount,
      revisionAmount: revisionAmount ?? this.revisionAmount,
      talaqqinAmount: talaqqinAmount ?? this.talaqqinAmount,
      memorizationNote: memorizationNote ?? this.memorizationNote,
      revisionNote: revisionNote ?? this.revisionNote,
      talaqqinNote: talaqqinNote ?? this.talaqqinNote,
      activityType: clearActivityType ? null : (activityType ?? this.activityType),
      activityNote: clearActivityNote ? null : (activityNote ?? this.activityNote),
      recitationExempt: recitationExempt ?? this.recitationExempt,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
