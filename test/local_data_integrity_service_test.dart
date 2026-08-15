import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/local_data_integrity_service.dart';

void main() {
  test('healthy metrics produce a clean read-only report', () {
    final report = LocalDataIntegrityEvaluator.evaluate(
      const LocalDataIntegrityMetrics(),
      checkedAt: DateTime.utc(2026, 7, 21),
    );

    expect(report.isHealthy, isTrue);
    expect(report.hasCritical, isFalse);
    expect(report.checkedRules, LocalDataIntegrityEvaluator.totalRules);
    expect(report.toSafeSummary(), contains('الحالة: سليمة'));
  });

  test('critical data defects are counted without exposing record values', () {
    final report = LocalDataIntegrityEvaluator.evaluate(
      const LocalDataIntegrityMetrics(
        foreignKeyViolations: 2,
        duplicateAttendanceGroups: 1,
        invalidStudentCodes: 3,
        invalidQuranRanges: 4,
      ),
      checkedAt: DateTime.utc(2026, 7, 21),
    );

    expect(report.hasCritical, isTrue);
    expect(report.criticalCount, 3);
    expect(report.warningCount, 1);
    expect(
      report.issues.map((issue) => issue.code),
      containsAll(<String>[
        'foreign_key_violation',
        'duplicate_attendance',
        'invalid_student_code',
        'invalid_quran_range',
      ]),
    );
    expect(report.toSafeSummary(), isNot(contains('student-id-example')));
  });

  test('failed rules reduce completed count and remain a warning', () {
    final report = LocalDataIntegrityEvaluator.evaluate(
      const LocalDataIntegrityMetrics(failedChecks: 2),
    );

    expect(report.checkedRules, 5);
    expect(report.hasCritical, isFalse);
    expect(report.warningCount, 1);
    expect(report.issues.single.code, 'audit_incomplete');
  });
}
