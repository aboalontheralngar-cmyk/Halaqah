import '../models/behavior_point.dart';
import '../models/daily_record.dart';
import '../models/exam.dart';
import '../models/memorization.dart';
import '../models/student.dart';
import '../models/student_period_report.dart';
import '../models/student_hold.dart';
import '../models/settings.dart';
import '../models/vacation.dart';
import '../models/fund_transaction.dart';
import 'database_service.dart';
import 'quran_service.dart';
import 'daily_excellence_service.dart';
import '../utils/prayer_time_helper.dart';

class StudentPeriodReportService {
  final DatabaseService _db;
  final QuranService _quran;

  StudentPeriodReportService({
    DatabaseService? database,
    QuranService? quran,
  })  : _db = database ?? DatabaseService(),
        _quran = quran ?? QuranService.instance;

  Future<StudentPeriodReport> generate({
    required Student student,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError('تاريخ النهاية يجب ألا يسبق تاريخ البداية');
    }

    final results = await Future.wait<dynamic>([
      _db.getStudentRecordsInRange(student.id, start, end),
      _db.getStudentMemorizationInRange(student.id, start, end),
      _db.getStudentBehaviorPointsInRange(student.id, start, end),
      _db.getStudentVacationsInRange(student.id, start, end),
      _db.getStudentHoldsInRange(student.id, start, end),
      _db.getSuspendedDates(),
      _db.getSuspensionReasons(),
      _db.getStudentFundTransactionsInRange(student.id, start, end),
      _db.getStudentExamsInRange(student.id, start, end),
      _db.getSettings(),
    ]);

    return calculate(
      student: student,
      startDate: start,
      endDate: end,
      records: results[0] as List<DailyRecord>,
      progress: results[1] as List<MemorizationProgress>,
      points: results[2] as List<BehaviorPoint>,
      vacations: results[3] as List<Vacation>,
      holds: results[4] as List<StudentHold>,
      suspendedDates: (results[5] as List<String>).toSet(),
      suspensionReasons: results[6] as Map<String, String>,
      fundTransactions: results[7] as List<FundTransaction>,
      exams: results[8] as List<Exam>,
      settings: results[9] as HalaqahSettings,
      holidayWeekdays: (results[9] as HalaqahSettings).holidayWeekdays,
      quran: _quran,
    );
  }

  /// يولد تقارير عدة طلاب مع قراءة بيانات الحلقة المشتركة مرة واحدة فقط.
  Future<List<StudentPeriodReport>> generateForStudents({
    required List<Student> students,
    required DateTime startDate,
    required DateTime endDate,
    void Function(int completed, int total)? onProgress,
  }) async {
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    if (end.isBefore(start)) {
      throw ArgumentError('تاريخ النهاية يجب ألا يسبق تاريخ البداية');
    }
    if (students.isEmpty) return const [];

    // Bulk-load the period once. The previous implementation issued seven
    // student-specific queries for every student, which made monthly/all-student
    // reports progressively slower as a halaqah grew.
    final data = await Future.wait<dynamic>([
      _db.getSuspendedDates(),
      _db.getSuspensionReasons(),
      _db.getSettings(),
      _db.getDailyRecordsInRange(start, end),
      _db.getMemorizationInRange(start, end),
      _db.getBehaviorPointsInRange(start, end),
      _db.getVacationsInRange(start, end),
      _db.getAllStudentHoldsInRange(start, end),
      _db.getFundTransactionsInRange(start, end),
      _db.getExamsInRange(start, end),
    ]);
    final suspendedDates = (data[0] as List<String>).toSet();
    final suspensionReasons = data[1] as Map<String, String>;
    final settings = data[2] as HalaqahSettings;
    final recordsByStudent = _groupByStudent<DailyRecord>(
      data[3] as List<DailyRecord>,
      (item) => item.studentId,
    );
    final progressByStudent = _groupByStudent<MemorizationProgress>(
      data[4] as List<MemorizationProgress>,
      (item) => item.studentId,
    );
    final pointsByStudent = _groupByStudent<BehaviorPoint>(
      data[5] as List<BehaviorPoint>,
      (item) => item.studentId,
    );
    final vacationsByStudent = _groupByStudent<Vacation>(
      data[6] as List<Vacation>,
      (item) => item.studentId,
    );
    final holdsByStudent = _groupByStudent<StudentHold>(
      data[7] as List<StudentHold>,
      (item) => item.studentId,
    );
    final fundByStudent = _groupByStudent<FundTransaction>(
      data[8] as List<FundTransaction>,
      (item) => item.studentId ?? '',
    );
    final examsByStudent = _groupByStudent<Exam>(
      data[9] as List<Exam>,
      (item) => item.studentId,
    );

    final reports = <StudentPeriodReport>[];
    for (var index = 0; index < students.length; index++) {
      final student = students[index];
      reports.add(
        calculate(
          student: student,
          startDate: start,
          endDate: end,
          records: recordsByStudent[student.id] ?? const <DailyRecord>[],
          progress: progressByStudent[student.id] ?? const <MemorizationProgress>[],
          points: pointsByStudent[student.id] ?? const <BehaviorPoint>[],
          vacations: vacationsByStudent[student.id] ?? const <Vacation>[],
          holds: holdsByStudent[student.id] ?? const <StudentHold>[],
          fundTransactions: fundByStudent[student.id] ?? const <FundTransaction>[],
          exams: examsByStudent[student.id] ?? const <Exam>[],
          suspendedDates: suspendedDates,
          suspensionReasons: suspensionReasons,
          holidayWeekdays: settings.holidayWeekdays,
          settings: settings,
          quran: _quran,
        ),
      );
      onProgress?.call(index + 1, students.length);
    }
    return _withTopThreeRanks(reports);
  }

  static Map<String, List<T>> _groupByStudent<T>(
    Iterable<T> items,
    String Function(T item) studentIdOf,
  ) {
    final result = <String, List<T>>{};
    for (final item in items) {
      final studentId = studentIdOf(item);
      if (studentId.isEmpty) continue;
      result.putIfAbsent(studentId, () => <T>[]).add(item);
    }
    return result;
  }

  static StudentPeriodReport calculate({
    required Student student,
    required DateTime startDate,
    required DateTime endDate,
    required List<DailyRecord> records,
    required List<MemorizationProgress> progress,
    required List<BehaviorPoint> points,
    required List<Vacation> vacations,
    List<StudentHold> holds = const [],
    List<FundTransaction> fundTransactions = const [],
    List<Exam> exams = const [],
    required Set<String> suspendedDates,
    required Map<String, String> suspensionReasons,
    required List<int> holidayWeekdays,
    HalaqahSettings? settings,
    required QuranService quran,
  }) {
    final surahsById = {for (final surah in quran.surahs) surah.number: surah};
    final recordsByDate = {for (final item in records) _key(item.date): item};
    final progressByDate = <String, List<MemorizationProgress>>{};
    for (final item in progress) {
      progressByDate.putIfAbsent(_key(item.date), () => []).add(item);
    }
    final pointsByDate = <String, List<BehaviorPoint>>{};
    for (final item in points) {
      pointsByDate.putIfAbsent(_key(item.date), () => []).add(item);
    }

    final days = <StudentPeriodDay>[];
    for (var date = _dateOnly(startDate);
        !date.isAfter(_dateOnly(endDate));
        date = date.add(const Duration(days: 1))) {
      final key = _key(date);
      final dailyProgress = progressByDate[key] ?? const [];
      final memorization = dailyProgress.where((item) => !item.isRevision).toList();
      final revision = dailyProgress.where((item) => item.isRevision).toList();
      Vacation? vacation;
      for (final item in vacations) {
        if (item.approved && item.isDateInVacation(date)) {
          vacation = item;
          break;
        }
      }
      StudentHold? hold;
      for (final item in holds) {
        if (item.isActiveAt(date)) {
          hold = item;
          break;
        }
      }
      final record = recordsByDate[key];
      final dailyPoints = pointsByDate[key] ?? const [];
      final suspended = suspendedDates.contains(key);
      final weeklyHoliday = holidayWeekdays.contains(date.weekday);
      final lateMinutes = _lateMinutes(record, settings);
      final qualityItems = [...memorization, ...revision];
      final quality = qualityItems.isEmpty
          ? 0.0
          : qualityItems.fold<int>(0, (sum, item) => sum + item.qualityRating) /
              qualityItems.length;
      final attended = record?.attendance == 'present' || record?.attendance == 'late';
      final heard = memorization.isNotEmpty || (record?.memorizationDone ?? false);
      final reviewed = revision.isNotEmpty || (record?.revisionDone ?? false);
      final pointBalance = dailyPoints.fold<int>(0, (sum, item) => sum + item.points);
      var score = 0;
      if (!suspended && !weeklyHoliday && record != null && hold == null) {
        score += record.attendance == 'present'
            ? 25
            : record.attendance == 'late'
                ? 20
                : record.attendance == 'excused'
                    ? 10
                    : 0;
        if (attended && heard) {
          var actual = DailyExcellenceService.calculateActualAmount(
            progress: memorization,
            surahs: surahsById,
            unit: student.planType,
          );
          if (actual <= 0 && record.memorizationDone) {
            actual = record.memorizationAmount.toDouble();
          }
          final ratio = actual / (student.planAmount <= 0 ? 1 : student.planAmount);
          score += (ratio.clamp(0, 1) * 40).round();
        }
        if (attended && reviewed) score += 10;
        if (qualityItems.isNotEmpty) score += ((quality / 5) * 25).round();
        score += pointBalance.clamp(-10, 10).toInt();
      }
      days.add(StudentPeriodDay(
        date: date,
        record: record,
        memorization: memorization,
        revision: revision,
        points: List<BehaviorPoint>.from(dailyPoints),
        vacation: vacation,
        hold: hold,
        isSuspended: suspended,
        isWeeklyHoliday: weeklyHoliday,
        suspensionReason: suspensionReasons[key],
        performanceScore: score.clamp(0, 100).toInt(),
        lateMinutes: lateMinutes,
      ));
    }

    final memorization = progress.where((item) => !item.isRevision).toList();
    final revision = progress.where((item) => item.isRevision).toList();
    final allQuality = progress.map((item) => item.qualityRating).toList();
    final scoredDays = days
        .where((day) => day.isRecitationRequiredDay && day.record != null)
        .toList();
    final violations = points
        .where((item) =>
            item.points < 0 &&
            !BehaviorReason.isAttendancePenalty(item.reason))
        .toList();
    final settledNegativePoints = fundTransactions
        .where((item) => item.type == 'penalty')
        .fold<int>(0, (sum, item) => sum + item.settledNegativePoints);

    return StudentPeriodReport(
      student: student,
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
      days: days,
      memorizedAyahs: memorization.fold(0, (sum, item) => sum + item.ayahCount),
      revisedAyahs: revision.fold(0, (sum, item) => sum + item.ayahCount),
      memorizedLines: _sumLines(memorization, quran),
      revisedLines: _sumLines(revision, quran),
      presentDays: days
          .where((day) => day.isAttendanceRequiredDay && day.record?.attendance == 'present')
          .length,
      lateDays: days
          .where((day) => day.isAttendanceRequiredDay && day.record?.attendance == 'late')
          .length,
      absentDays: days
          .where((day) => day.isAttendanceRequiredDay && day.record?.attendance == 'absent')
          .length,
      excusedDays: days
          .where((day) => day.isAttendanceRequiredDay && day.record?.attendance == 'excused')
          .length,
      noRecitationDays: days
          .where((day) =>
              day.isRecitationRequiredDay &&
              day.attended &&
              !day.memorizationDone)
          .length,
      positivePoints: points
          .where((item) => item.points > 0)
          .fold(0, (sum, item) => sum + item.points),
      negativePoints: points
          .where((item) => item.points < 0)
          .fold(0, (sum, item) => sum + item.points.abs()),
      positiveEvents: points.where((item) => item.points > 0).length,
      negativeEvents: points.where((item) => item.points < 0).length,
      averageQuality: allQuality.isEmpty
          ? 0
          : allQuality.reduce((a, b) => a + b) / allQuality.length,
      performanceScore: scoredDays.isEmpty
          ? 0
          : (scoredDays.fold<int>(
                    0,
                    (sum, day) => sum + day.performanceScore,
                  ) /
                  scoredDays.length)
              .round(),
      totalLateMinutes:
          days.fold<int>(0, (sum, day) => sum + day.lateMinutes),
      violationEvents: violations.length,
      violationPoints:
          violations.fold<int>(0, (sum, item) => sum + item.points.abs()),
      settledNegativePoints: settledNegativePoints,
      exams: List<Exam>.from(exams),
    );
  }

  static int _lateMinutes(DailyRecord? record, HalaqahSettings? settings) {
    if (record?.attendance != 'late' || record?.arrivalTime == null || settings == null) {
      return 0;
    }
    final start = PrayerTimeHelper.calculateClassTimes(settings, record!.date).start;
    return record.arrivalTime!.difference(start).inMinutes.clamp(0, 24 * 60).toInt();
  }

  static List<StudentPeriodReport> _withTopThreeRanks(
    List<StudentPeriodReport> reports,
  ) {
    final ordered = List<StudentPeriodReport>.from(reports)
      ..sort((left, right) {
        final byScore = right.performanceScore.compareTo(left.performanceScore);
        if (byScore != 0) return byScore;
        final byAttendance = right.attendanceRate.compareTo(left.attendanceRate);
        if (byAttendance != 0) return byAttendance;
        final byMemorization = right.memorizedAyahs.compareTo(left.memorizedAyahs);
        if (byMemorization != 0) return byMemorization;
        return left.student.name.compareTo(right.student.name);
      });
    final rankByStudent = <String, int>{};
    for (var index = 0; index < ordered.length && index < 3; index++) {
      rankByStudent[ordered[index].student.id] = index + 1;
    }
    return reports
        .map((report) => report.copyWithRank(rankByStudent[report.student.id]))
        .toList();
  }

  static double _sumLines(
    List<MemorizationProgress> progress,
    QuranService quran,
  ) {
    var lines = 0.0;
    for (final item in progress) {
      final ayahs = quran.getAyahRange(item.surahId, item.fromAyah, item.toAyah);
      lines += ayahs.fold<double>(
        0,
        (sum, ayah) => sum + (ayah.lines <= 0 ? 0.5 : ayah.lines),
      );
    }
    return lines;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
