import 'package:uuid/uuid.dart';

class Exam {
  final String id;
  final String studentId;
  final DateTime date;
  final String type;
  final int fromSurah;
  final int toSurah;
  final int? fromAyah;
  final int? toAyah;
  int score;
  String? notes;
  DateTime createdAt;

  Exam({
    String? id,
    required this.studentId,
    required this.date,
    this.type = 'oral',
    required this.fromSurah,
    required this.toSurah,
    this.fromAyah,
    this.toAyah,
    this.score = 0,
    this.notes,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  bool get isPassed => score >= 60;

  String get scoreGrade {
    if (score >= 90) return 'ممتاز';
    if (score >= 80) return 'جيد جداً';
    if (score >= 70) return 'جيد';
    if (score >= 60) return 'مقبول';
    return 'ضعيف';
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'date': date.toIso8601String().split('T')[0],
        'type': type,
        'from_surah': fromSurah,
        'to_surah': toSurah,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'score': score,
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Exam.fromMap(Map<String, dynamic> map) => Exam(
        id: map['id'],
        studentId: map['student_id'],
        date: DateTime.parse(map['date']),
        type: map['type'] ?? 'oral',
        fromSurah: map['from_surah'],
        toSurah: map['to_surah'],
        fromAyah: map['from_ayah'],
        toAyah: map['to_ayah'],
        score: map['score'] ?? 0,
        notes: map['notes'],
        createdAt: DateTime.parse(map['created_at']),
      );
}

class ExamType {
  static const String oral = 'oral';
  static const String written = 'written';

  static String getLabel(String type) {
    switch (type) {
      case oral:
        return 'شفهي';
      case written:
        return 'تحريري';
      default:
        return type;
    }
  }
}
