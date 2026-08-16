import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(process.cwd(), "..");
const pathOf = (p) => resolve(root, p);
const read = (p) => readFileSync(pathOf(p), "utf8");
const requireFile = (p) => {
  if (!existsSync(pathOf(p))) throw new Error(`P1.26 missing ${p}`);
  return read(p);
};
const requireAll = (p, fragments) => {
  const text = p === "lib/services/database_service.dart"
    ? requireFile(p) + requireFile("lib/services/local_database_schema.dart")
    : requireFile(p);
  for (const fragment of fragments) {
    if (!text.includes(fragment)) throw new Error(`P1.26 missing ${fragment} in ${p}`);
  }
  return text;
};
const stripSqlComments = (sql) => sql
  .replace(/\/\*[\s\S]*?\*\//g, "")
  .replace(/--.*$/gm, "");

requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.24'",
  "buildNumber = 80",
  "releaseLabel = 'P1.27'",
]);
requireAll("lib/utils/constants.dart", ["appVersion = '4.3.0-alpha.24'"]);
requireAll("pubspec.yaml", [
  "version: 4.3.0-alpha.24+80",
  "family: Tajawal",
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
]);
const theme = requireAll("lib/app/theme.dart", [
  "fontFamily: 'Tajawal'",
  "bodyColor: scheme.onSurface",
  "displayColor: scheme.onSurface",
  "color: scheme.onSurface",
]);
if (theme.includes("fontFamily: 'ReadexPro'")) {
  throw new Error("P1.26 Flutter UI must use the same static Tajawal family as PDF");
}

requireAll("lib/services/supabase_service.dart", [
  "import '../models/behavior_point.dart';",
  "import '../models/fund_transaction.dart';",
  "final points = <BehaviorPoint>[];",
  "final transactions = <FundTransaction>[];",
]);
const analysisOptions = requireFile("analysis_options.yaml");
if (analysisOptions.includes("package:lints/recommended.yaml")) {
  throw new Error("P1.26 analyzer config must not reference undeclared package:lints");
}

const constDynamicChecks = [
  ["lib/screens/reports/reports_screen.dart", "يرجى إبقاء هذه الشاشة مفتوحة حتى يكتمل إنشاء الملف."],
  ["lib/screens/reports/student_period_report_screen.dart", "المؤشر يجمع المواظبة والتسميع والمراجعة والجودة والنقاط اليومية."],
  ["lib/screens/settings/message_templates_screen.dart", "المتغيرات المتاحة (سيتم استبدالها تلقائياً):"],
  ["lib/screens/students/student_detail_screen.dart", "يبقى تسجيل الحضور متاحًا خلال الإيقاف."],
  ["lib/screens/students/student_detail_screen.dart", "تغيير الرقم يلغي جميع الجلسات القديمة."],
  ["lib/screens/vacations/vacations_screen.dart", "المدة الزمنية"],
  ["lib/screens/vacations/vacations_screen.dart", "السبب والمدة"],
];
for (const [file, marker] of constDynamicChecks) {
  const source = requireFile(file);
  const markerIndex = source.indexOf(marker);
  if (markerIndex < 0) throw new Error(`P1.26 missing const-regression marker in ${file}: ${marker}`);
  const before = source.slice(Math.max(0, markerIndex - 220), markerIndex);
  const after = source.slice(markerIndex, Math.min(source.length, markerIndex + 320));
  const textStart = before.lastIndexOf("Text(");
  const constructorPrefix = textStart >= 0 ? before.slice(Math.max(0, textStart - 12), textStart + 5) : "";
  if (/const\s+Text\($/.test(constructorPrefix) && /Theme\.of\(context\)/.test(after)) {
    throw new Error(`P1.26 ${file} must not call Theme.of(context) from a const Text expression near: ${marker}`);
  }
}

requireAll("lib/services/pdf_service.dart", [
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
  "generateArabicFontDiagnosticPdf",
  "textDirection: pw.TextDirection.rtl",
]);

requireAll("lib/models/competition.dart", ["CompetitionEvent copyWith"]);
requireAll("lib/services/database_service.dart", [
  "getCompetitionResultCounts",
  "Future<void> deleteCompetitionEvent",
  "await db.transaction((txn) async",
]);
requireAll("lib/screens/competition/competitions_screen.dart", [
  "PopupMenuButton<String>",
  "تعديل الاسم والفئة",
  "حذف المسابقة",
  "_editEvent",
  "_deleteEvent",
]);

for (const file of [
  "lib/screens/memorization/recitation_screen.dart",
  "lib/screens/memorization/mushaf_visualizer_screen.dart",
  "lib/screens/students/families_screen.dart",
  "lib/screens/students/student_detail_screen.dart",
]) {
  const text = requireFile(file);
  if (/TextStyle\([^\n]*color:\s*Colors\.grey/.test(text) || /color:\s*Colors\.grey\.shade(?:50|100|200)/.test(text)) {
    throw new Error(`P1.26 ${file} still contains a known low-contrast light-only text/surface pattern`);
  }
}

const audit = stripSqlComments(requireAll("website/supabase/P1.26_SUPABASE_DEEP_AUDIT.sql", [
  "EMPTY_PROJECT_READY_FOR_GUARDED_BASE_BOOTSTRAP",
  "STOP_ORPHAN_APP_TABLES_WITHOUT_BASE_SCOPE",
  "BASE_SCOPE_PRESENT_RERUN_P1_25_PREFLIGHT",
]));
if (/\b(CREATE|ALTER|DROP|TRUNCATE|INSERT|UPDATE|DELETE|GRANT|REVOKE)\b/i.test(audit)) {
  throw new Error("P1.26 deep audit must remain read-only");
}
const bootstrap = stripSqlComments(requireAll("website/supabase/P1.26_GUARDED_BASE_BOOTSTRAP.sql", [
  "P1.26_BOOTSTRAP_BLOCKED_EXISTING_APP_TABLES",
  "CREATE TABLE public.profiles",
  "CREATE TABLE public.centers",
  "CREATE TABLE public.halaqat",
  "CREATE TABLE public.center_members",
  "CREATE TABLE public.families",
  "CREATE TABLE public.family_guardians",
  "current_user_can_access_halaqa",
]));
if (/\b(DROP\s+TABLE|TRUNCATE|DELETE\s+FROM|UPDATE\s+public\.)\b/i.test(bootstrap)) {
  throw new Error("P1.26 guarded bootstrap must not destroy or rewrite application rows");
}
requireAll("website/supabase/migrations/20260809000100_p1_25_cloud_compat.sql", [
  "P1.25_BASE_SCHEMA_MISSING",
  "P1.25_BASE_SCOPE_COLUMNS_MISSING",
]);

const postBootstrapCore = stripSqlComments(requireAll("website/supabase/P1.26_POST_BOOTSTRAP_CORE.sql", [
  "P1.26_POST_BOOTSTRAP_BASE_MISSING",
  "CREATE TABLE IF NOT EXISTS public.students",
  "CREATE TABLE IF NOT EXISTS public.attendance",
  "CREATE TABLE IF NOT EXISTS public.quran_courses",
]));
for (const foreignTable of ["Subscribers", "Readings", "Fillings", "Collections", "Expenses", "SubscriberPoints", "AppNotifications"]) {
  const unsafe = new RegExp(`(?:ALTER\\s+TABLE|DROP\\s+TABLE|TRUNCATE|DELETE\\s+FROM|UPDATE)\\s+public\\.${foreignTable}\\b`, "i");
  if (unsafe.test(postBootstrapCore)) {
    throw new Error(`P1.26 post-bootstrap core migration must not mutate unrelated table ${foreignTable}`);
  }
}
const postBootstrapVerify = stripSqlComments(requireAll("website/supabase/P1.26_POST_BOOTSTRAP_VERIFY.sql", [
  "READY_FOR_APP_SYNC_TEST",
  "current_user_can_access_student",
  "core_tables_without_rls",
]));
if (/\b(CREATE|ALTER|DROP|TRUNCATE|INSERT|UPDATE|DELETE|GRANT|REVOKE)\b/i.test(postBootstrapVerify)) {
  throw new Error("P1.26 post-bootstrap verify must remain read-only");
}

console.log("P1.26 passed: unified static Arabic UI/PDF font, contrast-safe core screens, editable/deletable competitions, and guarded Supabase base-scope recovery are protected.");
