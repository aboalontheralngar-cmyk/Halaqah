import 'student.dart';
import 'student_period_report.dart';

class HalaqahStudentSummary {
  final Student student;
  final int performanceScore;
  final int attendanceRate;
  final int attendanceRecords;
  final int memorizedAyahs;
  final int revisedAyahs;
  final double memorizedPages;
  final int noRecitationDays;
  final int absentDays;
  final int positivePoints;
  final int negativePoints;

  const HalaqahStudentSummary({
    required this.student,
    required this.performanceScore,
    required this.attendanceRate,
    required this.attendanceRecords,
    required this.memorizedAyahs,
    required this.revisedAyahs,
    required this.memorizedPages,
    required this.noRecitationDays,
    required this.absentDays,
    required this.positivePoints,
    required this.negativePoints,
  });

  int get pointBalance => positivePoints - negativePoints;
  bool get needsAttention =>
      attendanceRecords > 0 &&
      (performanceScore < 60 || noRecitationDays >= 2 || absentDays >= 2);

  factory HalaqahStudentSummary.fromStudentReport(StudentPeriodReport report) =>
      HalaqahStudentSummary(
        student: report.student,
        performanceScore: report.performanceScore,
        attendanceRate: report.attendanceRate,
        attendanceRecords: report.attendanceTotal,
        memorizedAyahs: report.memorizedAyahs,
        revisedAyahs: report.revisedAyahs,
        memorizedPages: report.memorizedPages,
        noRecitationDays: report.noRecitationDays,
        absentDays: report.absentDays,
        positivePoints: report.positivePoints,
        negativePoints: report.negativePoints,
      );
}

class HalaqahPeriodReport {
  final DateTime startDate;
  final DateTime endDate;
  final List<HalaqahStudentSummary> students;
  final int totalMemorizedAyahs;
  final int totalRevisedAyahs;
  final double totalMemorizedPages;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int excusedDays;
  final int noRecitationDays;
  final int positivePoints;
  final int negativePoints;
  final int attendanceRate;
  final int performanceScore;
  final int studyDays;

  const HalaqahPeriodReport({
    required this.startDate,
    required this.endDate,
    required this.students,
    required this.totalMemorizedAyahs,
    required this.totalRevisedAyahs,
    required this.totalMemorizedPages,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.excusedDays,
    required this.noRecitationDays,
    required this.positivePoints,
    required this.negativePoints,
    required this.attendanceRate,
    required this.performanceScore,
    required this.studyDays,
  });

  double get totalMemorizedJuz => totalMemorizedPages / 20;
  int get studentCount => students.length;
  int get recitedStudentCount =>
      students.where((student) => student.memorizedAyahs > 0).length;

  List<HalaqahStudentSummary> get topStudents {
    final sorted = students
        .where((student) =>
            student.attendanceRecords > 0 ||
            student.memorizedAyahs > 0 ||
            student.revisedAyahs > 0 ||
            student.positivePoints > 0 ||
            student.negativePoints > 0)
        .toList()
      ..sort((a, b) {
        final score = b.performanceScore.compareTo(a.performanceScore);
        if (score != 0) return score;
        final memorization = b.memorizedAyahs.compareTo(a.memorizedAyahs);
        if (memorization != 0) return memorization;
        return a.student.name.compareTo(b.student.name);
      });
    return sorted.take(5).toList();
  }

  List<HalaqahStudentSummary> get attentionStudents {
    final flagged = students.where((student) => student.needsAttention).toList()
      ..sort((a, b) => a.performanceScore.compareTo(b.performanceScore));
    return flagged;
  }
}
