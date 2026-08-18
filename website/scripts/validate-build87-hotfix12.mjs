import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const exists = (relative) => fs.existsSync(path.join(root, relative));
const checks = [];
const expect = (condition, message) => checks.push({ condition: Boolean(condition), message });

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const recitation = read('lib/screens/memorization/memorization_screen.dart');
const swipe = read('lib/widgets/deliberate_swipe_action_card.dart');
const portalClient = read('website/src/lib/studentPortal.ts');
const portalProxy = read('website/src/app/api/student-portal/route.ts');
const portalEdge = read('website/supabase/functions/student-portal/index.ts');
const portalPage = read('website/src/app/portal/page.tsx');
const globals = read('website/src/app/globals.css');
const points = read('website/src/app/points/page.tsx');
const supervision = read('website/src/services/supervisionService.ts');
const applySql = read('P1.27_BUILD87_HOTFIX12_APPLY.sql');
const verifySql = read('P1.27_BUILD87_HOTFIX12_VERIFY.sql');
const releaseNotes = read('docs/release_notes.md');

expect(pubspec.includes('version: 4.3.0-alpha.30+87'), 'pubspec is Build 87');
expect(buildInfo.includes("versionName = '4.3.0-alpha.30'") && buildInfo.includes('buildNumber = 87'), 'AppBuildInfo is Build 87');
expect(!pubspec.includes('flutter_slidable'), 'flutter_slidable dependency removed');
expect(!recitation.includes('package:flutter_slidable'), 'recitation no longer imports flutter_slidable');
expect(recitation.includes('DeliberateSwipeActionCard('), 'passive deliberate swipe card is used');
expect(swipe.includes('Listener(') && swipe.includes('_directionRatio = 2.2') && swipe.includes('triggerDistance = 104'), 'swipe intent strongly favors vertical scrolling safety');
expect(exists('test/deliberate_swipe_action_card_test.dart'), 'gesture regression test exists');
expect(recitation.includes("value: 'memorization'") && recitation.includes("value: 'revision'") && recitation.includes("value: 'talaqqin'"), 'overflow menu includes memorization/revision/talaqqin');
expect(recitation.includes("value: 'session'") && recitation.includes("value: 'view'") && recitation.includes("value: 'history'"), 'overflow menu includes remaining recitation tools');
expect(recitation.includes("label: const Text('تسجيل حفظ')") && recitation.includes("label: const Text('تسجيل مراجعة')") && recitation.includes("label: const Text('تسجيل تلقين')"), 'expandable quick FAB exposes three recording actions');
expect(portalClient.includes("fetch('/api/student-portal'"), 'browser portal uses same-origin proxy');
expect(portalProxy.includes('/functions/v1/student-portal') && portalProxy.includes('15_000'), 'Next proxy forwards to Edge Function with bounded timeout');
expect(portalProxy.includes('export async function GET') && portalProxy.includes('{ action: "health" }'), 'same-origin portal readiness endpoint exists');
expect(portalProxy.includes('X-Forwarded-For') && portalProxy.includes('User-Agent'), 'proxy preserves client fingerprint inputs');
expect(portalEdge.includes("| 'health'"), 'portal Edge Function supports health action');
expect(portalEdge.includes('student_portal_runtime_health'), 'portal Edge Function checks runtime SQL contract');
expect(portalEdge.includes('portal_database_error') && portalEdge.includes('reference: errorCode'), 'portal database failures expose privacy-safe diagnostic reference');
expect(globals.includes('@custom-variant dark (&:where(.dark, .dark *));'), 'Tailwind v4 dark variants follow app dark class');
expect(portalPage.includes('toggleDarkMode') && portalPage.includes('bg-[var(--background)]'), 'standalone portal has class-driven light/dark theme');
expect(points.includes('maximumFractionDigits: 2') && points.includes('formatPoints(student.totalPoints)'), 'web point totals render at maximum two decimals');
expect(supervision.includes('crypto_search_path') && !supervision.includes('message.toLowerCase().includes("function")'), 'supervision does not misclassify dependency function errors');
expect(applySql.includes('SET search_path TO public, extensions, pg_temp'), 'Build 87 repairs pgcrypto search paths');
expect(applySql.includes('student_portal_runtime_health') && applySql.includes("NOTIFY pgrst, 'reload schema'"), 'Build 87 installs runtime health and reloads PostgREST');
expect(verifySql.includes('invitation_pgcrypto_search_path') && verifySql.includes('portal_pgcrypto_search_path'), 'Build 87 VERIFY covers portal and invitation search paths');
expect(exists('website/supabase/migrations/20260818000100_build87_portal_supervision_hardening.sql') && exists('website/supabase/verification/20260818000100_build87_portal_supervision_readiness.sql'), 'Build 87 is preserved in migration/readiness directories');
expect(exists('tools/deploy_student_portal.ps1'), 'repeatable portal Edge deployment helper exists');
expect(releaseNotes.startsWith('# Build 87 Hotfix 12'), 'release notes document Build 87 first');
expect(exists('docs/P1.27_BUILD87_HOTFIX12_PORTAL_RECITATION.md'), 'Build 87 detailed documentation exists');
expect(exists('P1.27_BUILD87_HOTFIX12_INSTALL_NOTE.md'), 'Build 87 install note exists');

const failed = checks.filter((item) => !item.condition);
for (const item of checks) console.log(`${item.condition ? 'PASS' : 'FAIL'}: ${item.message}`);
if (failed.length) {
  console.error(`Build 87 Hotfix 12 validation failed: ${failed.length} check(s).`);
  process.exit(1);
}
console.log(`Build 87 Hotfix 12 validation passed: ${checks.length}/${checks.length} checks.`);
