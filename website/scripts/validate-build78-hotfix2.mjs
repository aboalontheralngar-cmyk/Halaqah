import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 78 Hotfix 2 validation failed: ${message}`);
    process.exit(1);
  }
};

const pdf = read('lib/services/pdf_service.dart');
const printPolicy = read('lib/services/smart_plan_print_policy.dart');
assert(
  pdf.includes('SmartPlanPrintPolicy.validateExactAssignments('),
  'PDF generation must use the dedicated smart-plan print policy',
);
for (const token of [
  'if (assignment.isCatchupDay)',
  'if (!recitationIsExact)',
  "_hasExactQuranRange(assignment.recitationRange)",
]) {
  assert(printPolicy.includes(token), `plan print regression token missing: ${token}`);
}

const plansScreen = read('lib/screens/plans/plans_screen.dart');
assert(
  plansScreen.includes("replaceFirst(RegExp(r'^Bad state:\\s*'), '')"),
  'plan printing must hide the raw Dart Bad state prefix from the user',
);

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  'Future<CloudSyncResult>? _activeSync;',
  'bool get isSynchronizing => _activeSync != null;',
  '_syncDirectionCovers',
  'StudySuspensionSyncPlan.create(',
  '_fetchRemoteStudySuspensions(',
  'pendingDeletedDates',
]) {
  assert(sync.includes(token), `sync regression token missing: ${token}`);
}
assert(
  !sync.includes('for (final entry in localSuspensions.entries) {\n          await _callIdempotentSyncRpc'),
  'study suspension sync must not replay every local date blindly',
);

const diff = read('lib/services/study_suspension_sync_plan.dart');
assert(diff.includes('if (remoteReason != localReason)'), 'suspension diff must compare reasons');
assert(diff.includes('if (local.containsKey(date)) continue;'), 're-added suspension must win over stale delete marker');

const printTest = read('test/smart_plan_print_policy_test.dart');
assert(printTest.includes('Friday catch-up row prints'), 'Friday print regression test missing');
const diffTest = read('test/study_suspension_sync_plan_test.dart');
assert(diffTest.includes('unchanged historical suspensions produce no RPC work'), 'sync diff regression test missing');

const install = read('P1.27_BUILD78_HOTFIX2_INSTALL_NOTE.md');
assert(install.includes('no-font-binaries'), 'install note must call out missing font binaries');
assert(install.includes('verify_source_prerequisites.ps1'), 'install note must run source prerequisite check');

const apply = read('website/supabase/P1.27_BUILD78_APPLY.sql');
const migration = read('website/supabase/migrations/20260815000100_build78_reports_plans_supervisor_competitions.sql');
assert(apply === migration, 'Hotfix 2 must not alter Build78 SQL');

console.log('Build 78 Hotfix 2 printing and sync regression validation passed.');
