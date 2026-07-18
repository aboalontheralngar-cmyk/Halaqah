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

const migration = read('website/supabase/migrations/20260714000400_p7_student_portal_security.sql');
requireAll(migration, [
  'student_portal_credentials',
  'SET search_path = public, extensions, pg_temp',
  "crypt(p_pin, gen_salt('bf', 12))",
  'student_portal_sessions',
  "digest(raw_token, 'sha256')",
  'student_portal_login_attempts',
  "interval '15 minutes'",
  'student_portal_authenticate',
  'student_portal_get_dashboard',
  'student_portal_revoke_session',
  'TO service_role',
  'FROM PUBLIC, anon, authenticated',
], 'Portal security migration');

const edgeFunction = read('website/supabase/functions/student-portal/index.ts');
requireAll(edgeFunction, [
  "Deno.env.get('SUPABASE_SECRET_KEYS')",
  "Deno.env.get('PORTAL_RATE_LIMIT_PEPPER')",
  'readClientIp(request)',
  "action === 'login'",
  "action === 'dashboard'",
  "action === 'logout'",
  "'Cache-Control': 'no-store'",
], 'Portal Edge Function');

const portalClient = read('website/src/lib/studentPortal.ts');
requireAll(portalClient, [
  '/functions/v1/student-portal',
  "cache: 'no-store'",
  "action: 'login'",
  "action: 'dashboard'",
], 'Portal browser client');
if (/SERVICE_ROLE|SECRET_KEY/.test(portalClient)) {
  throw new Error('Portal browser client must not reference privileged server keys.');
}

const portalPage = read('website/src/app/portal/page.tsx');
requireAll(portalPage, [
  'sessionStorage',
  'بوابة الطالب وولي الأمر',
  'حفظ PDF',
  'recent_memorization',
  'recent_attendance',
  'ar-SA-u-ca-islamic',
], 'Portal page');
if (portalPage.includes('localStorage.setItem(SESSION_KEY')) {
  throw new Error('Portal session must remain tab-scoped, not persistent localStorage.');
}

requireAll(read('lib/services/supabase_service.dart'), [
  'getStudentPortalStatus',
  'setStudentPortalPin',
  'disableStudentPortal',
], 'Android portal management');

requireAll(read('lib/screens/students/student_detail_screen.dart'), [
  '_showPortalAccessDialog',
  'بوابة الطالب وولي الأمر',
  'FilteringTextInputFormatter.digitsOnly',
], 'Android student portal UI');

console.log('P7.2 student portal contract passed: PIN hashing, rate limiting, short sessions, read-only dashboard, and teacher controls.');
