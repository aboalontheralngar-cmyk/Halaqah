import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireFile = (path) => {
  if (!existsSync(resolve(root, path))) throw new Error(`P1.24 missing ${path}`);
};
const requireAll = (path, fragments) => {
  const source = path === "lib/services/database_service.dart"
    ? read(path) + read("lib/services/local_database_schema.dart")
    : read(path);
  for (const fragment of fragments) {
    if (!source.includes(fragment)) throw new Error(`P1.24 missing ${fragment} in ${path}`);
  }
  return source;
};

requireAll("pubspec.yaml", [
  "version: 4.3.0-alpha.24+80",
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
  "family: Tajawal",
]);
requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.24'",
  "buildNumber = 80",
  "releaseLabel = 'P1.27'",
]);
requireAll("lib/services/database_service.dart", [
  "static const int version = 26",
  "_upgradeToVersion23",
  "_upgradeToVersion23",
  "review_plan_type",
  "talaqqin_enabled",
  "review_unit",
  "CREATE TABLE IF NOT EXISTS quran_courses",
  "CREATE TABLE IF NOT EXISTS quran_course_enrollments",
  "getActiveQuranCourseForStudent",
  "deleted_quran_course_ids",
  "deleted_quran_course_enrollment_ids",
]);

const theme = requireAll("lib/app/theme.dart", [
  "Color(0xFF176B57)",
  "Color(0xFF3B8B75)",
  "Color(0xFF0F4F40)",
  "Color(0xFF9B6C2F)",
  "Color(0xFFF5F3ED)",
  "Color(0xFFFFFEFA)",
  "toolbarHeight: 52",
  "height: 62",
  "fontFamily: 'Tajawal'",
]);
if (theme.includes("Color(0xFF163B55)")) {
  throw new Error("P1.24 must keep the restored pre-P1.23 primary palette");
}
requireAll("website/src/app/globals.css", [
  "--background: #f5f3ed",
  "--foreground: #17241f",
  "--primary: #176b57",
  "--gold: #9b6c2f",
]);

const pdf = requireAll("lib/services/pdf_service.dart", [
  "rootBundle.load('assets/fonts/Tajawal-400.ttf')",
  "rootBundle.load('assets/fonts/Tajawal-700.ttf')",
  "pw.ThemeData.withFont",
  "base: _pdfRegularFont",
  "bold: _pdfBoldFont",
  "_rtlTableRow",
  "_rtlColumnWidths",
  "textDirection: pw.TextDirection.rtl",
  "اختبارات الفترة",
  "نتيجة الامتحان",
]);
if (/Font\.helvetica|fontFallback/.test(pdf)) {
  throw new Error("P1.25 PDF must never fall back to a non-Arabic system font");
}
const pageCount = (pdf.match(/pw\.(?:MultiPage|Page)\s*\(/g) ?? []).length;
const rtlCount = (pdf.match(/textDirection:\s*pw\.TextDirection\.rtl/g) ?? []).length;
if (pageCount < 10 || rtlCount < pageCount) {
  throw new Error(`P1.24 every PDF page must be RTL (${rtlCount}/${pageCount})`);
}

requireAll("lib/screens/behavior/add_point_screen.dart", [
  "final Set<String> _selectedReasonIds",
  "اختر واحدًا أو أكثر",
  "for (final student in _selectedStudents)",
  "for (final reason in reasons)",
  "await _db.insertBehaviorPoints(points)",
]);
requireAll("lib/services/database_service.dart", [
  "Future<void> insertBehaviorPoints(List<BehaviorPoint> points)",
  "await db.transaction((txn) async",
]);
requireAll("lib/screens/behavior/behavior_screen.dart", [
  "_searchQuery",
  "بحث عن طالب",
  "visualDensity: VisualDensity.compact",
]);

requireAll("lib/screens/attendance/attendance_screen.dart", [
  "Future<void> _clearPresentAttendance",
  "attendance: 'unmarked'",
  "value == 'present' && isSelected",
]);

requireAll("lib/models/student.dart", ["reviewPlanType", "talaqqinEnabled"]);
requireAll("lib/models/plan.dart", ["reviewUnit"]);
requireAll("lib/screens/students/student_form_screen.dart", [
  "وحدة المراجعة",
  "الطالب في مرحلة التلقين",
]);
requireAll("lib/services/student_learning_policy.dart", [
  "canReceiveTalaqqin",
  "student.talaqqinEnabled",
]);
requireAll("lib/screens/memorization/talaqqin_screen.dart", [
  "_finishTalaqqinStage",
  "إنهاء مرحلة التلقين",
  "talaqqinEnabled: false",
]);

requireAll("lib/services/database_service.dart", [
  "Future<void> deleteExam(String examId)",
  "deleted_exam_ids",
  "getStudentExamsInRange",
]);
requireAll("lib/screens/exam/exams_screen.dart", [
  "طباعة النتيجة",
  "حذف الامتحان",
  "_confirmDeleteExam",
]);
requireAll("lib/models/student_period_report.dart", ["final List<Exam> exams"]);
requireAll("lib/screens/reports/student_period_report_screen.dart", [
  "اختبارات الفترة",
  "📝 *اختبارات الفترة*",
  "Helpers.getDayName(day.date)",
]);

requireAll("lib/widgets/surah_picker.dart", [
  "ScrollController",
  "_centerOnCurrentSurah",
  "selectedSurahId",
  "jumpTo",
]);
requireAll("lib/screens/memorization/add_memorization_screen.dart", [
  "_getNextMemorizationStartingPoint",
  "selectedSurahId: _selectedSurahId",
]);
requireAll("lib/screens/exam/add_exam_screen.dart", [
  "memorizationDirection == 'desc'",
  "? surahs.first",
  ": surahs.last",
]);
requireAll("lib/screens/exam/exam_generator_screen.dart", [
  "memorizationDirection == 'desc'",
  "? surahs.first",
  ": surahs.last",
]);

for (const path of [
  "lib/models/quran_course.dart",
  "lib/screens/courses/quran_courses_screen.dart",
  "website/supabase/migrations/20260808000200_p1_24_courses_learning_units.sql",
  "website/supabase/verify_p1_24.sql",
  "docs/P1.24_IMPLEMENTATION_LOG.md",
  "docs/P1.24_QURAN_COURSES_RESEARCH.md",
  "docs/P1.24_SQL_AND_SETUP.md",
]) requireFile(path);
requireAll("lib/models/quran_course.dart", [
  "class QuranCourse",
  "memorizationUnit",
  "revisionUnit",
  "studyWeekdays",
  "class QuranCourseEnrollment",
]);
requireAll("lib/screens/home/home_screen.dart", [
  "QuranCoursesScreen",
  "دورات الحفظ والمراجعة",
]);
requireAll("lib/services/supabase_service.dart", ["_syncQuranCourses"]);

requireAll("lib/services/recitation_points_policy.dart", [
  "final rawReward = safeCompletionReward * ratio",
  "double proportionalReward = switch (roundingMode)",
  "completionPoints: proportionalReward",
  "bonusPoints: completed && exceeded ? safeExtraReward",
  "workloadPoints: 0",
]);
requireAll("lib/services/daily_excellence_service.dart", [
  "ayah.lines <= 0 ? 0.5 : ayah.lines",
  "_fractionalGroupAmount",
  "byPage: true",
  "byPage: false",
]);
requireAll("lib/services/memorization_measure_service.dart", [
  "ayah.lines <= 0 ? 0.5 : ayah.lines",
]);
requireAll("test/recitation_points_policy_test.dart", [
  "awards proportional points for partial completion",
  "full completion awards the full completion reward",
  "extra reward is added only after exceeding the plan",
]);
requireAll("test/daily_excellence_service_test.dart", [
  "uses a safe line estimate when source line metadata is missing",
]);
requireAll("test/memorization_measure_service_test.dart", [
  "line plans do not collapse when source line metadata is zero",
]);

requireAll("lib/models/student_hold.dart", ["fullPause = 'full_pause'"]);
requireAll("lib/screens/reports/student_period_report_screen.dart", [
  "🗓️ *تفصيل الأيام*",
  "Helpers.getDayName(day.date)",
]);

const migration = requireAll(
  "website/supabase/migrations/20260808000200_p1_24_courses_learning_units.sql",
  [
    "ADD COLUMN IF NOT EXISTS review_plan_type",
    "ADD COLUMN IF NOT EXISTS talaqqin_enabled",
    "ADD COLUMN IF NOT EXISTS review_unit",
    "CREATE TABLE IF NOT EXISTS public.quran_courses",
    "CREATE TABLE IF NOT EXISTS public.quran_course_enrollments",
    "ENABLE ROW LEVEL SECURITY",
  ],
);
if (/\bDROP\s+TABLE\b|\bTRUNCATE\b/i.test(migration)) {
  throw new Error("P1.24 migration contains a destructive table operation");
}
requireAll("website/supabase/verify_p1_24.sql", [
  "students_review_unit",
  "students_talaqqin_stage",
  "plans_review_unit",
  "quran_courses",
  "quran_course_enrollments",
  "courses_rls",
  "enrollments_rls",
  "courses_policy",
  "enrollments_policy",
]);

console.log("P1.24 contracts remain protected under P1.25: restored colors, static-Arabic RTL PDFs, learning units, exams, courses, attendance undo, behavior multi-reasons, and points contracts.");
