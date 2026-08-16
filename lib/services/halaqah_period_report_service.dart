import 'dart:convert';

import '../models/halaqah_period_report.dart';
import '../models/student.dart';
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

  static const String _rankingExclusionsKeyPrefix =
      'report_ranking_excluded_student_ids';

  String _rankingExclusionsKey(DateTime startDate, DateTime endDate) =>
      '${_rankingExclusionsKeyPrefix}_${_dateKey(startDate)}_${_dateKey(endDate)}';

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  Future<Set<String>> getRankingExcludedStudentIds({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final raw = await _db.getSetting(_rankingExclusionsKey(startDate, endDate));
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> saveRankingExcludedStudentIds({
    required DateTime startDate,
    required DateTime endDate,
    required Set<String> studentIds,
  }) async {
    final ordered = studentIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList()
      ..sort();
    await _db.saveSetting(
      _rankingExclusionsKey(startDate, endDate),
      jsonEncode(ordered),
    );
  }

  Future<HalaqahPeriodReport> generate({
    required DateTime startDate,
    required DateTime endDate,
    void Function(int completed, int total)? onProgress,
  }) async {
    final values = await Future.wait<dynamic>([
      _db.getStudents(status: 'active'),
      getRankingExcludedStudentIds(startDate: startDate, endDate: endDate),
    ]);
    final students = values[0] as List<Student>;
    final excludedStudentIds = values[1] as Set<String>;
    final reports = await _studentReports.generateForStudents(
      students: students,
      startDate: startDate,
      endDate: endDate,
      onProgress: onProgress,
    );
    return calculate(
      reports,
      rankingExcludedStudentIds: excludedStudentIds,
    );
  }

  static HalaqahPeriodReport calculate(
    List<StudentPeriodReport> reports, {
    Set<String> rankingExcludedStudentIds = const <String>{},
  }) {
    if (reports.isEmpty) {
      final today = DateTime.now();
      return HalaqahPeriodReport(
        startDate: DateTime(today.year, today.month, today.day),
        endDate: DateTime(today.year, today.month, today.day),
        students: const [],
        totalMemorizedAyahs: 0,
        totalRevisedAyahs: 0,
        totalMemorizedPages: 0,
        totalRevisedPages: 0,
        totalRecitedPages: 0,
        totalPaidAmount: 0,
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
        rankingExcludedStudentIds: rankingExcludedStudentIds,
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
      totalRevisedPages:
          reports.fold(0.0, (sum, item) => sum + item.revisedPages),
      totalRecitedPages:
          reports.fold(0.0, (sum, item) => sum + item.recitedPages),
      totalPaidAmount:
          reports.fold(0.0, (sum, item) => sum + item.paidAmount),
      presentDays: present,
      lateDays: late,
      absentDays: absent,
      excusedDays: excused,
      noRecitationDays:
          reports.fold(0, (sum, item) => sum + item.noRecitationDays),
      positivePoints:
          reports.fold<double>(0, (sum, item) => sum + item.positivePoints),
      negativePoints:
          reports.fold<double>(0, (sum, item) => sum + item.negativePoints),
      attendanceRate: attendanceTotal == 0
          ? 0
          : (((present + late) / attendanceTotal) * 100).round(),
      performanceScore: scored.isEmpty
          ? 0
          : (scored.fold<int>(0, (sum, item) => sum + item.performanceScore) /
                  scored.length)
              .round(),
      studyDays: studyDays,
      rankingExcludedStudentIds: rankingExcludedStudentIds,
    );
  }
}
