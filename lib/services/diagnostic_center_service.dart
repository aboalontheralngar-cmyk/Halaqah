import 'dart:io';

import '../app/build_info.dart';
import '../models/audit_event.dart';
import 'audit_log_service.dart';
import 'backup_service.dart';
import 'cloud_connection_diagnostics.dart';
import 'database_service.dart';
import 'local_data_integrity_service.dart';
import 'supabase_service.dart';

class OperationalIncidentSummary {
  final String eventType;
  final String fingerprint;
  final String source;
  final String? operation;
  final DateTime createdAt;

  const OperationalIncidentSummary({
    required this.eventType,
    required this.fingerprint,
    required this.source,
    this.operation,
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
  final String? lastCloudSyncFailedStage;
  final String? lastCloudSyncErrorCode;
  final DateTime? lastCloudSyncFailedAt;
  final bool hasAutomaticBackupError;
  final DateTime? lastBackgroundBackupWorkerAt;
  final String backgroundBackupWorkerStatus;
  final bool hasBackgroundBackupSchedulerError;
  final bool cloudAuthenticated;
  final CloudConnectionDiagnostic cloudConnection;
  final LocalDataIntegrityReport dataIntegrity;
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
    this.lastCloudSyncFailedStage,
    this.lastCloudSyncErrorCode,
    this.lastCloudSyncFailedAt,
    required this.hasAutomaticBackupError,
    required this.lastBackgroundBackupWorkerAt,
    required this.backgroundBackupWorkerStatus,
    required this.hasBackgroundBackupSchedulerError,
    required this.cloudAuthenticated,
    required this.cloudConnection,
    required this.dataIntegrity,
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
      ..writeln(
        'آخر مرحلة مزامنة فاشلة: ${lastCloudSyncFailedStage?.isNotEmpty == true ? lastCloudSyncFailedStage : 'لا يوجد'}',
      )
      ..writeln(
        'رمز خطأ المزامنة: ${lastCloudSyncErrorCode?.isNotEmpty == true ? lastCloudSyncErrorCode : 'لا يوجد'}',
      )
      ..writeln('وقت فشل المزامنة: ${date(lastCloudSyncFailedAt)}')
      ..writeln('خطأ نسخ تلقائي معلق: $hasAutomaticBackupError')
      ..writeln(
        'آخر تشغيل خلفي: ${date(lastBackgroundBackupWorkerAt)}',
      )
      ..writeln('حالة التشغيل الخلفي: $backgroundBackupWorkerStatus')
      ..writeln(
        'خطأ جدولة خلفية معلق: $hasBackgroundBackupSchedulerError',
      )
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
      ..writeln('--- سلامة البيانات المحلية ---')
      ..writeln(dataIntegrity.toSafeSummary());
    buffer
      ..writeln('--- الحوادث المنقحة (${incidents.length}) ---');
    for (final incident in incidents.take(20)) {
      buffer.writeln(
        '${date(incident.createdAt)} | ${incident.eventType} | '
        '${incident.source}${incident.operation == null ? '' : ' · ${incident.operation}'} | '
        '${incident.fingerprint}',
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
    LocalDataIntegrityService? dataIntegrity,
    Future<CloudConnectionDiagnostic> Function()? cloudCheck,
  })  : _database = database ?? DatabaseService(),
        _audit = audit ?? AuditLogService(),
        _backup = backup ?? BackupService(),
        _dataIntegrity = dataIntegrity ?? LocalDataIntegrityService(),
        _cloudCheck = cloudCheck ?? SupabaseService.instance.diagnoseConnection;

  final DatabaseService _database;
  final AuditLogService _audit;
  final BackupService _backup;
  final LocalDataIntegrityService _dataIntegrity;
  final Future<CloudConnectionDiagnostic> Function() _cloudCheck;

  static const _countedTables = <String, String>{
    'الطلاب': 'students',
    'الحضور': 'daily_records',
    'الحفظ والمراجعة': 'memorization_progress',
    'النقاط': 'behavior_points',
    'الخطط': 'plans',
    'الاختبارات': 'exams',
    'العائلات': 'families',
    'حذف بانتظار المزامنة': 'sync_delete_outbox',
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
    counts['سجلات حفظ سحابية تحتاج مراجعة'] = int.tryParse(
          await _database.getSetting('last_cloud_memorization_skipped_count') ??
              '',
        ) ??
        0;

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
    final lastCloudSyncFailedStage =
        (await _database.getSetting('last_cloud_sync_failed_stage'))?.trim();
    final lastCloudSyncErrorCode =
        (await _database.getSetting('last_cloud_sync_error_code'))?.trim();
    final lastCloudSyncFailedAt = DateTime.tryParse(
      await _database.getSetting('last_cloud_sync_failed_at') ?? '',
    );
    final automaticBackupError =
        (await _database.getSetting('last_automatic_backup_error'))?.trim();
    final lastBackgroundWorkerAt = DateTime.tryParse(
      await _database.getSetting('last_background_backup_worker_at') ?? '',
    );
    final backgroundWorkerStatus = await _database.getSetting(
          'last_background_backup_worker_status',
        ) ??
        'لم يعمل بعد';
    final schedulerError = (await _database.getSetting(
      'last_background_backup_scheduler_error',
    ))
        ?.trim();
    final versionRows = await database.rawQuery('PRAGMA user_version');
    final versionValue = versionRows.isEmpty || versionRows.first.values.isEmpty
        ? null
        : versionRows.first.values.first;
    final databaseVersion = versionValue is num
        ? versionValue.toInt()
        : int.tryParse(versionValue?.toString() ?? '') ?? 0;

    return DiagnosticSnapshot(
      generatedAt: DateTime.now(),
      operatingSystem: Platform.operatingSystem,
      operatingSystemVersion: Platform.operatingSystemVersion,
      databaseVersion: databaseVersion,
      recordCounts: counts,
      localBackupCount: backups.length,
      lastBackupAt: lastBackupAt,
      lastCloudUploadAt: lastUploadAt,
      lastCloudDownloadAt: lastDownloadAt,
      lastSyncDirection: lastDirection,
      lastCloudSyncFailedStage: lastCloudSyncFailedStage,
      lastCloudSyncErrorCode: lastCloudSyncErrorCode,
      lastCloudSyncFailedAt: lastCloudSyncFailedAt,
      hasAutomaticBackupError: automaticBackupError?.isNotEmpty == true,
      lastBackgroundBackupWorkerAt: lastBackgroundWorkerAt,
      backgroundBackupWorkerStatus: backgroundWorkerStatus,
      hasBackgroundBackupSchedulerError: schedulerError?.isNotEmpty == true,
      cloudAuthenticated: SupabaseService.instance.isAuthenticated,
      cloudConnection: await _cloudCheck(),
      dataIntegrity: await _dataIntegrity.audit(),
      incidents: incidents,
    );
  }

  OperationalIncidentSummary _incidentFromEvent(AuditEvent event) {
    return OperationalIncidentSummary(
      eventType: event.eventType,
      fingerprint: event.details['fingerprint']?.toString() ?? 'غير متوفر',
      source: event.details['source']?.toString() ?? 'unknown',
      operation: event.details['operation']?.toString(),
      createdAt: event.createdAt,
    );
  }
}
