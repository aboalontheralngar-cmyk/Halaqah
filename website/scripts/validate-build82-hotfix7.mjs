import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 82 Hotfix 7 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const constants = read('lib/utils/constants.dart');
assert(pubspec.includes('version: 4.3.0-alpha.25+82'), 'pubspec must use versionCode 82');
assert(buildInfo.includes("versionName = '4.3.0-alpha.25'"), 'version name must be alpha.25');
assert(buildInfo.includes('buildNumber = 82'), 'AppBuildInfo must use build 82');
assert(constants.includes("appVersion = '4.3.0-alpha.25'"), 'AppConstants version must match Build 82');

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  "..remove('id')",
  ".upsert(businessRows, onConflict: 'student_id,date')",
  'uq_attendance_student_date',
]) {
  assert(sync.includes(token), `attendance 23505 repair missing: ${token}`);
}

const portalLib = read('website/src/lib/studentPortal.ts');
for (const token of [
  'formatPortalAccessCodeInput',
  "const prefix = kind === 'family' ? 'FAM' : 'HAL'",
  'body.match(/.{1,5}/g)',
  "portal_not_deployed",
]) {
  assert(portalLib.includes(token), `portal client repair missing: ${token}`);
}

const portalPage = read('website/src/app/portal/page.tsx');
assert(
  portalPage.includes('setAccessCode(formatPortalAccessCodeInput(event.target.value, loginMode))'),
  'portal input must auto-format access codes',
);
for (const token of ['portal_not_deployed', 'portal_contract_missing', 'PORTAL']) {
  if (token === 'PORTAL') continue;
  assert(portalPage.includes(token), `portal error mapping missing: ${token}`);
}

const edge = read('website/supabase/functions/student-portal/index.ts');
for (const token of ["'PGRST202'", "'PGRST205'", "'42883'", "'42P01'", "portal_contract_missing"]) {
  assert(edge.includes(token), `Edge Function contract diagnostic missing: ${token}`);
}

const login = read('website/src/app/login/page.tsx');
for (const token of [
  'googleAuthErrorMessage',
  'provider is not enabled',
  'Google Provider',
  'المتابعة باستخدام Google',
]) {
  assert(login.includes(token), `Google auth repair missing: ${token}`);
}
assert(!login.includes('{isLogin && (\n              <>\n                <button\n                  type="button"\n                  onClick={handleGoogleLogin}'), 'Google button should not be login-only');

const supervision = read('website/src/services/supervisionService.ts');
for (const token of ['لا تعاود P7.3 القديمة', 'SUPERVISION_${reference}', 'direct_center_creation === false']) {
  assert(supervision.includes(token), `supervision diagnostic missing: ${token}`);
}

const store = read('website/src/store/useStore.ts');
assert(store.includes('Promise<{ success: boolean; error?: unknown }>'), 'joinSupervisor must preserve error details');
const settings = read('website/src/app/settings/page.tsx');
assert(settings.includes('supervisionErrorMessage(result.error, health)'), 'center link UI must surface classified supervision error');

const verifySql = read('P1.27_BUILD82_HOTFIX7_VERIFY.sql');
for (const token of [
  'attendance_business_key',
  'student_portal_rpcs',
  'at_least_one_active_student_pin',
  'p7_3_resulting_tables',
  'supervision_health_build76',
]) {
  assert(verifySql.includes(token), `Build 82 VERIFY missing: ${token}`);
}

const portalRepair = read('P1.27_BUILD82_HOTFIX7_PORTAL_REPAIR.sql');
assert(portalRepair.includes('CREATE EXTENSION IF NOT EXISTS pgcrypto'), 'portal repair must ensure pgcrypto exists');
assert(portalRepair.includes('CREATE OR REPLACE FUNCTION public.student_portal_authenticate'), 'portal repair must restore authenticate RPC');
assert(portalRepair.includes('GRANT EXECUTE ON FUNCTION public.student_portal_authenticate'), 'portal repair must restore service-role grant');
assert(!portalRepair.includes('CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa'), 'portal repair must not replace current shared scope helper');
assert(!portalRepair.includes('CREATE OR REPLACE FUNCTION public.current_user_is_center_admin'), 'portal repair must not replace current admin helper');

const readme = read('README.md');
assert(readme.includes('Build 82 Hotfix 7'), 'README must point to the current hotfix');
const releaseNotes = read('docs/release_notes.md');
assert(releaseNotes.includes('Build 82 Hotfix 7'), 'release notes must document Build 82 Hotfix 7');
const doc = read('docs/P1.27_BUILD82_HOTFIX7_PORTAL_AUTH_SYNC.md');
for (const token of ['SYNC_ATTENDANCE_23505', 'PORTAL_RATE_LIMIT_PEPPER', 'P7.3', 'Google']) {
  assert(doc.includes(token), `Hotfix 7 documentation missing: ${token}`);
}

console.log('Build 82 Hotfix 7 portal/auth/attendance validation passed.');
