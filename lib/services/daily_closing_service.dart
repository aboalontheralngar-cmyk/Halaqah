import 'package:sqflite/sqflite.dart';

import '../models/behavior_point.dart';
import '../models/daily_record.dart';
import '../models/student.dart';
import '../models/settings.dart';
import '../models/student_hold.dart';
import '../models/vacation.dart';
import '../utils/prayer_time_helper.dart';
import 'audit_log_service.dart';
import 'database_service.dart';

enum DailyClosingState {
  completed,
  absent,
  noRecitation,
  unrecorded,
  excused,
  held,
  activity,
  talaqqin,
  holiday,
}

class DailyClosingStudentItem {
  const DailyClosingStudentItem({
    required this.student,
    required this.state,
    this.record,
    this.detail,
  });

  final Student student;
  final DailyRecord? record;
  final DailyClosingState state;
  final String? detail;

  bool get needsAction => const {
        DailyClosingState.absent,
        DailyClosingState.noRecitation,
        DailyClosingState.unrecorded,
      }.contains(state);

  bool get isExempt => const {
        DailyClosingState.excused,
        DailyClosingState.held,
        DailyClosingState.activity,
        DailyClosingState.talaqqin,
        DailyClosingState.holiday,
      }.contains(state);
}

class DailyClosingSnapshot {
  const DailyClosingSnapshot({
    required this.date,
    required this.items,
    required this.isHoliday,
    required this.isPastEndTime,
    required this.alreadyClosed,
    this.wasAutomaticallyClosed = false,
    this.suspensionReason,
    this.closedAt,
  });

  final DateTime date;
  final List<DailyClosingStudentItem> items;
  final bool isHoliday;
  final bool isPastEndTime;
  final bool alreadyClosed;
  final bool wasAutomaticallyClosed;
  final String? suspensionReason;
  final DateTime? closedAt;

  int count(DailyClosingState state) =>
      items.where((item) => item.state == state).length;

  int get actionRequiredCount => items.where((item) => item.needsAction).length;
  int get completedCount => count(DailyClosingState.completed);
  int get absentCount => count(DailyClosingState.absent);
  int get noRecitationCount => count(DailyClosingState.noRecitation);
  int get unrecordedCount => count(DailyClosingState.unrecorded);
  int get exemptCount => items.where((item) => item.isExempt).length;

  bool get canClose => !isHoliday && isPastEndTime && !alreadyClosed;
}

class AutomaticDailyClosingResult {
  const AutomaticDailyClosingResult({
    required this.closedDates,
    required this.alreadyClosedDates,
    required this.exemptDates,
    required this.failedDates,
  });

  final List<DateTime> closedDates;
  final int alreadyClosedDates;
  final int exemptDates;
  final int failedDates;

  int get closedCount => closedDates.length;
  bool get hasFailures => failedDates > 0;
}

class DailyClosingResult {
  const DailyClosingResult({
    required this.recordsCreated,
    required this.recordsExcused,
    required this.absencePointsAdded,
    required this.noRecitationPointsAdded,
    required this.closedAt,
  });

  final int recordsCreated;
  final int recordsExcused;
  final int absencePointsAdded;
  final int noRecitationPointsAdded;
  final DateTime closedAt;

  int get totalPointsRecordsAdded =>
      absencePointsAdded + noRecitationPointsAdded;
}

class DailyClosingEvaluator {
  const DailyClosingEvaluator._();

  static DailyClosingState classify({
    required bool isHoliday,
    required bool hasApprovedVacation,
    required bool hasActiveHold,
    bool hasAttendanceExemptHold = false,
    required bool hasRecord,
    String? attendance,
    bool memorizationDone = false,
    bool revisionDone = false,
    bool talaqqinDone = false,
    bool recitationExempt = false,
  }) {
    if (isHoliday) return DailyClosingState.holiday;
    if (hasAttendanceExemptHold) return DailyClosingState.held;
    if (attendance == 'excused') return DailyClosingState.excused;
    if (attendance == 'present' || attendance == 'late') {
      if (memorizationDone || revisionDone) {
        return DailyClosingState.completed;
      }
      if (talaqqinDone) return DailyClosingState.talaqqin;
      if (recitationExempt) return DailyClosingState.activity;
      if (hasActiveHold) return DailyClosingState.held;
      return DailyClosingState.noRecitation;
    }
    if (hasApprovedVacation) return DailyClosingState.excused;
    if (!hasRecord) return DailyClosingState.unrecorded;
    if (attendance == 'absent') return DailyClosingState.absent;
    return DailyClosingState.unrecorded;
  }
}

/// Provides a reviewable, idempotent end-of-day workflow.
///
/// Missing attendance is never penalized silently while the class is running.
/// The teacher can review and close the current day after class. Any older day
/// left open is closed automatically on the next app start, using the exact
/// same atomic and idempotent transaction.
class DailyClosingService {
  DailyClosingService({
    DatabaseService? database,
    AuditLogService? auditLog,
  })  : _database = database ?? DatabaseService(),
        _auditLog = auditLog ?? AuditLogService(database: database);

  final DatabaseService _database;
  final AuditLogService _auditLog;

  static const absenceReason = 'غياب بدون عذر (تلقائي)';
  static const noRecitationReason = 'عدم التسميع (تلقائي)';

  Future<DailyClosingSnapshot> load({DateTime? date, DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final target = _dateOnly(date ?? clock);
    final dateKey = _dateKey(target);
    final results = await Future.wait<dynamic>([
      _database.getSettings(),
      _database.getOperationalStudents(),
      _database.getDailyRecordsForDate(target),
      _database.getAllVacations(),
      _database.getActiveStudentHolds(date: target),
      _database.isDateSuspended(target),
      _database.getSuspensionReasons(),
      _database.getSetting(_closedKey(target)),
      _database.getSetting(_modeKey(target)),
    ]);
    final settings = results[0] as HalaqahSettings;
    final students = results[1] as List<Student>;
    final records = results[2] as List<DailyRecord>;
    final vacations = results[3] as List<Vacation>;
    final holds = results[4] as List<StudentHold>;
    final isHoliday = results[5] as bool;
    final suspensionReasons = results[6] as Map<String, String>;
    final closedValue = results[7] as String?;
    final closeMode = results[8] as String?;
    final recordsByStudent = {
      for (final record in records) record.studentId: record,
    };
    final vacationByStudent = <String, Vacation>{};
    for (final vacation in vacations) {
      if (vacation.approved && vacation.isDateInVacation(target)) {
        vacationByStudent.putIfAbsent(vacation.studentId, () => vacation);
      }
    }
    final holdByStudent = {
      for (final hold in holds) hold.studentId: hold,
    };

    final items = <DailyClosingStudentItem>[];
    for (final student in students) {
      if (_dateOnly(student.joinDate).isAfter(target)) continue;
      final record = recordsByStudent[student.id];
      final vacation = vacationByStudent[student.id];
      final hold = holdByStudent[student.id];
      final state = DailyClosingEvaluator.classify(
        isHoliday: isHoliday,
        hasApprovedVacation: vacation != null,
        hasActiveHold: hold != null,
        hasAttendanceExemptHold: hold?.exemptsAttendance ?? false,
        hasRecord: record != null,
        attendance: record?.attendance,
        memorizationDone: record?.memorizationDone ?? false,
        revisionDone: record?.revisionDone ?? false,
        talaqqinDone: record?.talaqqinDone ?? false,
        recitationExempt: record?.recitationExempt ?? false,
      );
      items.add(DailyClosingStudentItem(
        student: student,
        record: record,
        state: state,
        detail: vacation != null
            ? 'إجازة معتمدة: ${VacationReason.getLabel(vacation.reason)}'
            : hold != null && state == DailyClosingState.held
                ? '${hold.exemptsAttendance ? 'متوقف مؤقتًا' : 'موقوف عن التسميع'}: ${hold.reason}'
                : state == DailyClosingState.activity
                    ? 'نشاط: ${DailyActivityType.label(record?.activityType)}'
                    : state == DailyClosingState.talaqqin
                        ? 'تلقين: ${record?.talaqqinAmount ?? 0} آية'
                        : null,
      ));
    }

    final classEnd = PrayerTimeHelper.calculateClassTimes(settings, target).end;
    final today = _dateOnly(clock);
    final pastEnd = target.isBefore(today) ||
        (target == today && !clock.isBefore(classEnd));

    return DailyClosingSnapshot(
      date: target,
      items: items,
      isHoliday: isHoliday,
      isPastEndTime: pastEnd,
      alreadyClosed: closedValue != null,
      wasAutomaticallyClosed: closeMode == 'automatic',
      suspensionReason: suspensionReasons[dateKey] ??
          (settings.isHolidayWeekday(target) ? 'إجازة أسبوعية' : null),
      closedAt: DateTime.tryParse(closedValue ?? ''),
    );
  }

  Future<DailyClosingResult> closeDay({
    DateTime? date,
    DateTime? now,
    bool automatic = false,
  }) async {
    final clock = now ?? DateTime.now();
    final snapshot = await load(date: date, now: clock);
    if (snapshot.isHoliday) {
      throw StateError('اليوم معلق أو إجازة، ولا يحتاج إلى إغلاق');
    }
    if (!snapshot.isPastEndTime) {
      throw StateError('لا يمكن إغلاق اليوم قبل انتهاء دوام الحلقة');
    }
    if (snapshot.alreadyClosed) {
      throw StateError('تم إغلاق هذا اليوم سابقًا');
    }

    final settings = await _database.getSettings();
    final absencePenalty = _negativeOrDefault(
      settings.pointsConfig['unexcused_absence'],
      -10,
    );
    final incompletePenalty = _negativeOrDefault(
      settings.pointsConfig['incomplete_penalty'],
      -3,
    );
    final dateKey = _dateKey(snapshot.date);
    var recordsCreated = 0;
    var recordsExcused = 0;
    var absencePointsAdded = 0;
    var noRecitationPointsAdded = 0;

    final db = await _database.database;
    await db.transaction((transaction) async {
      final existingClose = await transaction.query(
        'settings',
        columns: ['value'],
        where: 'key = ?',
        whereArgs: [_closedKey(snapshot.date)],
        limit: 1,
      );
      if (existingClose.isNotEmpty) {
        throw StateError('تم إغلاق هذا اليوم سابقًا');
      }

      for (final item in snapshot.items) {
        if (item.state == DailyClosingState.excused &&
            item.record?.attendance != 'excused') {
          final record = (item.record ?? DailyRecord(
            studentId: item.student.id,
            date: snapshot.date,
          )).copyWith(
            attendance: 'excused',
            absenceReason: 'إجازة معتمدة',
            notes: item.detail ?? 'إجازة معتمدة عند إغلاق اليوم',
          );
          await transaction.insert(
            'daily_records',
            record.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          recordsExcused++;
          continue;
        }

        var state = item.state;
        if (state == DailyClosingState.unrecorded) {
          final record = DailyRecord(
            studentId: item.student.id,
            date: snapshot.date,
            attendance: 'absent',
            absenceReason: 'بدون عذر',
            absenceNote: automatic
                ? 'سجل تلقائي بعد انتهاء اليوم دون إغلاق يدوي'
                : 'سجل تلقائي بعد مراجعة المعلم وإغلاق اليوم',
            notes: automatic
                ? 'أُنشئ عند الإغلاق التلقائي لليوم السابق'
                : 'أُنشئ تلقائيًا عند إغلاق اليوم',
          );
          await transaction.insert(
            'daily_records',
            record.toMap(),
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
          recordsCreated++;
          state = DailyClosingState.absent;
        }

        if (state == DailyClosingState.absent) {
          final inserted = await _insertPointIfMissing(
            transaction,
            studentId: item.student.id,
            date: snapshot.date,
            reason: absenceReason,
            points: absencePenalty,
            automatic: automatic,
          );
          if (inserted) absencePointsAdded++;
        } else if (state == DailyClosingState.noRecitation) {
          final inserted = await _insertPointIfMissing(
            transaction,
            studentId: item.student.id,
            date: snapshot.date,
            reason: noRecitationReason,
            points: incompletePenalty,
            automatic: automatic,
          );
          if (inserted) noRecitationPointsAdded++;
        }
      }

      await transaction.insert(
        'settings',
        {
          'key': _closedKey(snapshot.date),
          'value': clock.toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.abort,
      );
      await transaction.insert(
        'settings',
        {
          'key': _modeKey(snapshot.date),
          'value': automatic ? 'automatic' : 'manual',
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    try {
      await _auditLog.record(
        eventType: 'daily_operations_closed',
        entityType: 'daily_records',
        entityId: dateKey,
        details: {
          'records_created': recordsCreated,
          'records_excused': recordsExcused,
          'absence_points_added': absencePointsAdded,
          'no_recitation_points_added': noRecitationPointsAdded,
          'close_mode': automatic ? 'automatic' : 'manual',
        },
        now: clock,
      );
    } catch (_) {
      // The closing transaction has already committed; never report it as
      // failed because a secondary audit write could not be appended.
    }
    try {
      await _database.generateNotifications();
    } catch (_) {
      // Notifications are a post-close convenience and can be regenerated.
    }

    return DailyClosingResult(
      recordsCreated: recordsCreated,
      recordsExcused: recordsExcused,
      absencePointsAdded: absencePointsAdded,
      noRecitationPointsAdded: noRecitationPointsAdded,
      closedAt: clock,
    );
  }

  /// يغلق الأيام المنتهية التي تُركت بلا اعتماد يدوي.
  ///
  /// في أول تشغيل يبدأ الفحص من آخر يوم دراسة يسبق سلسلة الإجازات أو
  /// التعليقات المتصلة بيوم أمس، ثم يُحفظ آخر يوم فُحص حتى يمكن تعويض الأيام
  /// التي كان التطبيق مغلقًا فيها. حد الاستدراك يمنع معالجة تاريخ قديم جدًا
  /// دفعة واحدة عند ترقية نسخة قديمة.
  Future<AutomaticDailyClosingResult> closeOverdueDays({
    DateTime? now,
    int maxLookbackDays = 31,
  }) async {
    if (maxLookbackDays < 1) {
      throw ArgumentError.value(maxLookbackDays, 'maxLookbackDays');
    }
    final clock = now ?? DateTime.now();
    final yesterday = _dateOnly(clock).subtract(const Duration(days: 1));
    final lastSweepValue = await _database.getSetting(_automaticSweepKey);
    final lastSweep = DateTime.tryParse(lastSweepValue ?? '');
    var start = lastSweep == null
        ? yesterday
        : _dateOnly(lastSweep).add(const Duration(days: 1));
    final earliest = yesterday.subtract(Duration(days: maxLookbackDays - 1));
    if (start.isBefore(earliest)) start = earliest;

    // في أول تشغيل بعد ترقية/تثبيت النسخة كان البدء من «أمس» فقط يترك
    // آخر يوم دراسة مفتوحًا إذا كان أمس نفسه يومًا معلقًا. ارجع عبر سلسلة
    // أيام التعليق/الإجازة حتى أول يوم دراسة سابق، ثم ابدأ الاستدراك منه.
    if (lastSweep == null) {
      while (start.isAfter(earliest)) {
        final candidate = await load(date: start, now: clock);
        if (!candidate.isHoliday) break;
        start = start.subtract(const Duration(days: 1));
      }
    }

    final closedDates = <DateTime>[];
    var alreadyClosedDates = 0;
    var exemptDates = 0;
    var failedDates = 0;
    for (var day = start;
        !day.isAfter(yesterday);
        day = day.add(const Duration(days: 1))) {
      try {
        final snapshot = await load(date: day, now: clock);
        if (snapshot.isHoliday) {
          exemptDates++;
          continue;
        }
        if (snapshot.alreadyClosed) {
          alreadyClosedDates++;
          continue;
        }
        await closeDay(date: day, now: clock, automatic: true);
        closedDates.add(day);
      } catch (_) {
        failedDates++;
        break;
      }
    }

    if (failedDates == 0) {
      await _database.saveSetting(_automaticSweepKey, _dateKey(yesterday));
    }
    return AutomaticDailyClosingResult(
      closedDates: closedDates,
      alreadyClosedDates: alreadyClosedDates,
      exemptDates: exemptDates,
      failedDates: failedDates,
    );
  }

  Future<bool> _insertPointIfMissing(
    Transaction transaction, {
    required String studentId,
    required DateTime date,
    required String reason,
    required int points,
    required bool automatic,
  }) async {
    final existing = await transaction.query(
      'behavior_points',
      columns: ['id'],
      where: 'student_id = ? AND date = ? AND reason = ?',
      whereArgs: [studentId, _dateKey(date), reason],
      limit: 1,
    );
    if (existing.isNotEmpty) return false;
    await transaction.insert(
      'behavior_points',
      BehaviorPoint(
        studentId: studentId,
        type: 'negative',
        reason: reason,
        points: points,
        date: date,
        resolved: true,
        notes: automatic
            ? 'احتساب تلقائي بعد انتهاء اليوم دون إغلاق يدوي'
            : 'احتساب تلقائي بعد مراجعة المعلم وإغلاق اليوم',
      ).toMap(),
    );
    return true;
  }

  static int _negativeOrDefault(int? value, int fallback) =>
      value != null && value < 0 ? value : fallback;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKey(DateTime value) =>
      value.toIso8601String().split('T').first;

  static String _closedKey(DateTime date) =>
      'daily_operations_closed_${_dateKey(date)}';

  static String _modeKey(DateTime date) =>
      'daily_operations_close_mode_${_dateKey(date)}';

  static const _automaticSweepKey = 'daily_operations_last_automatic_sweep';
}
