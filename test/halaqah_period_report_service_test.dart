import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/models/student_period_report.dart';
import 'package:halaqah_teacher/services/halaqah_period_report_service.dart';

void main() {
  test('aggregates real student-period reports without lifetime totals', () {
    final first = _report(
      name: 'أحمد',
      memorizedAyahs: 20,
      revisedAyahs: 30,
      memorizedLines: 30,
      present: 4,
      late: 1,
      absent: 0,
      excused: 0,
      noRecitation: 0,
      positive: 5,
      negative: 1,
      score: 90,
    );
    final second = _report(
      name: 'بدر',
      memorizedAyahs: 10,
      revisedAyahs: 12,
      memorizedLines: 15,
      present: 2,
      late: 0,
      absent: 2,
      excused: 1,
      noRecitation: 2,
      positive: 1,
      negative: 3,
      score: 50,
    );

    final result = HalaqahPeriodReportService.calculate([first, second]);

    expect(result.studentCount, 2);
    expect(result.totalMemorizedAyahs, 30);
    expect(result.totalRevisedAyahs, 42);
    expect(result.totalMemorizedPages, 3);
    expect(result.attendanceRate, 70);
    expect(result.performanceScore, 70);
    expect(result.topStudents.first.student.name, 'أحمد');
    expect(result.attentionStudents.single.student.name, 'بدر');
    expect(result.positivePoints, 6);
    expect(result.negativePoints, 4);
  });
}

StudentPeriodReport _report({
  required String name,
  required int memorizedAyahs,
  required int revisedAyahs,
  required double memorizedLines,
  required int present,
  required int late,
  required int absent,
  required int excused,
  required int noRecitation,
  required int positive,
  required int negative,
  required int score,
}) {
  return StudentPeriodReport(
    student: Student(name: name),
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2026, 7, 7),
    days: const [],
    memorizedAyahs: memorizedAyahs,
    revisedAyahs: revisedAyahs,
    memorizedLines: memorizedLines,
    revisedLines: 0,
    presentDays: present,
    lateDays: late,
    absentDays: absent,
    excusedDays: excused,
    noRecitationDays: noRecitation,
    positivePoints: positive,
    negativePoints: negative,
    positiveEvents: 0,
    negativeEvents: 0,
    averageQuality: 0,
    performanceScore: score,
  );
}
