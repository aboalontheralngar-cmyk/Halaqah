
import 'database_service.dart';
import 'quran_service.dart';

enum DataIntegritySeverity { warning, critical }

class DataIntegrityIssue {
  final String code;
  final String title;
  final String description;
  final int affectedCount;
  final DataIntegritySeverity severity;

  const DataIntegrityIssue({
    required this.code,
    required this.title,
    required this.description,
    required this.affectedCount,
    required this.severity,
  });
}

class LocalDataIntegrityMetrics {
  final int foreignKeyViolations;
  final int duplicateAttendanceGroups;
  final int duplicateIdentityGroups;
  final int invalidStudentCodes;
  final int invalidStudentPlans;
  final int invalidVacationRanges;
  final int invalidQuranRanges;
  final int failedChecks;

  const LocalDataIntegrityMetrics({
    this.foreignKeyViolations = 0,
    this.duplicateAttendanceGroups = 0,
    this.duplicateIdentityGroups = 0,
    this.invalidStudentCodes = 0,
    this.invalidStudentPlans = 0,
    this.invalidVacationRanges = 0,
    this.invalidQuranRanges = 0,
    this.failedChecks = 0,
  });
}

class LocalDataIntegrityReport {
  final DateTime checkedAt;
  final int checkedRules;
  final List<DataIntegrityIssue> issues;

  const LocalDataIntegrityReport({
    required this.checkedAt,
    required this.checkedRules,
    required this.issues,
  });

  bool get isHealthy => issues.isEmpty;
  bool get hasCritical => issues.any(
        (issue) => issue.severity == DataIntegritySeverity.critical,
      );
  int get criticalCount => issues
      .where((issue) => issue.severity == DataIntegritySeverity.critical)
      .length;
  int get warningCount => issues
      .where((issue) => issue.severity == DataIntegritySeverity.warning)
      .length;

  String get statusLabel {
    if (hasCritical) return 'توجد مشكلات حرجة';
    if (issues.isNotEmpty) return 'توجد ملاحظات تحتاج مراجعة';
    return 'سليمة';
  }

  String toSafeSummary() {
    final buffer = StringBuffer()
      ..writeln('الحالة: $statusLabel')
      ..writeln('قواعد الفحص المكتملة: $checkedRules')
      ..writeln('مشكلات حرجة: $criticalCount')
      ..writeln('ملاحظات: $warningCount');
    for (final issue in issues) {
      buffer.writeln(
        '${issue.code}: ${issue.affectedCount} (${issue.severity.name})',
      );
    }
    return buffer.toString().trimRight();
  }
}

class LocalDataIntegrityEvaluator {
  static const totalRules = 7;

  static LocalDataIntegrityReport evaluate(
    LocalDataIntegrityMetrics metrics, {
    DateTime? checkedAt,
  }) {
    final issues = <DataIntegrityIssue>[];

    void add({
      required String code,
      required String title,
      required String description,
      required int count,
      required DataIntegritySeverity severity,
    }) {
      if (count <= 0) return;
      issues.add(
        DataIntegrityIssue(
          code: code,
          title: title,
          description: description,
          affectedCount: count,
          severity: severity,
        ),
      );
    }

    add(
      code: 'foreign_key_violation',
      title: 'سجلات غير مرتبطة بأصلها',
      description:
          'توجد علاقات محلية مفقودة. أنشئ نسخة احتياطية قبل أي تنزيل أو استعادة.',
      count: metrics.foreignKeyViolations,
      severity: DataIntegritySeverity.critical,
    );
    add(
      code: 'duplicate_attendance',
      title: 'حضور مكرر في اليوم نفسه',
      description:
          'وجد أكثر من سجل حضور للطالب نفسه في تاريخ واحد ويجب مراجعته قبل المزامنة.',
      count: metrics.duplicateAttendanceGroups,
      severity: DataIntegritySeverity.critical,
    );
    add(
      code: 'duplicate_identity',
      title: 'هوية طالب مكررة',
      description:
          'يوجد تكرار في كود الطالب أو رمز QR وقد يؤدي إلى اختيار طالب غير صحيح.',
      count: metrics.duplicateIdentityGroups,
      severity: DataIntegritySeverity.critical,
    );
    add(
      code: 'invalid_student_code',
      title: 'كود طالب غير صالح',
      description:
          'الكود الداخلي يجب أن يتكون من عشرين حرفًا أو رقمًا دون رموز إضافية.',
      count: metrics.invalidStudentCodes,
      severity: DataIntegritySeverity.warning,
    );
    add(
      code: 'invalid_student_plan',
      title: 'مقرر طالب غير صالح',
      description:
          'توجد وحدة مقرر غير مدعومة أو مقدار حفظ أو مراجعة أقل من واحد.',
      count: metrics.invalidStudentPlans,
      severity: DataIntegritySeverity.warning,
    );
    add(
      code: 'invalid_vacation_range',
      title: 'فترة إجازة غير صحيحة',
      description: 'يوجد تاريخ نهاية إجازة يسبق تاريخ بدايتها.',
      count: metrics.invalidVacationRanges,
      severity: DataIntegritySeverity.warning,
    );
    add(
      code: 'invalid_quran_range',
      title: 'نطاق قرآني خارج حدود السورة',
      description:
          'يوجد سجل حفظ أو مراجعة يبدأ أو ينتهي خارج عدد آيات السورة الفعلي.',
      count: metrics.invalidQuranRanges,
      severity: DataIntegritySeverity.critical,
    );
    add(
      code: 'audit_incomplete',
      title: 'لم تكتمل جميع قواعد الفحص',
      description:
          'تعذر تنفيذ بعض الاستعلامات؛ أعد فتح التطبيق ثم أعد الفحص قبل المزامنة.',
      count: metrics.failedChecks,
      severity: DataIntegritySeverity.warning,
    );

    return LocalDataIntegrityReport(
      checkedAt: checkedAt ?? DateTime.now(),
      checkedRules:
          (totalRules - metrics.failedChecks).clamp(0, totalRules).toInt(),
      issues: List.unmodifiable(issues),
    );
  }
}

class LocalDataIntegrityService {
  LocalDataIntegrityService({
    DatabaseService? database,
    QuranService? quran,
  })  : _database = database ?? DatabaseService(),
        _quran = quran ?? QuranService.instance;

  final DatabaseService _database;
  final QuranService _quran;

  Future<LocalDataIntegrityReport> audit() async {
    final database = await _database.database;
    var failedChecks = 0;

    Future<int> countQuery(String sql) async {
      try {
        final rows = await database.rawQuery(sql);
        if (rows.isEmpty) return 0;
        return (rows.first['count'] as num?)?.toInt() ?? 0;
      } catch (_) {
        failedChecks += 1;
        return 0;
      }
    }

    var foreignKeyViolations = 0;
    try {
      foreignKeyViolations = (await database.rawQuery(
        'PRAGMA foreign_key_check',
      ))
          .length;
    } catch (_) {
      failedChecks += 1;
    }

    final duplicateAttendanceGroups = await countQuery('''
      SELECT COUNT(*) AS count FROM (
        SELECT student_id, date
        FROM daily_records
        GROUP BY student_id, date
        HAVING COUNT(*) > 1
      )
    ''');

    final duplicateIdentityGroups = await countQuery('''
      SELECT
        (SELECT COUNT(*) FROM (
          SELECT student_code FROM students
          WHERE student_code IS NOT NULL AND trim(student_code) <> ''
          GROUP BY student_code HAVING COUNT(*) > 1
        )) +
        (SELECT COUNT(*) FROM (
          SELECT qr_code FROM students
          WHERE qr_code IS NOT NULL AND trim(qr_code) <> ''
          GROUP BY qr_code HAVING COUNT(*) > 1
        )) AS count
    ''');

    var invalidStudentCodes = 0;
    try {
      final identities = await database.query(
        'students',
        columns: const ['student_code'],
      );
      final validCode = RegExp(r'^[A-Z0-9]{20}$');
      invalidStudentCodes = identities.where((row) {
        final code = row['student_code']?.toString() ?? '';
        return !validCode.hasMatch(code);
      }).length;
    } catch (_) {
      failedChecks += 1;
    }

    final invalidStudentPlans = await countQuery('''
      SELECT COUNT(*) AS count
      FROM students
      WHERE plan_type NOT IN ('ayahs', 'pages', 'lines', 'hizbs')
         OR plan_amount IS NULL OR plan_amount < 1
         OR review_plan_amount IS NULL OR review_plan_amount < 1
         OR total_memorized IS NULL OR total_memorized < 0
         OR total_memorized > 6236
    ''');

    final invalidVacationRanges = await countQuery('''
      SELECT COUNT(*) AS count
      FROM vacations
      WHERE date(end_date) < date(start_date)
    ''');

    var invalidQuranRanges = 0;
    try {
      await _quran.initialize();
      for (final table in const ['memorization_progress', 'homework_grades']) {
        final ranges = await database.query(
          table,
          columns: const ['surah_id', 'from_ayah', 'to_ayah'],
        );
        for (final row in ranges) {
          final surahId = (row['surah_id'] as num?)?.toInt() ?? 0;
          final fromAyah = (row['from_ayah'] as num?)?.toInt() ?? 0;
          final toAyah = (row['to_ayah'] as num?)?.toInt() ?? 0;
          final maximum = _quran.getSurahAyahCount(surahId);
          if (maximum == 0 ||
              fromAyah < 1 ||
              toAyah < fromAyah ||
              toAyah > maximum) {
            invalidQuranRanges += 1;
          }
        }
      }
    } catch (_) {
      failedChecks += 1;
    }

    return LocalDataIntegrityEvaluator.evaluate(
      LocalDataIntegrityMetrics(
        foreignKeyViolations: foreignKeyViolations,
        duplicateAttendanceGroups: duplicateAttendanceGroups,
        duplicateIdentityGroups: duplicateIdentityGroups,
        invalidStudentCodes: invalidStudentCodes,
        invalidStudentPlans: invalidStudentPlans,
        invalidVacationRanges: invalidVacationRanges,
        invalidQuranRanges: invalidQuranRanges,
        failedChecks: failedChecks,
      ),
    );
  }
}
