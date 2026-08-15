import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/operational_readiness_service.dart';

void main() {
  final allManual = OperationalReadinessEvaluator.manualRequirements.keys.toSet();

  OperationalReadinessInput healthyInput({
    Set<String>? manual,
    bool dataWarnings = false,
    int incidents = 0,
  }) {
    return OperationalReadinessInput(
      databaseVersion: OperationalReadinessEvaluator.expectedDatabaseVersion,
      hasCriticalDataIssue: false,
      hasDataWarnings: dataWarnings,
      localBackupCount: 2,
      lastBackupAt: DateTime.utc(2026, 7, 21),
      hasAutomaticBackupError: false,
      hasBackgroundBackupSchedulerError: false,
      cloudConnectionHealthy: true,
      cloudAuthenticated: true,
      recentIncidentCount: incidents,
      completedManualChecks: manual ?? allManual,
    );
  }

  test('healthy automatic and completed manual checks are ready', () {
    final report = OperationalReadinessEvaluator.evaluate(
      healthyInput(),
      now: DateTime.utc(2026, 7, 22),
    );

    expect(report.isReady, isTrue);
    expect(report.blockedCount, 0);
    expect(report.pendingCount, 0);
    expect(report.passedCount, report.checks.length);
  });

  test('critical data, stale backup, and cloud failure block readiness', () {
    final report = OperationalReadinessEvaluator.evaluate(
      OperationalReadinessInput(
        databaseVersion: 17,
        hasCriticalDataIssue: true,
        hasDataWarnings: false,
        localBackupCount: 1,
        lastBackupAt: DateTime.utc(2026, 6, 1),
        hasAutomaticBackupError: true,
        hasBackgroundBackupSchedulerError: false,
        cloudConnectionHealthy: false,
        cloudAuthenticated: false,
        recentIncidentCount: 2,
        completedManualChecks: allManual,
      ),
      now: DateTime.utc(2026, 7, 22),
    );

    expect(report.isReady, isFalse);
    expect(report.blockedCount, 5);
    expect(report.warningCount, 2);
    expect(report.statusLabel, contains('عوائق'));
  });

  test('manual checks remain pending for every new release', () {
    final report = OperationalReadinessEvaluator.evaluate(
      healthyInput(manual: const <String>{}),
      now: DateTime.utc(2026, 7, 22),
    );

    expect(report.blockedCount, 0);
    expect(
      report.pendingCount,
      OperationalReadinessEvaluator.manualRequirements.length,
    );
    expect(report.isReady, isFalse);
    expect(report.statusLabel, contains('اختبارات القبول'));
  });

  test('warnings are visible but do not invalidate completed acceptance', () {
    final report = OperationalReadinessEvaluator.evaluate(
      healthyInput(dataWarnings: true, incidents: 1),
      now: DateTime.utc(2026, 7, 22),
    );

    expect(report.warningCount, 2);
    expect(report.isReady, isTrue);
    expect(report.statusLabel, contains('ملاحظات'));
    expect(report.toSafeReport(), isNot(contains('student-id')));
  });
}
