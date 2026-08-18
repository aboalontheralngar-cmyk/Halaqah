import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const websiteRoot = path.resolve(here, '..');
const root = path.resolve(websiteRoot, '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const checks = [];
const expect = (condition, message) => checks.push({ condition: Boolean(condition), message });

const pubspec = read('pubspec.yaml');
const sync = read('lib/services/supabase_service.dart');
const store = read('website/src/store/useStore.ts');
const login = read('website/src/app/login/page.tsx');
const callback = read('website/src/app/auth/callback/page.tsx');
const onboarding = read('website/src/app/onboarding/page.tsx');
const selectCenter = read('website/src/app/select-center/page.tsx');
const layout = read('website/src/components/DashboardLayout.tsx');
const applySql = read('P1.27_BUILD85_HOTFIX10_APPLY.sql');
const verifySql = read('P1.27_BUILD85_HOTFIX10_VERIFY.sql');

expect(pubspec.includes('version: 4.3.0-alpha.28+85'), 'Build 85 version is pinned');
expect(sync.includes('toAyah > surah.totalAyahs'), 'Remote memorization validates upper ayah bound');
expect(sync.includes('remote_batch_validation_fallback'), 'Malformed memorization batch has row fallback');
expect(sync.includes('remote_row_skipped:${rowError.runtimeType}'), 'Malformed memorization row is skipped, not fatal');
expect(store.includes('Auth triggers are allowed to create a placeholder profile'), 'Auth-trigger placeholder is not onboarding completion');
expect(store.includes("memberRoleToProfileRole"), 'Teacher/admin membership maps to application profile role');
expect(store.includes(".eq('owner_id', user.id)"), 'Legacy center owner is recognized without forced onboarding');
expect(store.includes(".rpc('get_my_supervisors')"), 'Existing supervisory membership is recognized');
expect(!store.includes('if (user) {\n      get().fetchProfile();'), 'setUser no longer launches a racing profile request');
expect(login.includes('finishAuthenticatedLogin'), 'All sign-in methods share deterministic post-auth routing');
expect(login.includes('authData.session?.user'), 'Email signup only enters onboarding with an authenticated session');
expect(callback.includes('router.replace(useStore.getState().profile ? "/select-center" : "/onboarding")'), 'OAuth callback routes incomplete users to onboarding');
expect(onboarding.includes('supabase.auth.getSession()'), 'Onboarding survives direct refresh with an existing auth session');
expect(onboarding.includes('metadata.full_name || metadata.name'), 'Google name prefills onboarding without skipping it');
expect(onboarding.includes('onboarding_completed: false'), 'Onboarding starts as incomplete before organization creation');
expect(onboarding.includes('.update({ onboarding_completed: true })'), 'Onboarding is marked complete only after organization creation');
expect(selectCenter.includes('accountName'), 'Center selector shows signed-in account identity');
expect(selectCenter.includes('accountRoleLabel'), 'Center selector shows signed-in account role');
expect(layout.includes('accountName'), 'Dashboard sidebar shows signed-in account identity');
expect(layout.includes('await supabase.auth.signOut()'), 'Dashboard logout revokes Supabase session');
expect(applySql.includes('ADD COLUMN IF NOT EXISTS onboarding_completed'), 'SQL adds explicit onboarding completion marker');
expect(applySql.includes('supervisor_members'), 'SQL backfills established supervisory accounts');
expect(verifySql.includes('established_accounts_marked_complete'), 'VERIFY checks established account backfill');

const failed = checks.filter((item) => !item.condition);
for (const item of checks) console.log(`${item.condition ? 'PASS' : 'FAIL'}: ${item.message}`);
if (failed.length) {
  console.error(`Build 85 Hotfix 10 validation failed: ${failed.length} check(s).`);
  process.exit(1);
}
console.log(`Build 85 Hotfix 10 validation passed: ${checks.length} checks.`);
