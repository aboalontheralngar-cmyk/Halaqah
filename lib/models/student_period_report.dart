import 'behavior_point.dart';
import 'daily_record.dart';
import 'memorization.dart';
import 'student.dart';
import 'student_hold.dart';
import 'vacation.dart';

class StudentPeriodDay {
  final DateTime date;
  final DailyRecord? record;
  final List<MemorizationProgress> memorization;
  final List<MemorizationProgress> revision;
  final List<BehaviorPoint> points;
  final Vacation? vacation;
  final StudentHold? hold;
  final bool isSuspended;
  final bool isWeeklyHoliday;
  final String? suspensionReason;
  final int performanceScore;

  const StudentPeriodDay({
    required this.date,
    required this.record,
    required this.memorization,
    required this.revision,
    required this.points,
    required this.vacation,
    required this.hold,
    required this.isSuspended,
    required this.isWeeklyHoliday,
    required this.suspensionReason,
    required this.performanceScore,
  });

  bool get isStudyDay => !isSuspended && !isWeeklyHoliday;
  bool get isRecitationRequiredDay => isStudyDay && hold == null;
  bool get attended =>
      record?.attendance == 'present' || record?.attendance == 'late';
  bool get memorizationDone =>
      memorization.isNotEmpty || (record?.memorizationDone ?? false);
  bool get revisionDone => revision.isNotEmpty || (record?.revisionDone ?? false);
  int get memorizedAyahs =>
      memorization.fold(0, (sum, item) => sum + item.ayahCount);
  int get revisedAyahs => revision.fold(0, (sum, item) => sum + item.ayahCount);
  int get positivePoints => points
      .where((item) => item.points > 0)
      .fold(0, (sum, item) => sum + item.points);
  int get negativePoints => points
      .where((item) => item.points < 0)
      .fold(0, (sum, item) => sum + item.points.abs());
}

class StudentPeriodReport {
  final Student student;
  final DateTime startDate;
  final DateTime endDate;
  final List<StudentPeriodDay> days;
  final int memorizedAyahs;
  final int revisedAyahs;
  final double memorizedLines;
  final double revisedLines;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int excusedDays;
  final int noRecitationDays;
  final int positivePoints;
  final int negativePoints;
  final int positiveEvents;
  final int negativeEvents;
  final double averageQuality;
  final int performanceScore;

  const StudentPeriodReport({
    required this.student,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.memorizedAyahs,
    required this.revisedAyahs,
    required this.memorizedLines,
    required this.revisedLines,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.excusedDays,
    required this.noRecitationDays,
    required this.positivePoints,
    required this.negativePoints,
    required this.positiveEvents,
    required this.negativeEvents,
    required this.averageQuality,
    required this.performanceScore,
  });

  double get memorizedPages => memorizedLines / 15;
  double get revisedPages => revisedLines / 15;
  double get memorizedJuz => memorizedPages / 20;
  int get attendanceTotal => presentDays + lateDays + absentDays + excusedDays;
  int get attendanceRate => attendanceTotal == 0
      ? 0
      : (((presentDays + lateDays) / attendanceTotal) * 100).round();
}
