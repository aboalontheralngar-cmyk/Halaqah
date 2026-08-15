import 'package:uuid/uuid.dart';

class TalaqqinRecord {
  final String id;
  final String sessionId;
  final String studentId;
  final int surahId;
  final int fromAyah;
  final int toAyah;
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  TalaqqinRecord({
    String? id,
    String? sessionId,
    required this.studentId,
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
    required this.date,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        sessionId = sessionId ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'session_id': sessionId,
        'student_id': studentId,
        'surah_id': surahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'date': date.toIso8601String().split('T').first,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory TalaqqinRecord.fromMap(Map<String, dynamic> map) => TalaqqinRecord(
        id: map['id'],
        sessionId: map['session_id'],
        studentId: map['student_id'],
        surahId: map['surah_id'],
        fromAyah: map['from_ayah'],
        toAyah: map['to_ayah'],
        date: DateTime.parse(map['date']),
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );
}
