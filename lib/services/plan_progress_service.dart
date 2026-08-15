import '../models/ayah.dart';
import '../models/plan.dart';
import '../models/memorization.dart';
import '../models/settings.dart';
import '../models/student_hold.dart';
import '../models/vacation.dart';
import '../models/student.dart';
import '../models/plan_recitation_record.dart';
import 'daily_excellence_service.dart';
import 'database_service.dart';
import 'quran_service.dart';
import 'student_learning_policy.dart';

class SmartPlanProgress {
  final int requiredStudyDays;
  final double requiredMemorization;
  final double actualMemorization;
  final double requiredReview;
  final double actualReview;
  final double requiredRecitation;
  final double actualRecitation;

  const SmartPlanProgress({
    required this.requiredStudyDays,
    required this.requiredMemorization,
    required this.actualMemorization,
    required this.requiredReview,
    required this.actualReview,
    required this.requiredRecitation,
    required this.actualRecitation,
  });

  double get memorizationRatio => requiredMemorization <= 0
      ? 1
      : actualMemorization / requiredMemorization;
  double get reviewRatio =>
      requiredReview <= 0 ? 0 : actualReview / requiredReview;
  double get recitationRatio => requiredRecitation <= 0
      ? 0
      : actualRecitation / requiredRecitation;

  List<double> get _requiredRatios => [
        if (requiredMemorization > 0) memorizationRatio,
        if (requiredReview > 0) reviewRatio,
        if (requiredRecitation > 0) recitationRatio,
      ];

  int get completionPercent {
    final ratios = _requiredRatios;
    if (ratios.isEmpty) return 0;
    final total = ratios.fold<double>(
      0,
      (sum, ratio) => sum + ratio.clamp(0, 1).toDouble(),
    );
    return ((total / ratios.length) * 100).round();
  }

  bool get isAccomplished {
    final ratios = _requiredRatios;
    final memorizationDone =
        requiredMemorization <= 0 || memorizationRatio >= 1;
    final reviewDone = requiredReview <= 0 || reviewRatio >= 1;
    final recitationDone = requiredRecitation <= 0 || recitationRatio >= 1;
    return requiredStudyDays > 0 &&
        ratios.isNotEmpty &&
        memorizationDone &&
        reviewDone &&
        recitationDone;
  }
}

class PlanProgressService {
  final DatabaseService _db;
  final QuranService _quran;

  PlanProgressService({DatabaseService? database, QuranService? quran})
      : _db = database ?? DatabaseService(),
        _quran = quran ?? QuranService.instance;

  Future<SmartPlanProgress> calculate({
    required SmartPlan plan,
    required Student student,
  }) async {
    await _quran.initialize();
    final values = await Future.wait<dynamic>([
      _db.getStudentMemorizationInRange(
        student.id,
        plan.startDate,
        plan.endDate,
      ),
      _db.getSuspendedDates(),
      _db.getSettings(),
      _db.getStudentVacationsInRange(student.id, plan.startDate, plan.endDate),
      _db.getStudentHoldsInRange(student.id, plan.startDate, plan.endDate),
      _db.getPlanRecitationRecordsInRange(
        studentId: student.id,
        planId: plan.id,
        startDate: plan.startDate,
        endDate: plan.endDate,
      ),
    ]);
    final progress = values[0] as List<MemorizationProgress>;
    final suspended = (values[1] as List<String>).toSet();
    final settings = values[2] as HalaqahSettings;
    final vacations = values[3] as List<Vacation>;
    final holds = values[4] as List<StudentHold>;
    final recitationRecords = values[5] as List<PlanRecitationRecord>;
    var studyDays = 0;
    for (var day = _date(plan.startDate);
        !day.isAfter(_date(plan.endDate));
        day = day.add(const Duration(days: 1))) {
      final key = _key(day);
      final onVacation = vacations.any(
        (vacation) => vacation.approved && vacation.isDateInVacation(day),
      );
      final held = holds.any((hold) => hold.isActiveAt(day));
      if (!suspended.contains(key) &&
          !settings.holidayWeekdays.contains(day.weekday) &&
          !onVacation &&
          !held) {
        studyDays++;
      }
    }

    final surahs = <int, Surah>{
      for (final surah in _quran.surahs) surah.number: surah,
    };
    final actualMemorization = DailyExcellenceService.calculateActualAmount(
      progress: progress,
      surahs: surahs,
      unit: plan.unit,
    );
    // المراجعة الدورية قد تعيد المقطع نفسه في أيام مختلفة؛ لذلك نجمع كل
    // يوم مستقلًا، مع إبقاء إزالة التكرار داخل اليوم نفسه.
    final reviewByDay = <String, List<MemorizationProgress>>{};
    for (final item in progress.where((item) => item.isRevision)) {
      reviewByDay.putIfAbsent(_key(item.date), () => []).add(item);
    }
    final actualReview = reviewByDay.values.fold<double>(
      0,
      (sum, dailyProgress) =>
          sum +
          DailyExcellenceService.calculateActualAmount(
            progress: dailyProgress,
            surahs: surahs,
            unit: plan.reviewUnit,
            isRevision: true,
          ),
    );
    // السرد لا يزيد محفوظ الطالب. نحوله إلى صفوف قياس مؤقتة فقط لإعادة
    // استخدام حساب الآيات/الأسطر/الصفحات/الأحزاب مع إزالة تداخل اليوم نفسه.
    final recitationByDay = <String, List<MemorizationProgress>>{};
    for (final item in recitationRecords) {
      final measured = MemorizationProgress(
        id: item.id,
        studentId: item.studentId,
        surahId: item.surahId,
        fromAyah: item.fromAyah,
        toAyah: item.toAyah,
        date: item.date,
        qualityRating: item.qualityRating,
        isRevision: true,
        notes: item.notes,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
      recitationByDay.putIfAbsent(_key(item.date), () => []).add(measured);
    }
    final actualRecitation = recitationByDay.values.fold<double>(
      0,
      (sum, dailyProgress) =>
          sum +
          DailyExcellenceService.calculateActualAmount(
            progress: dailyProgress,
            surahs: surahs,
            unit: plan.unit,
            isRevision: true,
          ),
    );
    return SmartPlanProgress(
      requiredStudyDays: studyDays,
      requiredMemorization: StudentLearningPolicy.hasCompletedQuran(student)
          ? 0
          : studyDays * plan.newAmount.toDouble(),
      actualMemorization: actualMemorization,
      requiredReview: studyDays * plan.reviewAmount.toDouble(),
      actualReview: actualReview,
      requiredRecitation: studyDays * plan.recitationAmount.toDouble(),
      actualRecitation: actualRecitation,
    );
  }

  static DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static String _key(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
