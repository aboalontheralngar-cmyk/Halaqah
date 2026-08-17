import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const websiteRoot = path.resolve(here, '..');
const root = path.resolve(websiteRoot, '..');

const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const checks = [];
const expect = (condition, message) => {
  checks.push({ condition: Boolean(condition), message });
};

const pubspec = read('pubspec.yaml');
const schema = read('lib/services/local_database_schema.dart');
const db = read('lib/services/database_service.dart');
const sync = read('lib/services/supabase_service.dart');
const notificationPolicy = read('lib/services/sync/cloud_notification_type_policy.dart');
const login = read('website/src/app/login/page.tsx');
const supabaseClient = read('website/src/lib/supabase.ts');
const callback = read('website/src/app/auth/callback/page.tsx');
const appUrl = read('website/src/lib/appUrl.ts');
const envExample = read('website/.env.example');
const applySql = read('P1.27_BUILD83_HOTFIX8_APPLY.sql');
const verifySql = read('P1.27_BUILD83_HOTFIX8_VERIFY.sql');

expect(pubspec.includes('version: 4.3.0-alpha.26+83'), 'Build 83 version is pinned');
expect(schema.includes('static const int version = 27;'), 'SQLite schema is version 27');
expect(schema.includes('CREATE TABLE IF NOT EXISTS sync_dirty_stages'), 'Dirty-stage journal exists');
expect(schema.includes('AFTER $event ON $safeTable'), 'Dirty-stage triggers are installed');
expect(db.includes('getSyncDirtyStageGeneration'), 'Dirty generation can be read');
expect(db.includes('acknowledgeSyncDirtyStage'), 'Dirty generation is acknowledged safely');
expect(sync.includes("stage_skipped_clean"), 'Upload-only sync skips clean domains');
expect(sync.includes("notification_type_compatibility_fallback"), 'Notification type compatibility fallback exists');
expect(sync.includes("error.code == '23514'"), 'Notification CHECK violation is handled explicitly');
expect(notificationPolicy.includes("'surah_completed'"), 'Surah completion notification type is supported');
expect(notificationPolicy.includes("'consecutive_no_recitation'"), 'No-recitation notification type is supported');
expect(notificationPolicy.includes("'student_expelled'"), 'Student-expelled notification type is supported');
expect(supabaseClient.includes("flowType: 'pkce'"), 'Web OAuth uses PKCE');
expect(supabaseClient.includes('detectSessionInUrl: false'), 'Implicit token-fragment parsing is disabled');
expect(login.includes('redirectTo: oauthCallbackUrl()'), 'Google OAuth targets the dedicated callback');
expect(callback.includes('exchangeCodeForSession(code)'), 'OAuth callback exchanges the PKCE code');
expect(appUrl.includes('NEXT_PUBLIC_APP_URL'), 'Production application origin is configurable');
expect(envExample.includes('NEXT_PUBLIC_APP_URL=https://YOUR_PUBLIC_APP_DOMAIN'), 'Production app URL is documented');
for (const type of ['surah_completed', 'consecutive_no_recitation', 'student_expelled']) {
  expect(applySql.includes(`'${type}'::text`), `Cloud notification CHECK allows ${type}`);
  expect(verifySql.includes(type), `VERIFY checks ${type}`);
}

const failed = checks.filter((item) => !item.condition);
for (const item of checks) {
  console.log(`${item.condition ? 'PASS' : 'FAIL'}: ${item.message}`);
}
if (failed.length > 0) {
  console.error(`Build 83 Hotfix 8 validation failed: ${failed.length} check(s).`);
  process.exit(1);
}
console.log(`Build 83 Hotfix 8 validation passed: ${checks.length} checks.`);
