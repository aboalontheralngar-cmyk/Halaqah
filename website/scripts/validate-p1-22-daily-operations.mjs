import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (path, fragments) => {
  let source = read(path);
  if (path === "lib/services/database_service.dart") {
    source += read("lib/services/local_database_schema.dart");
  }
  if (path === "lib/services/supabase_service.dart") {
    source += read("lib/services/cloud_config.dart");
  }
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`P1.22 missing ${fragment} in ${path}`);
    }
  }
  return source;
};
const requireFile = (path) => {
  if (!existsSync(resolve(root, path))) {
    throw new Error(`P1.22 missing required file: ${path}`);
  }
};

requireAll("pubspec.yaml", ["version: 4.3.0-alpha.24+80"]);
requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.24'",
  "buildNumber = 80",
  "releaseLabel = 'P1.27'",
]);
requireAll("lib/services/database_service.dart", [
  "static const int version = 26",
  "_upgradeToVersion22",
  "activity_type",
  "recitation_exempt",
  "talaqqin_records",
  "student_admin_actions",
  "insertBehaviorPoints",
  "await QuranService.instance.initialize()",
]);

requireAll("lib/screens/reports/student_period_report_screen.dart", [
  "../../models/daily_record.dart",
  "تفصيل الأيام",
  "Helpers.getDayName(day.date)",
  "معفى من التسميع",
]);
requireAll("lib/models/daily_record.dart", [
  "class DailyActivityType",
  "محاضرة",
  "دوري",
  "عشاء",
  "رياضة",
  "مسابقة ثقافية",
  "recitationExempt",
  "talaqqinDone",
]);
const attendanceSource = requireAll("lib/screens/attendance/attendance_screen.dart", [
  "_showActivityDialog",
  "activityType",
  "recitationExempt: true",
  "exemptsAttendance",
]);
const suspensionStart = attendanceSource.indexOf("Future<void> _toggleSuspension()");
const suspensionEnd = attendanceSource.indexOf("Future<Map<String, dynamic>?> _showSuspensionDialog", suspensionStart);
const suspensionBlock = attendanceSource.slice(suspensionStart, suspensionEnd);
if (suspensionBlock.includes("delete('daily_records'") || suspensionBlock.includes('delete("daily_records"')) {
  throw new Error("P1.22 suspension must preserve manual daily_records");
}
requireAll("lib/models/student_hold.dart", [
  "full_pause",
  "exemptsAttendance",
  "exemptsRecitation",
]);
requireAll("lib/screens/students/student_detail_screen.dart", [
  "دراسة",
  "عمل",
  "StudentHoldScope.fullPause",
  "إداريات",
  "StudentAdminActionType",
]);
requireAll("lib/screens/behavior/add_point_screen.dart", [
  "_selectedStudentIds",
  "insertBehaviorPoints(points)",
]);
requireAll("lib/screens/memorization/memorization_screen.dart", [
  "ReorderableListView.builder",
  "recitation_manual_order",
  "TalaqqinScreen",
  "التلقين",
]);
requireAll("lib/screens/memorization/talaqqin_screen.dart", [
  "saveTalaqqinSession",
  "QuranCrossSurahRangeService.between",
  "RecitationAttendanceGuard",
]);
requireAll("lib/services/daily_closing_service.dart", [
  "hasAttendanceExemptHold",
  "DailyClosingState.activity",
  "DailyClosingState.talaqqin",
  "ارجع عبر سلسلة",
]);
requireAll("lib/screens/settings/settings_screen.dart", [
  "موازنة نقاط السلوك",
  "ModelHalaqahScreen",
]);
requireAll("lib/screens/settings/model_halaqah_screen.dart", [
  "model_halaqah_evaluation_",
  "تقييم الحلقة النموذجية",
]);
requireAll("lib/services/mandatory_revision_schedule_service.dart", [
  "class MandatoryRevisionScheduleService",
  "totalDays",
  "selectedPages",
]);
requireAll("lib/screens/memorization/revision_screen.dart", [
  "await _quran.initialize()",
  "MandatoryRevisionScheduleService.chunkForDay",
  "mandatoryFromPage",
]);
requireAll("lib/services/quran_cross_surah_range_service.dart", [
  "static QuranCrossSurahRange? between",
  "startSurahId",
  "endSurahId",
]);
requireAll("lib/screens/memorization/add_memorization_screen.dart", [
  "تحديد النهاية في سورة أخرى",
  "QuranCrossSurahRangeService.between",
]);
requireAll("lib/screens/memorization/recitation_screen.dart", [
  "تحديد «إلى» في سورة أخرى",
  "RecitationAttendanceGuard",
]);
requireAll("lib/services/recitation_attendance_guard.dart", [
  "الطالب مسجل غائبًا",
  "الطالب مسجل مستأذنًا",
  "هل تود تحويله إلى حاضر؟",
  "attendance != 'absent' && attendance != 'excused'",
  "نعم، تحضيره",
]);

requireAll("lib/services/supabase_service.dart", [
  "signInWithGoogle",
  "OAuthProvider.google",
  "halaqah://login-callback",
  "hasActivityFields",
  "hasTalaqqinFields",
  "_syncTalaqqinRecords",
  "_syncStudentAdminActions",
]);
requireAll("lib/screens/auth/login_screen.dart", ["المتابعة باستخدام Google"]);
requireAll("website/src/app/login/page.tsx", [
  'provider: "google"',
  "المتابعة باستخدام Google",
]);
requireAll("android/app/src/main/AndroidManifest.xml", [
  'android:scheme="halaqah"',
  'android:host="login-callback"',
]);
requireAll("ios/Runner/Info.plist", [
  "CFBundleURLTypes",
  "halaqah",
  "NSCameraUsageDescription",
]);

const migrationPath =
  "website/supabase/migrations/20260808000100_p1_22_activity_talaqqin_admin.sql";
const migration = requireAll(migrationPath, [
  "CREATE TABLE IF NOT EXISTS public.student_holds",
  "ADD COLUMN IF NOT EXISTS activity_type",
  "recitation_exempt",
  "talaqqin_records",
  "student_admin_actions",
  "full_pause",
  "ENABLE ROW LEVEL SECURITY",
  "close_daily_operations",
  "COMMIT;",
]);
if (/\b(DROP TABLE|TRUNCATE)\b/i.test(migration)) {
  throw new Error("P1.22 migration contains a destructive table operation");
}
if (migration.indexOf("CREATE TABLE IF NOT EXISTS public.student_holds") > migration.indexOf("ALTER TABLE public.student_holds")) {
  throw new Error("P1.22 migration must bootstrap student_holds before altering it");
}
requireAll("website/supabase/verify_p1_22.sql", [
  "activity_type",
  "closing_respects_activity_exemption",
  "closing_respects_full_pause",
]);

for (const path of [
  "test/mandatory_revision_schedule_service_test.dart",
  "test/quran_cross_surah_range_service_test.dart",
  "test/daily_closing_service_test.dart",
  "test/student_hold_test.dart",
  "docs/P1.22_IMPLEMENTATION_LOG.md",
  "docs/P1.22_SQL_AND_GOOGLE_SETUP.md",
]) {
  requireFile(path);
}

console.log(
  "P1.22 passed: daily activities, pauses, talaqqin, multi-student behavior, connected recitation, review scheduling, Google OAuth, and cloud-migration compatibility contracts are protected.",
);
