import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const pathOf = (path) => resolve(root, path);
const read = (path) => readFileSync(pathOf(path), "utf8");
const requireFile = (path) => {
  if (!existsSync(pathOf(path))) throw new Error(`P1.25 missing ${path}`);
};
const requireAll = (path, fragments) => {
  const source = path === "lib/services/database_service.dart"
    ? read(path) + read("lib/services/local_database_schema.dart")
    : read(path);
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`P1.25 missing ${fragment} in ${path}`);
    }
  }
  return source;
};

requireAll("pubspec.yaml", [
  "version: 4.3.0-alpha.25+82",
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
]);
requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.25'",
  "buildNumber = 82",
  "releaseLabel = 'P1.27'",
]);
requireAll("lib/services/database_service.dart", [
  "static const int version = 26",
  "_upgradeToVersion24",
  "CREATE TABLE IF NOT EXISTS rules_config_history",
  "idx_daily_records_date_attendance_student",
  "idx_memorization_student_date_revision",
  "idx_behavior_student_date_type_resolved",
  "getSmartPlanGateReasons",
  "upsertQuranCoursesFromSync",
  "upsertQuranCourseEnrollmentsFromSync",
  "getBehaviorPointsInRange",
  "getVacationsInRange",
  "getFundTransactionsInRange",
  "getExamsInRange",
  "upsertFamiliesFromSync",
  "upsertFamilyGuardiansFromSync",
  "upsertBehaviorPointsFromSync",
  "upsertVacationsFromSync",
  "upsertExamsFromSync",
  "upsertTalaqqinRecordsFromSync",
  "upsertStudentAdminActionsFromSync",
  "upsertFundTransactionsFromSync",
  "upsertNotificationsFromSync",
  "upsertDailyAchievementsFromSync",
  "_batchUpsertMapsById",
  "REPLACE` is implemented as delete+insert",
]);

const pdf = requireAll("lib/services/pdf_service.dart", [
  "rootBundle.load('assets/fonts/Tajawal-400.ttf')",
  "rootBundle.load('assets/fonts/Tajawal-700.ttf')",
  "pw.ThemeData.withFont",
  "base: _pdfRegularFont",
  "bold: _pdfBoldFont",
  "_normalizeQuranTextForPdf",
  "replaceAll('ٱ', 'ا')",
  "_rtlTableRow",
  "_rtlColumnWidths",
  "generateArabicFontDiagnosticPdf",
  "textDirection: pw.TextDirection.rtl",
]);
if (pdf.includes("rootBundle.load('assets/fonts/ReadexPro.ttf')")) {
  throw new Error("P1.25 PDF must not use the variable Readex Pro TTF");
}
if (/Font\.helvetica\s*\(|fontFallback/.test(pdf)) {
  throw new Error("P1.25 PDF must not introduce a Latin/system fallback font");
}
const pageCount = (pdf.match(/pw\.(?:MultiPage|Page)\s*\(/g) ?? []).length;
const rtlCount = (pdf.match(/textDirection:\s*pw\.TextDirection\.rtl/g) ?? []).length;
if (pageCount < 10 || rtlCount < pageCount) {
  throw new Error(`P1.25 every PDF page must be explicit RTL (${rtlCount}/${pageCount})`);
}
requireAll("lib/screens/settings/diagnostics_screen.dart", [
  "اختبار PDF العربي",
  "generateArabicFontDiagnosticPdf",
  "Printing.layoutPdf",
]);

requireAll("lib/services/daily_excellence_service.dart", [
  "_fractionalGroupAmount",
  "_referenceWeights",
  "byPage: true",
  "byPage: false",
  "(entry.value / denominator).clamp(0.0, 1.0)",
]);
requireAll("test/daily_excellence_service_test.dart", [
  "a complete face is exactly one and does not look like an overrun",
  "touching a page does not count as completing a full face",
]);
requireAll("lib/services/database_service.dart", [
  "[rule completion=$completionReward;extra=$extraReward;",
  "getPointsConfigHistory",
  "Historical automatic penalties are frozen",
]);
requireAll("lib/screens/settings/settings_screen.dart", [
  "سجل إصدارات قواعد النقاط",
]);

const reports = requireAll("lib/services/student_period_report_service.dart", [
  "_db.getDailyRecordsInRange(start, end)",
  "_db.getMemorizationInRange(start, end)",
  "_db.getBehaviorPointsInRange(start, end)",
  "_db.getVacationsInRange(start, end)",
  "_db.getAllStudentHoldsInRange(start, end)",
  "_db.getFundTransactionsInRange(start, end)",
  "_db.getExamsInRange(start, end)",
  "_groupByStudent",
]);
const multiStudentSection = reports.split("Future<List<StudentPeriodReport>> generateForStudents", 2)[1]?.split("static Map<String, List<T>> _groupByStudent", 1)[0] ?? "";
if (/getStudent(?:Records|Memorization|BehaviorPoints|Vacations|Holds|FundTransactions|Exams)InRange\(student\.id/.test(multiStudentSection)) {
  throw new Error("P1.25 multi-student reports must not regress to N+1 period reads");
}

const database = read("lib/services/database_service.dart") + read("lib/services/local_database_schema.dart");
for (const method of [
  "upsertExamsFromSync",
  "upsertBehaviorPointsFromSync",
  "upsertQuranCoursesFromSync",
  "upsertQuranCourseEnrollmentsFromSync",
]) {
  const start = database.indexOf(`Future<void> ${method}`);
  if (start < 0) throw new Error(`P1.25 missing ${method}`);
  const next = database.indexOf("\n  Future<", start + 16);
  const block = database.slice(start, next < 0 ? database.length : next);
  if (block.includes("ConflictAlgorithm.replace")) {
    throw new Error(`P1.25 ${method} must not REPLACE parent rows during sync`);
  }
}

requireAll("lib/services/supabase_service.dart", [
  "upsertQuranCoursesFromSync(remoteCourses)",
  "upsertQuranCourseEnrollmentsFromSync(remoteEnrollments)",
  "_db.upsertFamiliesFromSync(",
  "_db.upsertFamilyGuardiansFromSync(",
  "_db.saveDailyRecords(pending)",
  "_db.upsertBehaviorPointsFromSync(points)",
  "_db.upsertDailyAchievementsFromSync(achievements)",
  "_db.upsertVacationsFromSync(vacations)",
  "_db.upsertTalaqqinRecordsFromSync(records)",
  "_db.upsertStudentAdminActionsFromSync(actions)",
  "_db.upsertExamsFromSync(exams)",
  "_db.upsertFundTransactionsFromSync(transactions)",
  "_db.upsertNotificationsFromSync(notifications)",
]);

for (const path of [
  "website/supabase/P1.25_SUPABASE_PREFLIGHT.sql",
  "website/supabase/migrations/20260809000100_p1_25_cloud_compat.sql",
  "website/supabase/P1.25_VERIFY.sql",
]) requireFile(path);
const preflight = requireAll("website/supabase/P1.25_SUPABASE_PREFLIGHT.sql", [
  "STOP_BASE_SCOPE_MISSING",
  "STOP_BASE_SCOPE_COLUMNS_MISSING",
  "STOP_REFERENCE_TYPE_MISMATCH",
  "READY_FOR_P1_25_REPAIR",
  "public.students",
]);
if (/\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bALTER\b|\bCREATE\s+TABLE\b/i.test(
  preflight.replace(/--.*$/gm, ""),
)) {
  throw new Error("P1.25 preflight must remain read-only");
}
const migration = requireAll(
  "website/supabase/migrations/20260809000100_p1_25_cloud_compat.sql",
  [
    "P1.25_BASE_SCHEMA_MISSING",
    "P1.25_BASE_SCOPE_COLUMNS_MISSING",
    "CREATE TABLE IF NOT EXISTS public.students",
    "CREATE TABLE IF NOT EXISTS public.quran_courses",
    "CREATE TABLE IF NOT EXISTS public.quran_course_enrollments",
    "NOT VALID",
    "BEGIN;",
    "COMMIT;",
  ],
);
const migrationCode = migration.replace(/--.*$/gm, "");
if (/\bDROP\s+TABLE\b|\bTRUNCATE\b|\bDELETE\s+FROM\b/i.test(migrationCode)) {
  throw new Error("P1.25 compatibility migration contains a destructive row/table operation");
}
requireAll("website/supabase/P1.25_VERIFY.sql", [
  "Historical orphan audit",
  "incompatible_uuid_columns",
  "attendance(student_id,date)",
  "quran_course_enrollments(course_id,student_id)",
]);
requireAll("website/supabase/migrations/20260808000200_p1_24_courses_learning_units.sql", [
  "SUPERSEDED FOR PARTIAL/INCONSISTENT CLOUD SCHEMAS",
  "P1.25_SUPABASE_PREFLIGHT.sql",
]);

requireAll("website/src/app/fund/page.tsx", [
  "fund_transactions",
  "settled_negative_points",
]);
requireAll("website/src/app/select-center/page.tsx", ["supabase"]);
const selectCenter = read("website/src/app/select-center/page.tsx");
if (/demo|تجريبي/i.test(selectCenter)) {
  throw new Error("P1.25 center selection must not synthesize demo cloud centers");
}
requireAll("website/src/app/reports/page.tsx", [
  "printStudentPeriodReport",
  "window.open",
]);
requireAll("website/src/app/portal/page.tsx", ["window.print"]);

console.log(
  "P1.25 passed: safe cloud preflight/repair, static Arabic PDF rendering, historical point-rule freeze, normalized page/hizb rewards, and bulk data-loading contracts are protected.",
);
