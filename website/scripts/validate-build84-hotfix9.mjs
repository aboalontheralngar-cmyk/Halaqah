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
const schema = read('lib/services/local_database_schema.dart');
const db = read('lib/services/database_service.dart');
const sync = read('lib/services/supabase_service.dart');
const range = read('lib/services/quran_cross_surah_range_service.dart');
const revision = read('lib/screens/memorization/revision_screen.dart');
const points = read('lib/services/recitation_points_policy.dart');
const reportModel = read('lib/models/student_period_report.dart');
const reportService = read('lib/services/student_period_report_service.dart');
const pdf = read('lib/services/pdf_service.dart');
const callback = read('website/src/app/auth/callback/page.tsx');
const login = read('website/src/app/login/page.tsx');
const dashboardLayout = read('website/src/components/DashboardLayout.tsx');
const homepage = read('website/src/app/page.tsx');
const supervision = read('website/src/services/supervisionService.ts');
const applySql = read('P1.27_BUILD84_HOTFIX9_APPLY.sql');
const verifySql = read('P1.27_BUILD84_HOTFIX9_VERIFY.sql');

expect(pubspec.includes('version: 4.3.0-alpha.27+84'), 'Build 84 version is pinned');
expect(schema.includes('static const int version = 28;'), 'SQLite schema is version 28');
expect(schema.includes("sync_remote_write_replay"), 'Dirty triggers ignore cloud replay writes');
expect(db.includes('runAsCloudReplay'), 'Cloud pull writes can be replay guarded');
expect(sync.includes("client.rpc(\n        'get_halaqah_sync_watermarks'"), 'One cloud watermark RPC exists');
expect(sync.includes('stage_skipped_no_delta'), 'Unchanged bidirectional domains are skipped');
expect(sync.includes('remoteMaxId != null && remoteMaxId <= cursor'), 'Tombstones skip when remote id did not advance');
expect(sync.includes("getDailyRecordsUpdatedSince"), 'Attendance upload is incremental');
expect(sync.includes("getHomeworkGradesUpdatedSince"), 'Homework upload is incremental');
expect(sync.includes("getMemorizationProgressUpdatedSince"), 'Memorization upload is incremental');
expect(sync.includes("_cloudPullSince('memorization'"), 'Memorization pull is cursor-based');
expect(sync.includes('getAllExamTemplateQuestions'), 'Exam-template questions are batched');
expect(!sync.includes('Future<void> _ensureCloudReachable()'), 'Redundant per-sync reachability probe is removed');

expect(applySql.includes('CREATE OR REPLACE FUNCTION public.get_halaqah_sync_watermarks'), 'SQL creates watermark RPC');
expect(applySql.includes('CREATE OR REPLACE FUNCTION public.halaqah_touch_updated_at'), 'SQL installs authoritative updated_at trigger');
expect(applySql.includes('idx_sync_tombstones_center_id'), 'SQL indexes tombstone max-id scan');
expect(applySql.includes('idx_attendance_sync_scope_updated'), 'SQL indexes attendance delta scan');
expect(applySql.includes('idx_memorization_sync_scope_updated'), 'SQL indexes memorization delta scan');
expect(applySql.includes('idx_mushaf_sync_center_updated'), 'SQL indexes mushaf watermark scan');
expect(applySql.includes('CREATE OR REPLACE FUNCTION public.create_supervisor_organization'), 'SQL repairs supervisory onboarding RPC');
expect(applySql.includes("NOTIFY pgrst, 'reload schema'"), 'SQL refreshes PostgREST schema cache');
expect(verifySql.includes('watermarks_rpc'), 'VERIFY checks watermark RPC');
expect(verifySql.includes('create_supervisor_organization_rpc'), 'VERIFY checks supervisory creation RPC');

expect(callback.includes('exchangeCodeForSession(code)'), 'OAuth callback exchanges PKCE code');
expect(callback.includes('useStore.setState({ user: data.session.user })'), 'OAuth callback hydrates authenticated user before routing');
expect(callback.includes('await useStore.getState().fetchProfile()'), 'OAuth callback waits for profile lookup');
expect(login.includes('redirectTo: oauthCallbackUrl()'), 'Google OAuth uses dedicated callback URL');
expect(dashboardLayout.includes('pathname.startsWith("/auth/")'), 'OAuth callback route is public to dashboard guard');
expect(dashboardLayout.includes('hasOAuthReturnCode'), 'Site-URL OAuth fallback code is public to dashboard guard');
expect(homepage.includes('new URL("/auth/callback", window.location.origin)'), 'Root fallback forwards OAuth code to callback');
expect(supervision.includes('create_supervisor_organization'), 'Website uses current supervisory create RPC');
expect(supervision.includes('get_my_supervisors'), 'Partial supervisory onboarding can resume');

expect(range.includes('static QuranCrossSurahRange? between'), 'Connected Quran range service exists');
expect(range.includes('allowedRanges'), 'Connected range respects memorized boundaries');
expect(revision.includes('_showConnectedRevisionRange'), 'Revision UI exposes connected range picker');
expect(revision.includes("tooltip: 'مراجعة متصلة من سورة إلى سورة'"), 'Revision range action is discoverable');
expect(!revision.includes('setSheetState(() {\n                          setSheetState(() {'), 'Revision bottom sheet has no duplicate state callback');

expect(points.includes('defaultBonusStepPercent = 25'), 'Extra reward uses 25 percent steps');
expect(points.includes('defaultMaxBonusTiers = 4'), 'Extra reward is capped at four tiers');
expect(points.includes('(safeExtraReward * bonusTier).toDouble()'), 'Bonus reward scales by tier');
expect(db.includes('bonusStep=$bonusStepPercent;maxBonusTiers=$maxBonusTiers'), 'Automatic point snapshot records tier policy');

expect(reportModel.includes('exceededMemorizationPlan'), 'Report model detects above-target days');
expect(reportModel.includes('khatmRemainingPercent'), 'Report model exposes remaining khatm percent');
expect(reportService.includes('studentMemorizedAyahs: student.totalMemorized'), 'Report uses stored total memorized ayahs');
expect(pdf.includes("★ زيادة"), 'PDF marks excess days');
expect(pdf.includes("'متبقي للختم'"), 'PDF renders khatm remaining indicator');

const failed = checks.filter((item) => !item.condition);
for (const item of checks) console.log(`${item.condition ? 'PASS' : 'FAIL'}: ${item.message}`);
if (failed.length) {
  console.error(`Build 84 Hotfix 9 validation failed: ${failed.length} check(s).`);
  process.exit(1);
}
console.log(`Build 84 Hotfix 9 validation passed: ${checks.length} checks.`);
