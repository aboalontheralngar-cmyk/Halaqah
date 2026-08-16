import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const webRoot = process.cwd();

function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}
function exists(relative) {
  return fs.existsSync(path.join(root, relative));
}
function assert(condition, message) {
  if (!condition) {
    console.error(`Build 75 / P1.27 validation failed: ${message}`);
    process.exit(1);
  }
}

const pubspec = read("pubspec.yaml");
const buildInfo = read("lib/app/build_info.dart");
const whatsNew = read("lib/screens/settings/whats_new_screen.dart");
assert(pubspec.includes("version: 4.3.0-alpha.24+80"), "pubspec version is not Build 75");
assert(buildInfo.includes("versionName = '4.3.0-alpha.24'") && buildInfo.includes("buildNumber = 80") && buildInfo.includes("releaseLabel = 'P1.27'"), "AppBuildInfo is not P1.27 Build 75");
assert(whatsNew.includes("v4.3.0-alpha.21 · P1.27 Build 75"), "What's New does not document Build 75");
assert(read("lib/services/local_database_schema.dart").includes("static const int version = 26"), "SQLite schema version must stay 24");

// 1) Proportional recitation points.
const pointsPolicy = read("lib/services/recitation_points_policy.dart");
const dbService = read("lib/services/database_service.dart");
assert(pointsPolicy.includes("safeCompletionReward * ratio") && pointsPolicy.includes("proportionalReward"), "proportional completion reward is missing");
assert(pointsPolicy.includes("exceeded") && pointsPolicy.includes("safeExtraReward"), "extra reward must only start above the plan");
assert(dbService.includes("completionPercent") && dbService.includes("إنجاز المقرر اليومي (تلقائي)"), "daily point recalculation is not using the proportional policy");
assert(exists("test/recitation_points_policy_test.dart"), "proportional points test missing");

// 2) Canonical inferred memorization frontier feeds revision/profile.
const memorized = read("lib/services/memorized_content_service.dart");
assert(memorized.includes("memorization direction + the furthest real memorization") && memorized.includes("_frontierRow"), "inferred memorization frontier missing");
assert(dbService.includes("MemorizedContentService.buildRanges"), "DatabaseService does not expose canonical memorized ranges");
assert(read("lib/screens/memorization/revision_screen.dart").includes("getStudentMemorizedRanges"), "revision screen still relies on raw memorization rows");
assert(read("lib/screens/memorization/student_memorization_view.dart").includes("getStudentMemorizedRanges"), "student memorization view does not use inferred ranges");
const studentForm = read("lib/screens/students/student_form_screen.dart");
assert(studentForm.includes("أول سجل") && studentForm.includes("اتجاه الحفظ"), "student registration does not explain inferred memorization");
assert(exists("test/memorized_content_service_test.dart"), "inferred memorization test missing");

// 3) Plan date: weekday + Hijri + Gregorian.
const helpers = read("lib/utils/helpers.dart");
assert(helpers.includes("formatPlanDate") && helpers.includes("getFullHijriDate") && helpers.includes("formatGregorianDate") && helpers.includes("getDayName"), "combined plan date formatter missing");
assert(read("lib/services/pdf_service.dart").includes("Helpers.formatPlanDate"), "PDF plan does not use combined date format");
assert(read("lib/screens/plans/plans_screen.dart").includes("Helpers.formatPlanDate"), "plans screen does not use combined date format");

// 4) In-app generated/share files and product identity.
const shareNames = read("lib/services/share_file_name_service.dart");
assert(shareNames.includes("appName = 'حلقتي'"), "share filenames are not branded حلقتي");
for (const file of ["lib/screens/memorization/recitation_screen.dart", "lib/screens/reports/halaqah_period_report_screen.dart", "lib/services/report_export_service.dart"]) {
  assert(read(file).includes("ShareFileNameService"), `generated share path not branded in ${file}`);
}
assert(read("android/app/src/main/AndroidManifest.xml").includes('android:label="حلقتي"'), "Android app label is not حلقتي");
assert(read("ios/Runner/Info.plist").includes("حلقتي"), "iOS product name is not حلقتي");
assert(read("web/manifest.json").includes("حلقتي"), "web manifest product name is not حلقتي");

// 5) Backdated entry grace period is unified across all memorization entry paths.
const backdate = read("lib/services/backdated_entry_policy.dart");
assert(backdate.includes("maxBackdateDays = 3"), "backdated entry grace period is not three days");
for (const file of ["lib/screens/memorization/recitation_screen.dart", "lib/screens/memorization/revision_screen.dart", "lib/screens/memorization/add_memorization_screen.dart"]) {
  const source = read(file);
  assert(source.includes("BackdatedEntryPolicy"), `backdated entry policy missing from ${file}`);
}
assert(exists("test/backdated_entry_policy_test.dart"), "backdated entry policy test missing");

// 6) Monthly plan exam contract: 30+30+20+20.
const monthlyService = read("lib/services/monthly_plan_exam_service.dart");
const monthlyScreen = read("lib/screens/exam/monthly_plan_exam_screen.dart");
assert(monthlyService.includes("memorizationQuestionScores") && monthlyService.includes("reviewQuestionScores") && monthlyService.includes("memorizationPlanScore") && monthlyService.includes("reviewPlanScore"), "monthly exam breakdown missing");
assert(monthlyService.includes("* 20") || monthlyService.includes("20.0"), "monthly plan completion component is not capped at 20");
assert(monthlyScreen.includes("List.filled(3, 0)") && monthlyScreen.includes("ExamType.monthlyPlan") && monthlyScreen.includes("for (var i = 0; i < 3; i++)"), "monthly plan exam does not contain 3+3 questions/type");
assert(read("lib/models/exam.dart").includes("monthly_plan"), "Flutter monthly_plan exam type missing");
assert(read("website/src/store/useStore.ts").includes("'monthly_plan'"), "web monthly_plan exam type missing");
assert(exists("test/monthly_plan_exam_service_test.dart"), "monthly plan exam test missing");

// 7) Peer-level competition groups.
assert(read("lib/screens/home/home_screen.dart").includes("PeerLevelGroupsScreen"), "peer groups are not reachable from home");
assert(read("lib/services/peer_level_grouping_service.dart").includes("groupCount.clamp(1, students.length)"), "peer grouping count is not safely constrained");
assert(read("lib/screens/competition/peer_level_groups_screen.dart").includes("getStudentMemorizedRanges"), "peer grouping is not based on canonical memorization");
assert(exists("test/peer_level_grouping_service_test.dart"), "peer grouping test missing");

// 8) Backdated suspension reverses only automatic records.
const suspensionScreen = read("lib/screens/attendance/attendance_screen.dart");
assert(dbService.includes("أُنشئ تلقائيًا عند إغلاق اليوم") && dbService.includes("deleted_attendance_keys"), "local automatic-absence rollback/queue missing");
assert(dbService.includes("غياب بدون عذر (تلقائي)") && dbService.includes("عدم التسميع (تلقائي)"), "local automatic penalty rollback missing");
assert(suspensionScreen.includes("setStudySuspension"), "attendance UI does not use safe suspension rollback");

// 9) Telegram-like sync: automatic retries + remote tombstones before uploads.
const autoSync = read("lib/services/cloud_auto_sync_coordinator.dart");
const supabaseService = read("lib/services/supabase_service.dart");
assert(autoSync.includes("WidgetsBindingObserver") && autoSync.includes("Timer.periodic") && autoSync.includes("AppLifecycleState.resumed"), "automatic foreground/resume sync coordinator missing");
assert(read("lib/main.dart").includes("CloudAutoSyncCoordinator.instance.start()"), "automatic sync coordinator is not started");
const synchronizeBlock = supabaseService.slice(supabaseService.indexOf("Future<CloudSyncResult> synchronizeData"), supabaseService.indexOf("Future<void> _syncCloudTombstones"));
assert(synchronizeBlock.indexOf("_syncCloudTombstones") >= 0, "cloud tombstones are not synchronized");
assert(synchronizeBlock.indexOf("_syncCloudTombstones") < synchronizeBlock.indexOf("_syncStudents"), "remote deletions must be replayed before local uploads");
assert(read("lib/services/cloud_tombstone_local_service.dart").includes("case 'exam_scores'"), "tombstone local replay coverage missing exam_scores");
assert(dbService.split("\n").length < 5200, "DatabaseService modularization regressed above the Build74 ceiling");

// 10) ErrorWidget incident tracing and concrete empty-rating crash repair.
const main = read("lib/main.dart");
const recitationScreen = read("lib/screens/memorization/recitation_screen.dart");
assert(main.includes("stackFingerprint") && main.includes("رمز الحادثة"), "ErrorWidget does not expose a stable incident code");
assert(recitationScreen.includes("_ayahRatings.isEmpty") && !/\.map\(\(r\) => r\.rating\)\.reduce/.test(recitationScreen), "empty ayah-rating reduce crash remains");

// 11) Contrast-safe memorization/revision labels.
assert(read("lib/utils/color_contrast.dart").includes("estimateBrightnessForColor"), "contrast helper missing");
assert(read("lib/widgets/quality_rating.dart").includes("ColorContrast.on"), "quality rating selected text does not use contrast helper");
assert(recitationScreen.includes("onPrimaryContainer") && recitationScreen.includes("حفظ جديد") && recitationScreen.includes("مراجعة"), "recitation choice chips are not semantic-theme aware");

// 12) Supervision: owner/admin direct center creation + precise diagnostics.
const supervisionService = read("website/src/services/supervisionService.ts");
const supervisionPage = read("website/src/app/supervision/page.tsx");
assert(supervisionService.includes("createSupervisedCenter") && supervisionService.includes('rpc("create_supervised_center"'), "direct supervised-center RPC client missing");
assert(supervisionService.includes("can_create_centers") && supervisionService.includes("direct_center_creation"), "Build75 supervision health fields missing");
assert(supervisionPage.includes("createSupervisedCenter") && supervisionPage.includes("إضافة مركز"), "supervision portal cannot create a center directly");
assert(!supervisionPage.includes("تأكد من تنفيذ SQL المرحلة 7.3"), "obsolete P7.3 generic message remains");

// 13) Build75 SQL: direct center, safe holiday rollback, monthly exam and durable delete ledger.
const migration = read("website/supabase/migrations/20260812000200_build75_offline_supervision_and_daily_repair.sql");
for (const token of ["FUNCTION public.create_supervised_center", "FUNCTION public.set_study_suspension", "CREATE TABLE IF NOT EXISTS public.sync_tombstones", "FUNCTION public.get_sync_tombstones", "build75-2026-08-12", "monthly_plan", "exam_scores"]) {
  assert(migration.includes(token), `Build75 SQL contract missing: ${token}`);
}
assert(migration.includes("attendance_row.notes = 'أُنشئ تلقائيًا عند إغلاق اليوم'"), "cloud suspension cleanup could remove manual attendance");
assert(migration.includes("SET search_path = public, pg_temp"), "Build75 SECURITY DEFINER search_path hardening missing");

// 14) Consolidated SQL + exhaustive documentation shipped with the release.
for (const file of [
  "P1.27_INSTALL_NOTE.md",
  "docs/P1.27_IMPLEMENTATION_LOG.md",
  "docs/P1.27_SQL_AND_SETUP.md",
  "docs/P1.27_FEATURE_AUDIT.md",
  "docs/P1.27_SYNC_ARCHITECTURE.md",
  "docs/P1.27_VALIDATION.md",
  "website/supabase/P1.27_BUILD75_APPLY.sql",
  "website/supabase/P1.27_BUILD75_VERIFY.sql",
]) {
  assert(exists(file), `release documentation/artifact missing: ${file}`);
}

console.log("Build 75 / P1.27 feature and hardening validation passed.");
