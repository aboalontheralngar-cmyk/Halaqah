import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 78 Hotfix 3 validation failed: ${message}`);
    process.exit(1);
  }
};

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  'ValueNotifier<CloudSyncProgress?> syncProgress',
  'Future<void> _runSyncStage({',
  "'last_cloud_sync_failed_stage'",
  "'last_cloud_sync_error_code'",
  "'last_cloud_sync_failed_at'",
  "await client.from('mushaf_progress').upsert(chunk);",
  "await client.from('daily_achievements').upsert(payload);",
  '_studentIdsByHalaqah',
  '_identityRefreshTtl = Duration(hours: 6)',
]) {
  assert(sync.includes(token), `sync hardening token missing: ${token}`);
}
assert(
  !sync.includes("onConflict: 'student_id,hizb_number,thumun_number'"),
  'mobile mushaf upload must not depend on a composite conflict target',
);
assert(
  !sync.includes("onConflict: 'student_id,date'"),
  'mobile upload must use stable primary keys rather than composite conflict targets',
);

const coordinator = read('lib/services/cloud_auto_sync_coordinator.dart');
for (const token of [
  "import 'sync/adaptive_retry_policy.dart';",
  'final AdaptiveRetryPolicy _retryPolicy',
  'void _scheduleNetworkRetry()',
  '_periodicTimer = Timer.periodic(',
  'retryInterval = Duration(minutes: 5)',
]) {
  assert(coordinator.includes(token), `auto-sync efficiency token missing: ${token}`);
}
assert(!coordinator.includes('_networkProbeTimer'), 'always-running network probe timer must be removed');
assert(!coordinator.includes('networkProbeInterval'), 'fixed 12-second network probe cadence must be removed');

const progressWidget = read('lib/widgets/cloud_sync_progress_dialog.dart');
assert(progressWidget.includes('ValueListenableBuilder<CloudSyncProgress?>'), 'shared sync progress widget is missing live progress');
const home = read('lib/screens/home/home_screen.dart');
const settings = read('lib/screens/settings/settings_screen.dart');
assert(home.includes('CloudSyncProgressDialog('), 'Home must use the shared sync progress dialog');
assert(settings.includes('CloudSyncProgressDialog('), 'Settings must use the shared sync progress dialog');

const diagnostics = read('lib/services/diagnostic_center_service.dart');
for (const token of [
  'lastCloudSyncFailedStage',
  'lastCloudSyncErrorCode',
  'lastCloudSyncFailedAt',
]) {
  assert(diagnostics.includes(token), `diagnostic sync marker missing: ${token}`);
}

const apply = read('website/supabase/P1.27_BUILD78_HOTFIX3_APPLY.sql');
for (const token of [
  'HAVING count(*) > 1',
  'uq_mushaf_progress_student_hizb_thumun',
  'uq_attendance_student_date',
  'uq_daily_achievements_student_date',
  'uq_exam_scores_exam_student',
  'uq_quran_course_enrollments_course_student',
  'ix_sync_study_suspensions_center_halaqa_date',
]) {
  assert(apply.includes(token), `Hotfix 3 APPLY token missing: ${token}`);
}
assert(!/DELETE\s+FROM/i.test(apply), 'Hotfix 3 APPLY must never delete user rows');

const verify = read('website/supabase/P1.27_BUILD78_HOTFIX3_VERIFY.sql');
const migration = read('website/supabase/migrations/20260816000100_build78_hotfix3_sync_integrity.sql');
const verification = read('website/supabase/verification/20260816000100_build78_hotfix3_sync_integrity_readiness.sql');
assert(apply === migration, 'Hotfix 3 APPLY and migration copy must stay identical');
assert(verify === verification, 'Hotfix 3 VERIFY and verification copy must stay identical');
for (const token of [
  'set_study_suspension',
  'get_sync_tombstones',
  'delete_student_for_sync',
  'uq_mushaf_progress_student_hizb_thumun',
  'uq_exam_scores_exam_student',
]) {
  assert(verify.includes(token), `Hotfix 3 VERIFY token missing: ${token}`);
}

const retryTest = read('test/adaptive_retry_policy_test.dart');
const progressTest = read('test/cloud_sync_progress_test.dart');
assert(retryTest.includes('backs off exponentially'), 'adaptive retry regression test missing');
assert(progressTest.includes('privacy-safe code'), 'sync progress privacy regression test missing');

const docsIndex = read('docs/INDEX.md');
assert(docsIndex.includes('P1.27_BUILD78_HOTFIX3'), 'documentation index must point to Hotfix 3');
const releaseNotes = read('docs/release_notes.md');
assert(releaseNotes.includes('Build 78 Hotfix 3'), 'release notes must document Hotfix 3');

console.log('Build 78 Hotfix 3 cloud-sync, schema, diagnostics, and efficiency validation passed.');
