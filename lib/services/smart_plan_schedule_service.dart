import '../models/memorization.dart';
import '../models/plan.dart';
import '../models/plan_recitation_record.dart';
import '../models/settings.dart';
import '../models/student.dart';
import '../models/student_hold.dart';
import '../models/vacation.dart';
import 'database_service.dart';
import 'memorization_progression_service.dart';
import 'memorized_content_service.dart';
import 'quran_cross_surah_range_service.dart';
import 'quran_service.dart';
import 'revision_progression_service.dart';
import 'student_learning_policy.dart';

class SmartPlanDailyAssignment {
  final DateTime date;
  final String memorizationRange;
  final String reviewRange;
  final String recitationRange;
  final bool isStudyDay;
  final String? dayStatus;

  const SmartPlanDailyAssignment({
    required this.date,
    required this.memorizationRange,
    required this.reviewRange,
    required this.recitationRange,
    this.isStudyDay = true,
    this.dayStatus,
  });
}

class SmartPlanScheduleException implements Exception {
  final String message;

  const SmartPlanScheduleException(this.message);

  @override
  String toString() => message;
}

class _PlanCalendarDay {
  final DateTime date;
  final String? status;

  const _PlanCalendarDay(this.date, {this.status});

  bool get isStudyDay => status == null;
}

/// Generates exact Quran ranges for every real study day in a smart plan.
///
/// The schedule starts from the latest persisted cursor for each stream and
/// marks weekly holidays, study suspensions, approved vacations, and student
/// holds explicitly. Generation is read-only; recording an actual session
/// remains the source of truth for achievement.
class SmartPlanScheduleService {
  final DatabaseService _db;
  final QuranService _quran;

  SmartPlanScheduleService({DatabaseService? database, QuranService? quran})
      : _db = database ?? DatabaseService(),
        _quran = quran ?? QuranService.instance;

  Future<List<SmartPlanDailyAssignment>> generate({
    required SmartPlan plan,
    required Student student,
  }) async {
    await _quran.initialize();
    final values = await Future.wait<dynamic>([
      _db.getStudentMemorization(student.id),
      _db.getStudentMemorizedRanges(student.id),
      _db.getStudentPlanRecitationRecords(student.id),
      _db.getSuspendedDates(),
      _db.getSuspensionReasons(),
      _db.getSettings(),
      _db.getStudentVacationsInRange(student.id, plan.startDate, plan.endDate),
      _db.getStudentHoldsInRange(student.id, plan.startDate, plan.endDate),
    ]);
    final progress = values[0] as List<MemorizationProgress>;
    final memorizedRanges = values[1] as Map<int, MemorizedAyahRange>;
    final recitationRecords = values[2] as List<PlanRecitationRecord>;
    final suspendedDates = (values[3] as List<String>).toSet();
    final suspensionReasons = values[4] as Map<String, String>;
    final settings = values[5] as HalaqahSettings;
    final vacations = values[6] as List<Vacation>;
    final holds = values[7] as List<StudentHold>;

    final calendarDays = _calendarDays(
      plan: plan,
      settings: settings,
      suspendedDates: suspendedDates,
      suspensionReasons: suspensionReasons,
      vacations: vacations,
      holds: holds,
    );
    final revisionOnly = StudentLearningPolicy.hasCompletedQuran(student);
    final ascendingMemorization = student.memorizationDirection != 'desc';
    final planStudent = student.copyWith(
      planType: plan.unit,
      planAmount: plan.newAmount,
    );
    final memorizationStart = revisionOnly
        ? null
        : MemorizationProgressionService.nextStartingPoint(
            student: planStudent,
            progress: progress,
            getSurah: _quran.getSurah,
          );
    (int, int)? memorizationCursor = memorizationStart == null
        ? null
        : (
            memorizationStart['surahId']!,
            memorizationStart['fromAyah']!,
          );

    final ascendingReview = settings.revisionOrder != 'descending';
    final reviewStart = RevisionProgressionService.nextStartingPoint(
      memorizedSurahIds: memorizedRanges.keys.toList(),
      progress: progress,
      ascending: ascendingReview,
      getSurah: _quran.getSurah,
      memorizedRanges: memorizedRanges,
    );
    (int, int)? reviewCursor = reviewStart == null
        ? null
        : (reviewStart['surahId']!, reviewStart['fromAyah']!);
    final reviewAllowed = <int, QuranRangeSegment>{
      for (final entry in memorizedRanges.entries)
        entry.key: QuranRangeSegment(
          surahId: entry.key,
          fromAyah: entry.value.fromAyah,
          toAyah: entry.value.toAyah,
        ),
    };
    if (reviewCursor == null && student.totalMemorized > 0) {
      throw SmartPlanScheduleException(
        'محفوظ ${student.name} مسجل كإجمالي فقط بلا سورة وآية. '
        'حدّد نطاق المحفوظ في ملف الطالب أو خريطة المصحف ثم أعد إنشاء الخطة.',
      );
    }

    (int, int)? recitationCursor = _nextRecitationCursor(
      recitationRecords,
      ascending: ascendingMemorization,
    );
    recitationCursor ??= (ascendingMemorization ? 1 : 114, 1);

    final result = <SmartPlanDailyAssignment>[];
    for (final calendarDay in calendarDays) {
      final day = calendarDay.date;
      if (!calendarDay.isStudyDay) {
        final status = calendarDay.status!;
        result.add(
          SmartPlanDailyAssignment(
            date: day,
            memorizationRange: status,
            reviewRange: status,
            recitationRange: status,
            isStudyDay: false,
            dayStatus: status,
          ),
        );
        continue;
      }
      final memorization = revisionOnly
          ? null
          : _rangeFromCursor(
              cursor: memorizationCursor,
              unit: plan.unit,
              amount: plan.newAmount,
              ascending: ascendingMemorization,
            );
      final review = _rangeFromCursor(
        cursor: reviewCursor,
        unit: plan.reviewUnit,
        amount: plan.reviewAmount,
        ascending: ascendingReview,
        allowedRanges: reviewAllowed,
      );
      final recitation = _rangeFromCursor(
        cursor: recitationCursor,
        unit: plan.unit,
        amount: plan.recitationAmount,
        ascending: ascendingMemorization,
      );
      if (reviewCursor != null && review == null) {
        throw SmartPlanScheduleException(
          'تعذر إنشاء نطاق مراجعة دقيق للطالب ${student.name}. '
          'راجع نطاق المحفوظ ونوع المقرر اليومي.',
        );
      }
      if (recitation == null) {
        throw SmartPlanScheduleException(
          'تعذر إنشاء نطاق السرد الدقيق للطالب ${student.name}.',
        );
      }

      result.add(
        SmartPlanDailyAssignment(
          date: day,
          memorizationRange: revisionOnly
              ? 'غير مطلوب للخاتم'
              : memorization == null
                  ? 'أتم حفظ القرآن الكريم'
                  : _rangeLabel(memorization),
          reviewRange: review == null
              ? 'لا يوجد محفوظ مسجل للمراجعة'
              : _rangeLabel(review),
          recitationRange: _rangeLabel(recitation),
        ),
      );
      if (!revisionOnly) {
        memorizationCursor = _afterRange(
          memorization,
          ascending: ascendingMemorization,
        );
      }
      reviewCursor = reviewAllowed.isEmpty
          ? null
          : _afterRange(
              review,
              ascending: ascendingReview,
              allowedRanges: reviewAllowed,
              cycle: true,
            );
      recitationCursor = _afterRange(
        recitation,
        ascending: ascendingMemorization,
        cycle: true,
      );
    }
    return result;
  }

  List<_PlanCalendarDay> _calendarDays({
    required SmartPlan plan,
    required HalaqahSettings settings,
    required Set<String> suspendedDates,
    required Map<String, String> suspensionReasons,
    required List<Vacation> vacations,
    required List<StudentHold> holds,
  }) {
    final result = <_PlanCalendarDay>[];
    for (var day = _date(plan.startDate);
        !day.isAfter(_date(plan.endDate));
        day = day.add(const Duration(days: 1))) {
      final key = _key(day);
      Vacation? activeVacation;
      for (final item in vacations) {
        if (item.approved && item.isDateInVacation(day)) {
          activeVacation = item;
          break;
        }
      }
      StudentHold? activeHold;
      for (final item in holds) {
        if (item.isActiveAt(day)) {
          activeHold = item;
          break;
        }
      }
      String? status;
      if (suspendedDates.contains(key)) {
        final reason = suspensionReasons[key]?.trim();
        status = reason == null || reason.isEmpty
            ? 'تعليق الدراسة'
            : 'تعليق الدراسة: $reason';
      } else if (settings.holidayWeekdays.contains(day.weekday)) {
        status = 'إجازة أسبوعية';
      } else if (activeVacation != null) {
        status = 'إجازة الطالب: ${VacationReason.getLabel(activeVacation.reason)}';
      } else if (activeHold != null) {
        status = 'الطالب موقوف: ${activeHold.reason}';
      }
      result.add(_PlanCalendarDay(day, status: status));
    }
    return result;
  }

  QuranCrossSurahRange? _rangeFromCursor({
    required (int, int)? cursor,
    required String unit,
    required int amount,
    required bool ascending,
    Map<int, QuranRangeSegment> allowedRanges = const {},
  }) {
    if (cursor == null) return null;
    return QuranCrossSurahRangeService.toAmount(
      surahs: _quran.surahs,
      startSurahId: cursor.$1,
      startAyah: cursor.$2,
      unit: QuranCrossSurahRangeService.unitFromPlanType(unit),
      amount: amount,
      ascendingSurahs: ascending,
      allowedRanges: allowedRanges,
    );
  }

  (int, int)? _afterRange(
    QuranCrossSurahRange? range, {
    required bool ascending,
    Map<int, QuranRangeSegment> allowedRanges = const {},
    bool cycle = false,
  }) {
    if (range == null || range.segments.isEmpty) {
      return cycle ? _firstCursor(ascending, allowedRanges) : null;
    }
    final last = range.segments.last;
    final allowed = allowedRanges[last.surahId];
    final surah = _quran.getSurah(last.surahId);
    final endAyah = allowed?.toAyah ?? surah?.totalAyahs;
    if (endAyah != null && last.toAyah < endAyah) {
      return (last.surahId, last.toAyah + 1);
    }

    final orderedSurahs = allowedRanges.isEmpty
        ? [for (var id = 1; id <= 114; id++) id]
        : allowedRanges.keys.toList()..sort();
    if (!ascending) {
      final reversed = orderedSurahs.reversed.toList();
      orderedSurahs
        ..clear()
        ..addAll(reversed);
    }
    final index = orderedSurahs.indexOf(last.surahId);
    if (index >= 0 && index < orderedSurahs.length - 1) {
      final nextSurah = orderedSurahs[index + 1];
      return (nextSurah, allowedRanges[nextSurah]?.fromAyah ?? 1);
    }
    return cycle ? _firstCursor(ascending, allowedRanges) : null;
  }

  (int, int) _firstCursor(
    bool ascending,
    Map<int, QuranRangeSegment> allowedRanges,
  ) {
    if (allowedRanges.isEmpty) return (ascending ? 1 : 114, 1);
    final ids = allowedRanges.keys.toList()..sort();
    final surahId = ascending ? ids.first : ids.last;
    return (surahId, allowedRanges[surahId]!.fromAyah);
  }

  (int, int)? _nextRecitationCursor(
    List<PlanRecitationRecord> records, {
    required bool ascending,
  }) {
    if (records.isEmpty) return null;
    final latestRecord = records.reduce(
      (left, right) => left.createdAt.isAfter(right.createdAt) ? left : right,
    );
    final sessionRows = records
        .where((row) => row.sessionId == latestRecord.sessionId)
        .toList()
      ..sort((left, right) => left.segmentOrder.compareTo(right.segmentOrder));
    final last = sessionRows.last;
    final surah = _quran.getSurah(last.surahId);
    if (surah != null && last.toAyah < surah.totalAyahs) {
      return (last.surahId, last.toAyah + 1);
    }
    final nextSurah = ascending ? last.surahId + 1 : last.surahId - 1;
    return nextSurah >= 1 && nextSurah <= 114 ? (nextSurah, 1) : null;
  }

  String _rangeLabel(QuranCrossSurahRange? range) {
    if (range == null || range.segments.isEmpty) return 'أتم النطاق المتاح';
    final first = range.segments.first;
    final last = range.segments.last;
    if (first.surahId == last.surahId) {
      return 'سورة ${_quran.getSurahName(first.surahId)}: '
          'من الآية ${first.fromAyah} إلى الآية ${last.toAyah}';
    }
    return 'من سورة ${_quran.getSurahName(first.surahId)} '
        'الآية ${first.fromAyah} إلى سورة '
        '${_quran.getSurahName(last.surahId)} الآية ${last.toAyah}';
  }

  DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String _key(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
