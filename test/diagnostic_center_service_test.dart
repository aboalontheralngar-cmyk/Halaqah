import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/cloud_connection_diagnostics.dart';
import 'package:halaqah_teacher/services/diagnostic_center_service.dart';

void main() {
  test('support report contains health metrics but excludes raw details', () {
    final snapshot = DiagnosticSnapshot(
      generatedAt: DateTime.utc(2026, 7, 18, 12),
      operatingSystem: 'android',
      operatingSystemVersion: 'Android test',
      databaseVersion: 18,
      recordCounts: const <String, int>{'الطلاب': 25, 'الحضور': 120},
      localBackupCount: 3,
      lastBackupAt: DateTime.utc(2026, 7, 18, 2),
      lastCloudUploadAt: null,
      lastCloudDownloadAt: null,
      lastSyncDirection: 'upload',
      hasAutomaticBackupError: false,
      cloudAuthenticated: true,
      cloudConnection: const CloudConnectionDiagnostic(
        status: CloudConnectionStatus.healthy,
        host: 'project.supabase.co',
        elapsed: Duration(milliseconds: 90),
        httpStatus: 200,
        technicalDetails: '/Users/private/device/path',
      ),
      incidents: <OperationalIncidentSummary>[
        OperationalIncidentSummary(
          eventType: 'runtime.error',
          fingerprint: '0123456789abcdef',
          source: 'flutter_framework',
          createdAt: DateTime.utc(2026, 7, 18, 11),
        ),
      ],
    );

    final report = snapshot.toSupportReport();
    expect(report, contains('إصدار SQLite: 18'));
    expect(report, contains('الطلاب: 25'));
    expect(report, contains('0123456789abcdef'));
    expect(report, isNot(contains('/Users/private')));
    expect(report, isNot(contains('technicalDetails')));
  });
}
