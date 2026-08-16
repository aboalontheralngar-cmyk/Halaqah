import '../models/plan.dart';
import '../models/student.dart';
import 'smart_plan_schedule_service.dart';
import 'student_learning_policy.dart';

/// Validates that a smart-plan PDF contains concrete Quran ranges wherever a
/// concrete assignment is required.
///
/// Friday catch-up rows are intentionally different: memorization/review are
/// descriptive catch-up instructions, while recitation still has to be an
/// exact Quran range. Treating those rows like full-plan study days prevented
/// otherwise valid weekly/monthly plans from printing.
class SmartPlanPrintPolicy {
  const SmartPlanPrintPolicy._();

  static void validateExactAssignments({
    required Student student,
    required SmartPlan plan,
    required List<SmartPlanDailyAssignment> assignments,
  }) {
    final start = _day(plan.startDate);
    final end = _day(plan.endDate);
    final expectedDays = end.difference(start).inDays + 1;
    final assignmentByDate = <String, SmartPlanDailyAssignment>{
      for (final assignment in assignments)
        _dateKey(assignment.date): assignment,
    };

    if (assignments.length != expectedDays ||
        assignmentByDate.length != expectedDays) {
      throw StateError(
        'الخطة غير مكتملة: يجب إنشاء الحفظ والمراجعة والتلاوة لكل يوم قبل الطباعة.',
      );
    }

    for (var day = start;
        !day.isAfter(end);
        day = day.add(const Duration(days: 1))) {
      final assignment = assignmentByDate[_dateKey(day)];
      if (assignment == null) {
        throw StateError('لا يوجد مقرر قرآني ليوم ${_reportDate(day)}.');
      }
      if (!assignment.isStudyDay) continue;

      final recitationIsExact = _hasExactQuranRange(assignment.recitationRange);
      if (assignment.isCatchupDay) {
        if (!recitationIsExact) {
          throw StateError(
            'تعذر طباعة يوم التدارك؛ يجب تحديد السورة والآية للسرد/التلاوة.',
          );
        }
        continue;
      }

      final memorizationIsExact =
          StudentLearningPolicy.hasCompletedQuran(student) ||
              _hasExactQuranRange(assignment.memorizationRange) ||
              assignment.memorizationRange == 'أتم حفظ القرآن الكريم';
      final reviewIsExact = _hasExactQuranRange(assignment.reviewRange) ||
          assignment.reviewRange == 'لا يوجد محفوظ مسجل للمراجعة';

      if (!memorizationIsExact || !reviewIsExact || !recitationIsExact) {
        throw StateError(
          'تعذر طباعة خطة بمقادير عامة؛ يجب تحديد السورة والآية للحفظ والمراجعة والتلاوة.',
        );
      }
    }
  }

  static bool _hasExactQuranRange(String value) => value.contains('سورة ');

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _reportDate(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';
}
