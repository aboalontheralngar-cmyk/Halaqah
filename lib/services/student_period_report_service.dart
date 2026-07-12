import '../models/behavior_point.dart';
import '../models/daily_record.dart';
import '../models/memorization.dart';
import '../models/student.dart';
import '../models/student_period_report.dart';
import '../models/student_hold.dart';
import '../models/settings.dart';
import '../models/vacation.dart';
import 'database_service.dart';
import 'quran_service.dart';

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
      holidayWeekdays: (results[7] as HalaqahSettings).holidayWeekdays,
      quran: _quran,
    );
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
    required Set<String> suspendedDates,
    required Map<String, String> suspensionReasons,
    required List<int> holidayWeekdays,
    required QuranService quran,
  }) {
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
            ? 30
            : record.attendance == 'late'
                ? 24
                : record.attendance == 'excused'
                    ? 18
                    : 0;
        if (attended && heard) score += 35;
        if (attended && reviewed) score += 15;
        if (qualityItems.isNotEmpty) score += ((quality / 5) * 15).round();
        score += pointBalance.clamp(-5, 5).toInt();
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
      ));
    }

    final memorization = progress.where((item) => !item.isRevision).toList();
    final revision = progress.where((item) => item.isRevision).toList();
    final allQuality = progress.map((item) => item.qualityRating).toList();
    final scoredDays = days
        .where((day) => day.isRecitationRequiredDay && day.record != null)
        .toList();

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
          .where((day) => day.isStudyDay && day.record?.attendance == 'present')
          .length,
      lateDays: days
          .where((day) => day.isStudyDay && day.record?.attendance == 'late')
          .length,
      absentDays: days
          .where((day) => day.isStudyDay && day.record?.attendance == 'absent')
          .length,
      excusedDays: days
          .where((day) => day.isStudyDay && day.record?.attendance == 'excused')
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
    );
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
