import 'dart:convert';

import '../app/build_info.dart';
import 'database_service.dart';
import 'diagnostic_center_service.dart';

enum OperationalReadinessState { passed, warning, blocked, pending }

class OperationalReadinessCheck {
  final String code;
  final String title;
  final String description;
  final OperationalReadinessState state;
  final bool manual;

  const OperationalReadinessCheck({
    required this.code,
    required this.title,
    required this.description,
    required this.state,
    this.manual = false,
  });
}

class OperationalReadinessInput {
  final int databaseVersion;
  final bool hasCriticalDataIssue;
  final bool hasDataWarnings;
  final int localBackupCount;
  final DateTime? lastBackupAt;
  final bool hasAutomaticBackupError;
  final bool hasBackgroundBackupSchedulerError;
  final bool cloudConnectionHealthy;
  final bool cloudAuthenticated;
  final int recentIncidentCount;
  final Set<String> completedManualChecks;

  const OperationalReadinessInput({
    required this.databaseVersion,
    required this.hasCriticalDataIssue,
    required this.hasDataWarnings,
    required this.localBackupCount,
    required this.lastBackupAt,
    required this.hasAutomaticBackupError,
    required this.hasBackgroundBackupSchedulerError,
    required this.cloudConnectionHealthy,
    required this.cloudAuthenticated,
    required this.recentIncidentCount,
    this.completedManualChecks = const <String>{},
  });
}

class OperationalReadinessReport {
  final DateTime generatedAt;
  final List<OperationalReadinessCheck> checks;

  const OperationalReadinessReport({
    required this.generatedAt,
    required this.checks,
  });

  Iterable<OperationalReadinessCheck> get automaticChecks =>
      checks.where((check) => !check.manual);
  Iterable<OperationalReadinessCheck> get manualChecks =>
      checks.where((check) => check.manual);
  int get passedCount => checks
      .where((check) => check.state == OperationalReadinessState.passed)
      .length;
  int get warningCount => checks
      .where((check) => check.state == OperationalReadinessState.warning)
      .length;
  int get blockedCount => checks
      .where((check) => check.state == OperationalReadinessState.blocked)
      .length;
  int get pendingCount => checks
      .where((check) => check.state == OperationalReadinessState.pending)
      .length;
  bool get isReady => blockedCount == 0 && pendingCount == 0;

  String get statusLabel {
    if (blockedCount > 0) return 'غير جاهز — توجد عوائق';
    if (pendingCount > 0) return 'ينتظر اختبارات القبول';
    if (warningCount > 0) return 'جاهز مع ملاحظات';
    return 'جاهز للاختبار المرحلي';
  }

  String toSafeReport() {
    final buffer = StringBuffer()
      ..writeln('تقرير جاهزية حلقتي')
      ..writeln('الإصدار: ${AppBuildInfo.displayVersion}')
      ..writeln('وقت الفحص: ${generatedAt.toLocal().toIso8601String()}')
      ..writeln('الحالة: $statusLabel')
      ..writeln('اجتاز: $passedCount من ${checks.length}')
      ..writeln('عوائق: $blockedCount')
      ..writeln('ملاحظات: $warningCount')
      ..writeln('قبول يدوي متبقٍ: $pendingCount')
      ..writeln('--- النتائج ---');
    for (final check in checks) {
      buffer.writeln(
        '${check.code}: ${check.state.name} — ${check.description}',
      );
    }
    buffer.writeln(
      'هذا التقرير منقح ولا يحتوي أسماء الطلاب أو الهواتف أو الملاحظات أو المعرفات أو رموز الجلسات.',
    );
    return buffer.toString();
  }
}

class OperationalReadinessEvaluator {
  static const expectedDatabaseVersion = 18;
  static const maximumBackupAge = Duration(days: 7);

  static const manualRequirements = <String, String>{
    'two_device_sync': 'اختبار الرفع والتنزيل على جهازين دون فقد البيانات',
    'encrypted_restore': 'استعادة نسخة مشفرة والتحقق من البيانات بعد الاستعادة',
    'portal_isolation': 'اختبار عزل حسابين ومركزين وبوابتي الطالب والعائلة',
    'physical_printing': 'اختبار A4 وA5 والكاشير على طابعة فعلية',
    'qr_attendance': 'اختبار بطاقات QR والتحضير على جهاز فعلي',
  };

  static OperationalReadinessReport evaluate(
    OperationalReadinessInput input, {
    DateTime? now,
  }) {
    final checkedAt = now ?? DateTime.now();
    final checks = <OperationalReadinessCheck>[];

    checks.add(
      OperationalReadinessCheck(
        code: 'database_schema',
        title: 'مخطط قاعدة البيانات المحلية',
        description: input.databaseVersion >= expectedDatabaseVersion
            ? 'SQLite بالإصدار ${input.databaseVersion} وهو متوافق.'
            : 'SQLite بالإصدار ${input.databaseVersion}؛ المطلوب $expectedDatabaseVersion أو أحدث.',
        state: input.databaseVersion >= expectedDatabaseVersion
            ? OperationalReadinessState.passed
            : OperationalReadinessState.blocked,
      ),
    );

    checks.add(
      OperationalReadinessCheck(
        code: 'local_data_integrity',
        title: 'سلامة البيانات المحلية',
        description: input.hasCriticalDataIssue
            ? 'اكتُشفت مشكلة حرجة؛ لا تنزّل من السحابة قبل إنشاء نسخة ومراجعة التشخيص.'
            : input.hasDataWarnings
                ? 'اكتمل الفحص مع ملاحظات غير حرجة تحتاج مراجعة.'
                : 'لم يكتشف الفحص مشكلات في العلاقات أو الهوية أو النطاقات.',
        state: input.hasCriticalDataIssue
            ? OperationalReadinessState.blocked
            : input.hasDataWarnings
                ? OperationalReadinessState.warning
                : OperationalReadinessState.passed,
      ),
    );

    final backupAge = input.lastBackupAt == null
        ? null
        : checkedAt.difference(input.lastBackupAt!);
    final backupFresh = input.localBackupCount > 0 &&
        backupAge != null &&
        !backupAge.isNegative &&
        backupAge <= maximumBackupAge;
    checks.add(
      OperationalReadinessCheck(
        code: 'fresh_local_backup',
        title: 'نسخة حماية حديثة',
        description: backupFresh
            ? 'توجد نسخة محلية خلال آخر سبعة أيام.'
            : 'أنشئ نسخة محلية مشفرة الآن قبل المزامنة أو الاختبار.',
        state: backupFresh
            ? OperationalReadinessState.passed
            : OperationalReadinessState.blocked,
      ),
    );

    final backupHealthy = !input.hasAutomaticBackupError &&
        !input.hasBackgroundBackupSchedulerError;
    checks.add(
      OperationalReadinessCheck(
        code: 'backup_automation',
        title: 'النسخ التلقائي',
        description: backupHealthy
            ? 'لا توجد أخطاء نسخ أو جدولة معلقة.'
            : 'يوجد خطأ نسخ أو جدولة معلق؛ أنشئ نسخة يدوية وراجع الإعدادات.',
        state: backupHealthy
            ? OperationalReadinessState.passed
            : OperationalReadinessState.warning,
      ),
    );

    checks.add(
      OperationalReadinessCheck(
        code: 'cloud_connection',
        title: 'اتصال Supabase',
        description: input.cloudConnectionHealthy
            ? 'الوصول إلى خادم Supabase سليم.'
            : 'فشل فحص الشبكة أو DNS أو TLS؛ المزامنة غير جاهزة.',
        state: input.cloudConnectionHealthy
            ? OperationalReadinessState.passed
            : OperationalReadinessState.blocked,
      ),
    );

    checks.add(
      OperationalReadinessCheck(
        code: 'cloud_session',
        title: 'جلسة المزامنة',
        description: input.cloudAuthenticated
            ? 'الحساب السحابي متصل وجاهز للاختبار.'
            : 'سجّل الدخول بالحساب المرحلي قبل اختبار الرفع أو التنزيل.',
        state: input.cloudAuthenticated
            ? OperationalReadinessState.passed
            : OperationalReadinessState.blocked,
      ),
    );

    checks.add(
      OperationalReadinessCheck(
        code: 'recent_incidents',
        title: 'الحوادث البرمجية الحديثة',
        description: input.recentIncidentCount == 0
            ? 'لا توجد حوادث تشغيلية حديثة مسجلة.'
            : 'يوجد ${input.recentIncidentCount} حادث تشغيلي منقح يحتاج مراجعة.',
        state: input.recentIncidentCount == 0
            ? OperationalReadinessState.passed
            : OperationalReadinessState.warning,
      ),
    );

    for (final requirement in manualRequirements.entries) {
      final completed = input.completedManualChecks.contains(requirement.key);
      checks.add(
        OperationalReadinessCheck(
          code: requirement.key,
          title: requirement.value,
          description: completed
              ? 'أكّد المختبر نجاح هذا البند على البيئة الفعلية.'
              : 'لم يُعتمد هذا الاختبار على البيئة الفعلية بعد.',
          state: completed
              ? OperationalReadinessState.passed
              : OperationalReadinessState.pending,
          manual: true,
        ),
      );
    }

    return OperationalReadinessReport(
      generatedAt: checkedAt,
      checks: List.unmodifiable(checks),
    );
  }
}

class OperationalReadinessService {
  OperationalReadinessService({
    DiagnosticCenterService? diagnostics,
    DatabaseService? database,
  })  : _diagnostics = diagnostics ?? DiagnosticCenterService(),
        _database = database ?? DatabaseService();

  final DiagnosticCenterService _diagnostics;
  final DatabaseService _database;

  String get _manualSettingKey =>
      'release_acceptance_manual_${AppBuildInfo.versionName}';

  Future<OperationalReadinessReport> collect() async {
    final snapshot = await _diagnostics.collect();
    final completed = await loadCompletedManualChecks();
    return OperationalReadinessEvaluator.evaluate(
      OperationalReadinessInput(
        databaseVersion: snapshot.databaseVersion,
        hasCriticalDataIssue: snapshot.dataIntegrity.hasCritical,
        hasDataWarnings: snapshot.dataIntegrity.warningCount > 0,
        localBackupCount: snapshot.localBackupCount,
        lastBackupAt: snapshot.lastBackupAt,
        hasAutomaticBackupError: snapshot.hasAutomaticBackupError,
        hasBackgroundBackupSchedulerError:
            snapshot.hasBackgroundBackupSchedulerError,
        cloudConnectionHealthy: snapshot.cloudConnection.isHealthy,
        cloudAuthenticated: snapshot.cloudAuthenticated,
        recentIncidentCount: snapshot.incidents.length,
        completedManualChecks: completed,
      ),
    );
  }

  Future<Set<String>> loadCompletedManualChecks() async {
    final raw = await _database.getSetting(_manualSettingKey);
    if (raw == null || raw.trim().isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .map((value) => value.toString())
          .where(OperationalReadinessEvaluator.manualRequirements.containsKey)
          .toSet();
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> setManualCheck(String code, bool completed) async {
    if (!OperationalReadinessEvaluator.manualRequirements.containsKey(code)) {
      throw ArgumentError.value(code, 'code', 'Unknown acceptance check');
    }
    final current = await loadCompletedManualChecks();
    if (completed) {
      current.add(code);
    } else {
      current.remove(code);
    }
    final ordered = OperationalReadinessEvaluator.manualRequirements.keys
        .where(current.contains)
        .toList();
    await _database.saveSetting(_manualSettingKey, jsonEncode(ordered));
  }
}
