import '../models/halaqah_period_report.dart';
import '../models/student_period_report.dart';
import 'database_service.dart';
import 'student_period_report_service.dart';

class HalaqahPeriodReportService {
  final DatabaseService _db;
  final StudentPeriodReportService _studentReports;

  HalaqahPeriodReportService({DatabaseService? database})
      : _db = database ?? DatabaseService(),
        _studentReports = StudentPeriodReportService(
          database: database ?? DatabaseService(),
        );

  Future<HalaqahPeriodReport> generate({
    required DateTime startDate,
    required DateTime endDate,
    void Function(int completed, int total)? onProgress,
  }) async {
    final students = await _db.getStudents(status: 'active');
    final reports = await _studentReports.generateForStudents(
      students: students,
      startDate: startDate,
      endDate: endDate,
      onProgress: onProgress,
    );
    return calculate(reports);
  }

  static HalaqahPeriodReport calculate(List<StudentPeriodReport> reports) {
    if (reports.isEmpty) {
      final today = DateTime.now();
      return HalaqahPeriodReport(
        startDate: DateTime(today.year, today.month, today.day),
        endDate: DateTime(today.year, today.month, today.day),
        students: const [],
        totalMemorizedAyahs: 0,
        totalRevisedAyahs: 0,
        totalMemorizedPages: 0,
        presentDays: 0,
        lateDays: 0,
        absentDays: 0,
        excusedDays: 0,
        noRecitationDays: 0,
        positivePoints: 0,
        negativePoints: 0,
        attendanceRate: 0,
        performanceScore: 0,
        studyDays: 0,
      );
    }

    final summaries = reports
        .map(HalaqahStudentSummary.fromStudentReport)
        .toList()
      ..sort((a, b) => a.student.name.compareTo(b.student.name));
    final present = reports.fold<int>(0, (sum, item) => sum + item.presentDays);
    final late = reports.fold<int>(0, (sum, item) => sum + item.lateDays);
    final absent = reports.fold<int>(0, (sum, item) => sum + item.absentDays);
    final excused = reports.fold<int>(0, (sum, item) => sum + item.excusedDays);
    final attendanceTotal = present + late + absent + excused;
    final scored = reports.where((report) => report.attendanceTotal > 0).toList();
    final studyDays = reports.first.days.where((day) => day.isStudyDay).length;

    return HalaqahPeriodReport(
      startDate: reports.first.startDate,
      endDate: reports.first.endDate,
      students: summaries,
      totalMemorizedAyahs:
          reports.fold(0, (sum, item) => sum + item.memorizedAyahs),
      totalRevisedAyahs:
          reports.fold(0, (sum, item) => sum + item.revisedAyahs),
      totalMemorizedPages:
          reports.fold(0.0, (sum, item) => sum + item.memorizedPages),
      presentDays: present,
      lateDays: late,
      absentDays: absent,
      excusedDays: excused,
      noRecitationDays:
          reports.fold(0, (sum, item) => sum + item.noRecitationDays),
      positivePoints:
          reports.fold(0, (sum, item) => sum + item.positivePoints),
      negativePoints:
          reports.fold(0, (sum, item) => sum + item.negativePoints),
      attendanceRate: attendanceTotal == 0
          ? 0
          : (((present + late) / attendanceTotal) * 100).round(),
      performanceScore: scored.isEmpty
          ? 0
          : (scored.fold<int>(0, (sum, item) => sum + item.performanceScore) /
                  scored.length)
              .round(),
      studyDays: studyDays,
    );
  }
}
