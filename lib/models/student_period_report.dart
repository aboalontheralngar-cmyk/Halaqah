import 'behavior_point.dart';
import 'daily_record.dart';
import 'exam.dart';
import 'fund_transaction.dart';
import 'memorization.dart';
import 'plan_recitation_record.dart';
import 'student.dart';
import 'student_hold.dart';
import 'vacation.dart';

class StudentPeriodDay {
  final DateTime date;
  final DailyRecord? record;
  final List<MemorizationProgress> memorization;
  final List<MemorizationProgress> revision;
  final List<BehaviorPoint> points;
  final Vacation? vacation;
  final StudentHold? hold;
  final bool isSuspended;
  final bool isWeeklyHoliday;
  final String? suspensionReason;
  final int performanceScore;
  final int lateMinutes;
  final double memorizationActualAmount;
  final double memorizationPlanAmount;
  final String memorizationUnit;

  const StudentPeriodDay({
    required this.date,
    required this.record,
    required this.memorization,
    required this.revision,
    required this.points,
    required this.vacation,
    required this.hold,
    required this.isSuspended,
    required this.isWeeklyHoliday,
    required this.suspensionReason,
    required this.performanceScore,
    this.lateMinutes = 0,
    this.memorizationActualAmount = 0,
    this.memorizationPlanAmount = 0,
    this.memorizationUnit = 'ayahs',
  });

  bool get isStudyDay => !isSuspended && !isWeeklyHoliday;
  bool get isAttendanceRequiredDay =>
      isStudyDay && !(hold?.exemptsAttendance ?? false);
  bool get isRecitationRequiredDay => isAttendanceRequiredDay &&
      hold == null &&
      !(record?.recitationExempt ?? false) &&
      !(record?.talaqqinDone ?? false);
  bool get attended =>
      record?.attendance == 'present' || record?.attendance == 'late';
  bool get memorizationDone =>
      memorization.isNotEmpty || (record?.memorizationDone ?? false);
  bool get revisionDone => revision.isNotEmpty || (record?.revisionDone ?? false);
  int get memorizedAyahs =>
      memorization.fold(0, (sum, item) => sum + item.ayahCount);
  int get revisedAyahs => revision.fold(0, (sum, item) => sum + item.ayahCount);
  double get positivePoints => points
      .where((item) => item.points > 0)
      .fold<double>(0, (sum, item) => sum + item.points);
  double get negativePoints => points
      .where((item) => item.points < 0)
      .fold<double>(0, (sum, item) => sum + item.points.abs());
  List<BehaviorPoint> get violations => points
      .where((item) =>
          item.points < 0 &&
          !BehaviorReason.isAttendancePenalty(item.reason))
      .toList();
  double get memorizationQuality => _quality(memorization);
  double get revisionQuality => _quality(revision);
  String get memorizationRating => _rating(memorizationQuality);
  String get revisionRating => _rating(revisionQuality);
  bool get exceededMemorizationPlan => memorizationPlanAmount > 0 &&
      memorizationActualAmount > memorizationPlanAmount + 0.000001;
  double get memorizationExcessPercent => !exceededMemorizationPlan
      ? 0
      : ((memorizationActualAmount - memorizationPlanAmount) /
              memorizationPlanAmount) *
          100;

  static double _quality(List<MemorizationProgress> items) => items.isEmpty
      ? 0
      : items.fold<int>(0, (sum, item) => sum + item.qualityRating) /
          items.length;

  static String _rating(double value) {
    if (value >= 4.5) return 'ممتاز';
    if (value >= 3.5) return 'جيد جدًا';
    if (value >= 2.5) return 'جيد';
    if (value > 0) return 'يحتاج متابعة';
    return '—';
  }
}

class StudentPeriodReport {
  final Student student;
  final DateTime startDate;
  final DateTime endDate;
  final List<StudentPeriodDay> days;
  final int memorizedAyahs;
  final int revisedAyahs;
  final double memorizedLines;
  final double revisedLines;
  final int recitedAyahs;
  final double recitedLines;
  final int presentDays;
  final int lateDays;
  final int absentDays;
  final int excusedDays;
  final int noRecitationDays;
  final double positivePoints;
  final double negativePoints;
  final int positiveEvents;
  final int negativeEvents;
  final double averageQuality;
  final int performanceScore;
  final int totalLateMinutes;
  final int violationEvents;
  final double violationPoints;
  final int settledNegativePoints;
  final List<Exam> exams;
  final List<FundTransaction> fundTransactions;
  final List<PlanRecitationRecord> recitationRecords;
  final int? periodRank;
  final int quranTotalAyahs;
  final int studentMemorizedAyahs;

  const StudentPeriodReport({
    required this.student,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.memorizedAyahs,
    required this.revisedAyahs,
    required this.memorizedLines,
    required this.revisedLines,
    this.recitedAyahs = 0,
    this.recitedLines = 0,
    required this.presentDays,
    required this.lateDays,
    required this.absentDays,
    required this.excusedDays,
    required this.noRecitationDays,
    required this.positivePoints,
    required this.negativePoints,
    required this.positiveEvents,
    required this.negativeEvents,
    required this.averageQuality,
    required this.performanceScore,
    this.totalLateMinutes = 0,
    this.violationEvents = 0,
    this.violationPoints = 0,
    this.settledNegativePoints = 0,
    this.exams = const [],
    this.fundTransactions = const [],
    this.recitationRecords = const [],
    this.periodRank,
    this.quranTotalAyahs = 0,
    this.studentMemorizedAyahs = 0,
  });

  double get memorizedPages => memorizedLines / 15;
  double get revisedPages => revisedLines / 15;
  double get recitedPages => recitedLines / 15;
  double get totalCompletedPages => memorizedPages + revisedPages + recitedPages;
  List<FundTransaction> get payments => fundTransactions
      .where((item) => item.type != 'expense' && item.amount > 0)
      .toList();
  double get paidAmount => payments.fold<double>(0, (sum, item) => sum + item.amount);
  double get memorizedJuz => memorizedPages / 20;
  double get khatmProgressPercent => quranTotalAyahs <= 0
      ? 0
      : (studentMemorizedAyahs.clamp(0, quranTotalAyahs) /
              quranTotalAyahs *
              100)
          .clamp(0, 100)
          .toDouble();
  double get khatmRemainingPercent => (100 - khatmProgressPercent).clamp(0, 100).toDouble();
  int get khatmRemainingAyahs =>
      (quranTotalAyahs - studentMemorizedAyahs.clamp(0, quranTotalAyahs))
          .clamp(0, quranTotalAyahs)
          .toInt();
  int get attendanceTotal => presentDays + lateDays + absentDays + excusedDays;
  int get attendanceRate => attendanceTotal == 0
      ? 0
      : (((presentDays + lateDays) / attendanceTotal) * 100).round();
  double get outstandingNegativePoints =>
      (negativePoints - settledNegativePoints).clamp(0, negativePoints).toDouble();
  String? get rankLabel {
    switch (periodRank) {
      case 1:
        return 'المركز الأول';
      case 2:
        return 'المركز الثاني';
      case 3:
        return 'المركز الثالث';
      default:
        return null;
    }
  }

  StudentPeriodReport copyWithRank(int? rank) => StudentPeriodReport(
        student: student,
        startDate: startDate,
        endDate: endDate,
        days: days,
        memorizedAyahs: memorizedAyahs,
        revisedAyahs: revisedAyahs,
        memorizedLines: memorizedLines,
        revisedLines: revisedLines,
        recitedAyahs: recitedAyahs,
        recitedLines: recitedLines,
        presentDays: presentDays,
        lateDays: lateDays,
        absentDays: absentDays,
        excusedDays: excusedDays,
        noRecitationDays: noRecitationDays,
        positivePoints: positivePoints,
        negativePoints: negativePoints,
        positiveEvents: positiveEvents,
        negativeEvents: negativeEvents,
        averageQuality: averageQuality,
        performanceScore: performanceScore,
        totalLateMinutes: totalLateMinutes,
        violationEvents: violationEvents,
        violationPoints: violationPoints,
        settledNegativePoints: settledNegativePoints,
        exams: exams,
        fundTransactions: fundTransactions,
        recitationRecords: recitationRecords,
        periodRank: rank,
        quranTotalAyahs: quranTotalAyahs,
        studentMemorizedAyahs: studentMemorizedAyahs,
      );
}
