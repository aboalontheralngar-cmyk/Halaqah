import 'package:uuid/uuid.dart';

enum DecayStatus {
  fresh,       // < 14 days
  aging,       // 14-30 days
  stale,       // > 30 days
  notStarted   // not started yet
}

class MushafProgress {
  final String id;
  final String studentId;
  final int hizbNumber; // 1-60
  final int thumunNumber; // 1-8
  final double averageGrade;
  final DateTime? lastGradedDate;
  final bool isPreMemorized;

  MushafProgress({
    String? id,
    required this.studentId,
    required this.hizbNumber,
    required this.thumunNumber,
    this.averageGrade = 0.0,
    this.lastGradedDate,
    this.isPreMemorized = false,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toMap() => {
        'id': id,
        'student_id': studentId,
        'hizb_number': hizbNumber,
        'thumun_number': thumunNumber,
        'average_grade': averageGrade,
        'last_graded_date': lastGradedDate?.toIso8601String().split('T')[0],
        'is_pre_memorized': isPreMemorized ? 1 : 0,
      };

  factory MushafProgress.fromMap(Map<String, dynamic> map) => MushafProgress(
        id: map['id'],
        studentId: map['student_id'],
        hizbNumber: map['hizb_number'] ?? 1,
        thumunNumber: map['thumun_number'] ?? 1,
        averageGrade: (map['average_grade'] as num?)?.toDouble() ?? 0.0,
        lastGradedDate: map['last_graded_date'] != null
            ? DateTime.parse(map['last_graded_date'])
            : null,
        isPreMemorized: map['is_pre_memorized'] == 1,
      );

  DecayStatus get decayStatus {
    if (lastGradedDate == null) {
      return isPreMemorized ? DecayStatus.fresh : DecayStatus.notStarted;
    }
    final days = DateTime.now().difference(lastGradedDate!).inDays;
    if (days < 14) {
      return DecayStatus.fresh;
    } else if (days <= 30) {
      return DecayStatus.aging;
    } else {
      return DecayStatus.stale;
    }
  }
}
