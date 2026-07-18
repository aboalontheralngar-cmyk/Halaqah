import 'dart:io';

import '../app/build_info.dart';
import '../models/audit_event.dart';
import 'audit_log_service.dart';
import 'backup_service.dart';
import 'cloud_connection_diagnostics.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class OperationalIncidentSummary {
  final String eventType;
  final String fingerprint;
  final String source;
  final DateTime createdAt;

  const OperationalIncidentSummary({
    required this.eventType,
    required this.fingerprint,
    required this.source,
    required this.createdAt,
  });
}

class DiagnosticSnapshot {
  final DateTime generatedAt;
  final String operatingSystem;
  final String operatingSystemVersion;
  final int databaseVersion;
  final Map<String, int> recordCounts;
  final int localBackupCount;
  final DateTime? lastBackupAt;
  final DateTime? lastCloudUploadAt;
  final DateTime? lastCloudDownloadAt;
  final String lastSyncDirection;
  final bool hasAutomaticBackupError;
  final bool cloudAuthenticated;
  final CloudConnectionDiagnostic cloudConnection;
  final List<OperationalIncidentSummary> incidents;

  const DiagnosticSnapshot({
    required this.generatedAt,
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.databaseVersion,
    required this.recordCounts,
    required this.localBackupCount,
    required this.lastBackupAt,
    required this.lastCloudUploadAt,
    required this.lastCloudDownloadAt,
    required this.lastSyncDirection,
    required this.hasAutomaticBackupError,
    required this.cloudAuthenticated,
    required this.cloudConnection,
    required this.incidents,
  });

  String toSupportReport() {
    String date(DateTime? value) =>
        value?.toLocal().toIso8601String() ?? 'غير متوفر';
    final buffer = StringBuffer()
      ..writeln('تقرير تشخيص حلقتي')
      ..writeln('الإصدار: ${AppBuildInfo.displayVersion}')
      ..writeln('وقت التقرير: ${date(generatedAt)}')
      ..writeln('النظام: $operatingSystem')
      ..writeln('إصدار النظام: $operatingSystemVersion')
      ..writeln('إصدار SQLite: $databaseVersion')
      ..writeln('النسخ المحلية: $localBackupCount')
      ..writeln('آخر نسخة: ${date(lastBackupAt)}')
      ..writeln('آخر رفع: ${date(lastCloudUploadAt)}')
      ..writeln('آخر تنزيل: ${date(lastCloudDownloadAt)}')
      ..writeln('آخر اتجاه مزامنة: $lastSyncDirection')
      ..writeln('خطأ نسخ تلقائي معلق: $hasAutomaticBackupError')
      ..writeln('جلسة سحابية: $cloudAuthenticated')
      ..writeln('اتصال Supabase: ${cloudConnection.status.name}')
      ..writeln('نطاق Supabase: ${cloudConnection.host}')
      ..writeln('HTTP: ${cloudConnection.httpStatus ?? 'غير متوفر'}')
      ..writeln('زمن الاتصال: ${cloudConnection.elapsed.inMilliseconds} ms')
      ..writeln('--- أعداد السجلات ---');
    for (final entry in recordCounts.entries) {
      buffer.writeln('${entry.key}: ${entry.value}');
    }
    buffer
      ..writeln('--- الحوادث المنقحة (${incidents.length}) ---');
    for (final incident in incidents.take(20)) {
      buffer.writeln(
        '${date(incident.createdAt)} | ${incident.eventType} | '
        '${incident.source} | ${incident.fingerprint}',
      );
    }
    buffer.writeln(
      'لا يحتوي هذا التقرير أسماء الطلاب أو الهواتف أو الملاحظات أو كلمات المرور أو رموز الجلسات.',
    );
    return buffer.toString();
  }
}

class DiagnosticCenterService {
  DiagnosticCenterService({
    DatabaseService? database,
    AuditLogService? audit,
    BackupService? backup,
    Future<CloudConnectionDiagnostic> Function()? cloudCheck,
  })  : _database = database ?? DatabaseService(),
        _audit = audit ?? AuditLogService(),
        _backup = backup ?? BackupService(),
        _cloudCheck = cloudCheck ?? SupabaseService.instance.diagnoseConnection;

  final DatabaseService _database;
  final AuditLogService _audit;
  final BackupService _backup;
  final Future<CloudConnectionDiagnostic> Function() _cloudCheck;

  static const _countedTables = <String, String>{
    'الطلاب': 'students',
    'الحضور': 'daily_records',
    'الحفظ والمراجعة': 'memorization_progress',
    'النقاط': 'behavior_points',
    'الخطط': 'plans',
    'الاختبارات': 'exams',
    'العائلات': 'families',
  };

  Future<DiagnosticSnapshot> collect() async {
    final database = await _database.database;
    final counts = <String, int>{};
    for (final entry in _countedTables.entries) {
      try {
        final result = await database.rawQuery(
          'SELECT COUNT(*) AS count FROM ${entry.value}',
        );
        counts[entry.key] = (result.first['count'] as num?)?.toInt() ?? 0;
      } catch (_) {
        counts[entry.key] = -1;
      }
    }

    final recentAudit = await _audit.recent(limit: 100);
    final incidents = recentAudit
        .where((event) => event.eventType.startsWith('runtime.'))
        .map(_incidentFromEvent)
        .toList();
    final backups = await _backup.getBackupFiles();
    final lastBackupAt = DateTime.tryParse(
      await _database.getSetting('last_backup_at') ?? '',
    );
    final lastUploadAt = DateTime.tryParse(
      await _database.getSetting('last_cloud_upload_at') ?? '',
    );
    final lastDownloadAt = DateTime.tryParse(
      await _database.getSetting('last_cloud_download_at') ?? '',
    );
    final lastDirection =
        await _database.getSetting('last_cloud_sync_direction') ?? 'لم تنفذ';
    final automaticBackupError =
        (await _database.getSetting('last_automatic_backup_error'))?.trim();

    return DiagnosticSnapshot(
      generatedAt: DateTime.now(),
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      databaseVersion: await database.getVersion(),
      recordCounts: counts,
      localBackupCount: backups.length,
      lastBackupAt: lastBackupAt,
      lastCloudUploadAt: lastUploadAt,
      lastCloudDownloadAt: lastDownloadAt,
      lastSyncDirection: lastDirection,
      hasAutomaticBackupError: automaticBackupError?.isNotEmpty == true,
      cloudAuthenticated: SupabaseService.instance.isAuthenticated,
      cloudConnection: await _cloudCheck(),
      incidents: incidents,
    );
  }

  OperationalIncidentSummary _incidentFromEvent(AuditEvent event) {
    return OperationalIncidentSummary(
      eventType: event.eventType,
      fingerprint: event.details['fingerprint']?.toString() ?? 'غير متوفر',
      source: event.details['source']?.toString() ?? 'unknown',
      createdAt: event.createdAt,
    );
  }
}
