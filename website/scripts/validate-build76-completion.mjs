import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const exists = (relative) => fs.existsSync(path.join(root, relative));
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 76 completion validation failed: ${message}`);
    process.exit(1);
  }
};

// Release identity / local migration.
assert(read("pubspec.yaml").includes("version: 4.3.0-alpha.24+80"), "pubspec is not Build 76");
const buildInfo = read("lib/app/build_info.dart");
assert(buildInfo.includes("versionName = '4.3.0-alpha.24'") && buildInfo.includes("buildNumber = 80"), "AppBuildInfo is not Build 76");
const schema = read("lib/services/local_database_schema.dart");
assert(schema.includes("static const int version = 26"), "SQLite v25 migration missing");
assert(schema.includes("CREATE TABLE IF NOT EXISTS sync_delete_outbox"), "local durable delete outbox missing");
for (const table of [
  "family_guardians", "homework_grades", "memorization_progress", "behavior_points", "daily_achievements", "vacations", "fund_transactions",
  "notifications", "student_holds", "talaqqin_records", "student_admin_actions",
  "quran_course_enrollments", "plan_recitation_records", "exams", "exam_templates",
  "plans", "quran_courses", "families", "students",
]) {
  assert(schema.includes(`('${table}',`), `delete outbox trigger mapping missing: ${table}`);
}
assert(schema.includes("localTable: 'daily_records'") && schema.includes("remoteTable: 'attendance'"), "attendance composite delete mapping missing");
assert(schema.includes("localTable: 'mushaf_progress'") && schema.includes("thumun_number"), "mushaf progress composite delete mapping missing");

// Telegram-like behavior: cloud deletes first, local durable deletes next, then normal upserts.
const sync = read("lib/services/supabase_service.dart");
const synchronize = sync.slice(sync.indexOf("Future<CloudSyncResult> synchronizeData"), sync.indexOf("Future<void> _syncFamilies"));
assert(synchronize.indexOf("_syncCloudTombstones") >= 0, "remote tombstones not downloaded");
assert(synchronize.indexOf("_syncDeleteOutbox") >= 0, "local delete outbox not uploaded");
assert(synchronize.indexOf("_syncCloudTombstones") < synchronize.indexOf("_syncDeleteOutbox"), "remote deletes must be applied before outbound deletes");
assert(synchronize.indexOf("_syncDeleteOutbox") < synchronize.indexOf("_syncStudents"), "delete intent must be flushed before regular upserts");
assert(sync.includes("delete_student_for_sync"), "student delete is not guarded by atomic cloud RPC");
const tombstoneReplay = read("lib/services/cloud_tombstone_local_service.dart");
assert(tombstoneReplay.includes("sync_remote_delete_replay") && tombstoneReplay.includes("case 'mushaf_progress'"), "cloud delete replay guard/coverage missing");
const autoSync = read("lib/services/cloud_auto_sync_coordinator.dart");
assert(autoSync.includes("_networkRetryTimer") && autoSync.includes("_scheduleNetworkRetry") && autoSync.includes("_retryWhenNetworkReturns") && autoSync.includes("authStateChanges"), "adaptive network-return/auth automatic retry missing");
assert(read("lib/services/diagnostic_center_service.dart").includes("'حذف بانتظار المزامنة': 'sync_delete_outbox'"), "pending delete outbox is not visible in diagnostics");

// Supervision drill-down.
const supervisionService = read("website/src/services/supervisionService.ts");
const detailPage = read("website/src/app/supervision/centers/[id]/page.tsx");
assert(supervisionService.includes("fetchSupervisionCenterDetail") && supervisionService.includes("get_supervision_center_detail"), "center detail RPC client missing");
for (const token of ["الحلقات", "أداء الطلاب", "attendance_rate", "new_ayahs", "review_ayahs", "points_balance"]) {
  assert(detailPage.includes(token), `supervision drill-down UI missing ${token}`);
}
assert(read("website/src/app/supervision/page.tsx").includes("/supervision/centers/"), "supervision center cards do not link to drill-down");

// Peer competition weekly ranking, not just grouping.
const peerService = read("lib/services/peer_level_grouping_service.dart");
const peerScreen = read("lib/screens/competition/peer_level_groups_screen.dart");
for (const token of ["weeklyNewAyahs", "weeklyReviewAyahs", "weeklyBehaviorPoints", "weeklyRanking", "weeklyScore"]) {
  assert(peerService.includes(token), `peer weekly competition metric missing: ${token}`);
}
assert(peerScreen.includes("الترتيب الأسبوعي") && peerScreen.includes("LinearProgressIndicator"), "peer weekly ranking UI missing");
assert(read("test/peer_level_grouping_service_test.dart").includes("weekly ranking"), "peer weekly competition test missing");

// Structured monthly exam linkage + cross-device sync.
const monthlyScreen = read("lib/screens/exam/monthly_plan_exam_screen.dart");
assert(monthlyScreen.includes("ExamTemplate(") && monthlyScreen.includes("ExamTemplateQuestion(") && monthlyScreen.includes("templateId: template.id"), "monthly exam is not linked to template/questions");
const monthlyPersistence = read("lib/services/monthly_exam_persistence_service.dart");
assert(monthlyScreen.includes("_persistence.save(") && monthlyPersistence.includes("database.transaction") && monthlyPersistence.includes("exam_template_questions"), "monthly exam bundle is not persisted atomically");
assert(read("lib/models/exam.dart").includes("final String? templateId"), "local exam template reference missing");
assert(schema.includes("template_id TEXT"), "SQLite exam template_id column missing");
assert(sync.includes("_syncExamTemplates(centerId, halaqahId, direction)") && sync.includes("remoteQuestions") && sync.includes("saveExamTemplate(template, questions)"), "exam templates/questions are not bidirectional");

// Contrast and incident diagnostics.
const theme = read("lib/app/theme.dart");
assert(theme.includes("selectedColor: scheme.secondaryContainer") && theme.includes("onSecondaryContainer"), "selected control contrast tokens missing");
for (const file of [
  "lib/screens/memorization/memorization_screen.dart",
  "lib/screens/memorization/memorization_plan_screen.dart",
  "lib/screens/competition/competition_judge_screen.dart",
  "lib/screens/students/student_detail_screen.dart",
]) {
  const source = read(file);
  assert(source.includes("labelColor: Theme.of(context).colorScheme.onPrimary") && source.includes("indicatorColor: Theme.of(context).colorScheme.secondary"), `AppBar TabBar contrast missing in ${file}`);
}
const themeTest = read("test/theme_contrast_test.dart");
for (const token of ["primary", "secondaryContainer", "errorContainer", "semantic.success", "semantic.warning", "semantic.info"]) {
  assert(themeTest.includes(token), `theme contrast test missing ${token}`);
}
const main = read("lib/main.dart");
const incidents = read("lib/services/operational_incident_service.dart");
assert(main.includes("error_widget.$source") && main.includes("operation: 'render'"), "ErrorWidget context/operation capture missing");
assert(incidents.includes("String? operation") && incidents.includes("'operation': safeOperation"), "incident operation metadata missing");
assert(read("lib/screens/settings/diagnostics_screen.dart").includes("incident.operation"), "diagnostics screen does not expose operation metadata");

// Proportional point rounding policy is configurable and tested.
const settings = read("lib/models/settings.dart");
const points = read("lib/services/recitation_points_policy.dart");
assert(settings.includes("recitationPointsRounding") && settings.includes("recitation_points_rounding"), "rounding setting missing");
assert(points.includes("roundingMode") && points.includes("'floor' =>") && points.includes("'ceil' =>"), "rounding policy options missing");
assert(read("lib/screens/settings/settings_screen.dart").includes("تقريب نقاط إنجاز المقرر"), "rounding selector UI missing");
assert(read("test/recitation_points_policy_test.dart").includes("floor") && read("test/recitation_points_policy_test.dart").includes("ceil"), "rounding behavior tests missing");

// SQL completion contract + user-runnable artifacts.
const sql = read("website/supabase/migrations/20260814000100_build76_p127_completion.sql");
for (const token of [
  "FUNCTION public.delete_student_for_sync",
  "FUNCTION public.get_supervision_center_detail",
  "build76-2026-08-14",
  "capture_sync_tombstone_after_delete",
  "mushaf_progress",
  "SET search_path = public, pg_temp",
]) {
  assert(sql.includes(token), `Build76 SQL contract missing ${token}`);
}
for (const file of [
  "website/supabase/P1.27_BUILD76_APPLY.sql",
  "website/supabase/P1.27_BUILD76_VERIFY.sql",
]) {
  assert(exists(file), `Build76 SQL artifact missing ${file}`);
}

assert(sql.includes("scoped_record_id := coalesce(payload ->> 'student_id'") && sql.includes("payload ->> 'thumun_number'"), "mushaf tombstone ledger key is not composite");
assert(read("lib/screens/settings/whats_new_screen.dart").includes("P1.27 Build 76"), "What's New missing Build76");
console.log("Build 76 / P1.27 completion validation passed.");
