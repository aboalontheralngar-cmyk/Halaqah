import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/behavior_point.dart';
import 'package:halaqah_teacher/models/daily_record.dart';
import 'package:halaqah_teacher/models/memorization.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/models/student_hold.dart';
import 'package:halaqah_teacher/models/vacation.dart';
import 'package:halaqah_teacher/models/settings.dart';
import 'package:halaqah_teacher/models/fund_transaction.dart';
import 'package:halaqah_teacher/services/quran_service.dart';
import 'package:halaqah_teacher/services/student_period_report_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await QuranService.instance.initialize();
  });

  test('calculates only the selected period and excludes suspended holidays', () {
    final student = Student(name: 'طالب الاختبار');
    final start = DateTime(2026, 7, 6);
    final end = DateTime(2026, 7, 12);
    final records = [
      _record(student.id, DateTime(2026, 7, 6), 'present', heard: true),
      _record(student.id, DateTime(2026, 7, 7), 'present'),
      _record(student.id, DateTime(2026, 7, 8), 'absent'),
      _record(student.id, DateTime(2026, 7, 9), 'absent'),
      _record(student.id, DateTime(2026, 7, 10), 'absent'),
      _record(student.id, DateTime(2026, 7, 11), 'excused'),
    ];
    final progress = [
      MemorizationProgress(
        studentId: student.id,
        surahId: 1,
        fromAyah: 1,
        toAyah: 5,
        date: DateTime(2026, 7, 6),
        qualityRating: 4,
      ),
      MemorizationProgress(
        studentId: student.id,
        surahId: 2,
        fromAyah: 1,
        toAyah: 3,
        date: DateTime(2026, 7, 6),
        qualityRating: 5,
        isRevision: true,
      ),
    ];

    final report = StudentPeriodReportService.calculate(
      student: student,
      startDate: start,
      endDate: end,
      records: records,
      progress: progress,
      points: [
        BehaviorPoint(
          studentId: student.id,
          type: 'positive',
          reason: 'extra_memorization',
          points: 2,
          date: DateTime(2026, 7, 6),
        ),
      ],
      vacations: [
        Vacation(
          studentId: student.id,
          startDate: DateTime(2026, 7, 11),
          endDate: DateTime(2026, 7, 11),
          reason: VacationReason.sick,
          notes: 'مراجعة الطبيب',
        ),
      ],
      holds: [
        StudentHold(
          studentId: student.id,
          startDate: DateTime(2026, 7, 7),
          endDate: DateTime(2026, 7, 7),
          reason: 'مراجعة إدارية',
        ),
      ],
      suspendedDates: {'2026-07-08'},
      suspensionReasons: {'2026-07-08': 'نشاط عام'},
      holidayWeekdays: const [DateTime.friday],
      quran: QuranService.instance,
    );

    expect(report.days, hasLength(7));
    expect(report.memorizedAyahs, 5);
    expect(report.revisedAyahs, 3);
    expect(report.presentDays, 2);
    expect(report.absentDays, 1);
    expect(report.excusedDays, 1);
    expect(report.noRecitationDays, 0);
    expect(report.positivePoints, 2);
    expect(report.days[2].isSuspended, isTrue);
    expect(report.days[4].isWeeklyHoliday, isTrue);
    expect(report.days[5].vacation?.notes, 'مراجعة الطبيب');
    expect(report.days[1].hold?.reason, 'مراجعة إدارية');
  });

  test('full daily plan with good quality reaches an encouraging score', () {
    final student = Student(
      name: 'طالب مجتهد',
      planType: 'ayahs',
      planAmount: 5,
    );
    final date = DateTime(2026, 7, 6);
    final report = StudentPeriodReportService.calculate(
      student: student,
      startDate: date,
      endDate: date,
      records: [_record(student.id, date, 'present', heard: true)],
      progress: [
        MemorizationProgress(
          studentId: student.id,
          surahId: 1,
          fromAyah: 1,
          toAyah: 5,
          date: date,
          qualityRating: 4,
        ),
      ],
      points: [
        BehaviorPoint(
          studentId: student.id,
          type: 'positive',
          reason: 'إنجاز المقرر اليومي (تلقائي)',
          points: 5,
          date: date,
        ),
      ],
      vacations: const [],
      suspendedDates: const {},
      suspensionReasons: const {},
      holidayWeekdays: const [],
      quran: QuranService.instance,
    );

    expect(report.performanceScore, greaterThanOrEqualTo(90));
  });

  test('separates violations and calculates late minutes and settlements', () {
    final student = Student(name: 'طالب المتابعة');
    final date = DateTime(2026, 7, 6);
    final report = StudentPeriodReportService.calculate(
      student: student,
      startDate: date,
      endDate: date,
      records: [
        DailyRecord(
          studentId: student.id,
          date: date,
          attendance: 'late',
          arrivalTime: DateTime(2026, 7, 6, 16, 25),
        ),
      ],
      progress: const [],
      points: [
        BehaviorPoint(
          studentId: student.id,
          type: 'negative',
          reason: 'غياب بدون عذر (تلقائي)',
          points: -10,
          date: date,
        ),
        BehaviorPoint(
          studentId: student.id,
          type: 'negative',
          reason: 'bad_behavior',
          points: -4,
          date: date,
        ),
      ],
      vacations: const [],
      fundTransactions: [
        FundTransaction(
          studentId: student.id,
          type: 'penalty',
          amount: 10,
          settledNegativePoints: 3,
          date: date,
        ),
      ],
      suspendedDates: const {},
      suspensionReasons: const {},
      holidayWeekdays: const [],
      settings: HalaqahSettings(normalStartTime: '16:00'),
      quran: QuranService.instance,
    );

    expect(report.totalLateMinutes, 25);
    expect(report.violationEvents, 1);
    expect(report.violationPoints, 4);
    expect(report.settledNegativePoints, 3);
    expect(report.outstandingNegativePoints, 11);
  });
}

DailyRecord _record(
  String studentId,
  DateTime date,
  String attendance, {
  bool heard = false,
}) {
  return DailyRecord(
    studentId: studentId,
    date: date,
    attendance: attendance,
    memorizationDone: heard,
  );
}
