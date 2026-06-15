import 'package:uuid/uuid.dart';

class HomeworkGrade {
  final String id;
  final String studentId;
  final int surahId;
  final int fromAyah;
  final int toAyah;
  final DateTime date;
  final String gradeMark; // 'excellent' | 'very_good' | 'good' | 'needs_work' | 'absent'
  final int mistakesCount;
  final bool isRevision;
  final String? remark;
  final DateTime createdAt;

  HomeworkGrade({
    String? id,
    required this.studentId,
    required this.surahId,
    required this.fromAyah,
    required this.toAyah,
    required this.date,
    required this.gradeMark,
    this.mistakesCount = 0,
    this.isRevision = false,
    this.remark,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now();

  int get ayahCount => toAyah - fromAyah + 1;

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'surah_id': surahId,
        'from_ayah': fromAyah,
        'to_ayah': toAyah,
        'date': date.toIso8601String().split('T')[0],
        'grade_mark': gradeMark,
        'mistakes_count': mistakesCount,
        'is_revision': isRevision ? 1 : 0,
        'remark': remark,
        'created_at': createdAt.toIso8601String(),
      };

  factory HomeworkGrade.fromMap(Map<String, dynamic> map) => HomeworkGrade(
        id: map['id'],
        studentId: map['student_id'],
        surahId: map['surah_id'],
        fromAyah: map['from_ayah'],
        toAyah: map['to_ayah'],
        date: DateTime.parse(map['date']),
        gradeMark: map['grade_mark'] ?? 'good',
        mistakesCount: map['mistakes_count'] ?? 0,
        isRevision: map['is_revision'] == 1,
        remark: map['remark'],
        createdAt: DateTime.parse(map['created_at']),
      );

  // Helper translations for UI representation
  String get gradeMarkArabic {
    switch (gradeMark) {
      case 'excellent':
        return 'ممتاز';
      case 'very_good':
        return 'جيد جداً';
      case 'good':
        return 'جيد';
      case 'needs_work':
        return 'يحتاج تركيز';
      case 'absent':
        return 'غائب';
      default:
        return 'جيد';
    }
  }
}
