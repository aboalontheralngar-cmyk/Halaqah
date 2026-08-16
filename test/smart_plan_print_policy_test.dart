import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/models/plan.dart';
import 'package:halaqah_teacher/models/student.dart';
import 'package:halaqah_teacher/services/smart_plan_print_policy.dart';
import 'package:halaqah_teacher/services/smart_plan_schedule_service.dart';

void main() {
  final student = Student(id: 'student-1', name: 'طالب');

  SmartPlan plan() => SmartPlan(
        id: 'plan-1',
        studentId: student.id,
        period: 'weekly',
        startDate: DateTime(2026, 8, 16),
        endDate: DateTime(2026, 8, 22),
        unit: 'pages',
        reviewUnit: 'pages',
        newAmount: 1,
        reviewAmount: 8,
        recitationAmount: 1,
        fridayMode: 'catchup_recitation',
        createdAt: DateTime(2026, 8, 16),
        updatedAt: DateTime(2026, 8, 16),
      );

  SmartPlanDailyAssignment exact(DateTime date) => SmartPlanDailyAssignment(
        date: date,
        memorizationRange: 'سورة البقرة: من الآية 1 إلى الآية 5',
        reviewRange: 'سورة الفاتحة: من الآية 1 إلى الآية 7',
        recitationRange: 'سورة آل عمران: من الآية 1 إلى الآية 4',
      );

  test('Friday catch-up row prints when recitation is an exact Quran range', () {
    final assignments = <SmartPlanDailyAssignment>[];
    for (var day = DateTime(2026, 8, 16);
        !day.isAfter(DateTime(2026, 8, 22));
        day = day.add(const Duration(days: 1))) {
      if (day.weekday == DateTime.friday) {
        assignments.add(
          SmartPlanDailyAssignment(
            date: day,
            memorizationRange: 'تدارك الفائت — لا مقرر حفظ جديد',
            reviewRange: 'تدارك الفائت — راجع ما لم يكتمل فقط',
            recitationRange: 'سورة آل عمران: من الآية 5 إلى الآية 9',
            dayStatus: 'الجمعة: تدارك الفائت + سرد تلاوة',
            isCatchupDay: true,
          ),
        );
      } else {
        assignments.add(exact(day));
      }
    }

    expect(
      () => SmartPlanPrintPolicy.validateExactAssignments(
        student: student,
        plan: plan(),
        assignments: assignments,
      ),
      returnsNormally,
    );
  });

  test('ordinary study day still rejects generic amounts', () {
    final assignments = <SmartPlanDailyAssignment>[];
    for (var day = DateTime(2026, 8, 16);
        !day.isAfter(DateTime(2026, 8, 22));
        day = day.add(const Duration(days: 1))) {
      assignments.add(exact(day));
    }
    assignments[0] = SmartPlanDailyAssignment(
      date: assignments[0].date,
      memorizationRange: '1 صفحة',
      reviewRange: assignments[0].reviewRange,
      recitationRange: assignments[0].recitationRange,
    );

    expect(
      () => SmartPlanPrintPolicy.validateExactAssignments(
        student: student,
        plan: plan(),
        assignments: assignments,
      ),
      throwsStateError,
    );
  });
}
