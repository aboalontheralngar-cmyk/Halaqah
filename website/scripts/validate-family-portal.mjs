import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const requireAll = (source, fragments, label) => {
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`${label} is missing: ${fragment}`);
    }
  }
};

const migration = read('website/supabase/migrations/20260714000600_p7_family_portal.sql');
requireAll(migration, [
  'family_code TEXT',
  "gen_random_bytes(10)",
  'SET search_path = public, extensions, pg_temp',
  'idx_families_family_code',
  'family_portal_credentials',
  "crypt(p_pin, gen_salt('bf', 12))",
  'family_portal_sessions',
  "digest(raw_token, 'sha256')",
  'family_portal_login_attempts',
  'family_portal_authenticate',
  'family_portal_get_dashboard',
  'p_student_id UUID DEFAULT NULL',
  'student.family_id = target_family.id',
  "student.status = 'active'",
  'build_student_portal_dashboard',
  'family_portal_revoke_session',
  'ALTER FUNCTION public.student_portal_authenticate(TEXT, TEXT, TEXT)',
  'TO service_role',
  'FROM PUBLIC, anon, authenticated',
], 'Family portal migration');

const edgeFunction = read('website/supabase/functions/student-portal/index.ts');
requireAll(edgeFunction, [
  "action === 'familyLogin'",
  "action === 'familyDashboard'",
  "action === 'familyLogout'",
  "admin.rpc('family_portal_authenticate'",
  "admin.rpc('family_portal_get_dashboard'",
  "'family_portal_revoke_session'",
], 'Family portal Edge Function');

const portalClient = read('website/src/lib/studentPortal.ts');
requireAll(portalClient, [
  'FamilyPortalDashboard',
  'loginToFamilyPortal',
  'loadFamilyPortalDashboard',
  'logoutFamilyPortal',
], 'Family portal browser client');

const portalPage = read('website/src/app/portal/page.tsx');
requireAll(portalPage, [
  'دخول ولي الأمر',
  'familyDashboard.selected_student_id',
  'handleStudentChange',
  'parseStoredSession',
  'حساب ولي الأمر',
], 'Family portal page');

const familyPage = read('website/src/app/parents/page.tsx');
requireAll(familyPage, [
  'get_family_portal_status',
  'set_family_portal_pin',
  'disable_family_portal',
  'generateSixDigitPin',
  'بوابة ولي الأمر',
], 'Web family access management');

requireAll(read('lib/services/database_service.dart'), [
  'version: 18',
  '_upgradeToVersion18',
  'family_code TEXT',
], 'Android local family identity migration');

requireAll(read('lib/services/supabase_service.dart'), [
  'getFamilyPortalStatus',
  'setFamilyPortalPin',
  'disableFamilyPortal',
], 'Android family portal service');

requireAll(read('lib/screens/students/families_screen.dart'), [
  '_managePortal',
  'Random.secure()',
  'بوابة ولي الأمر',
  'FilteringTextInputFormatter.digitsOnly',
], 'Android family portal UI');

requireAll(read('test/family_model_test.dart'), [
  'global cloud code',
  "family.toMap()['family_code']",
  'Family.fromMap(family.toMap()).familyCode',
], 'Android family code regression test');

console.log('P7.2.1 family portal contract passed: global family code, hashed PIN, isolated sessions, active-child switching, and teacher controls.');
