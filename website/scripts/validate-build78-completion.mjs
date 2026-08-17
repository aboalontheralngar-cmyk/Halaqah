import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const exists = (relative) => fs.existsSync(path.join(root, relative));
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 78 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const schema = read('lib/services/local_database_schema.dart');
const pubspecBuild = Number(pubspec.match(/version:\s+4\.3\.0-alpha\.24\+(\d+)/)?.[1] ?? 0);
const appBuild = Number(buildInfo.match(/buildNumber\s*=\s*(\d+)/)?.[1] ?? 0);
assert(pubspecBuild >= 78, 'pubspec is older than Build 78');
assert(buildInfo.includes("versionName = '4.3.0-alpha.26'") && appBuild >= 78, 'AppBuildInfo is older than Build 78');
assert(schema.includes('static const int version = 27'), 'SQLite schema is not v26');
for (const dependency of [
  'supabase_flutter: 2.14.2',
  'printing: 5.14.3',
  'share_plus: 10.0.3',
  'pdf: 3.12.0',
]) {
  assert(pubspec.includes(dependency), `known-good dependency changed: ${dependency}`);
}

// Dual calendar + Friday policy.
assert(exists('lib/widgets/dual_calendar_date_picker.dart'), 'dual calendar picker is missing');
const calendar = read('lib/widgets/dual_calendar_date_picker.dart');
assert(calendar.includes('_CalendarMode.hijri') && calendar.includes('HijriCalendar.fromDate') && calendar.includes('SingleChildScrollView'), 'Hijri picker is incomplete or not small-screen safe');
for (const file of [
  'lib/screens/plans/plans_screen.dart',
  'lib/screens/reports/reports_screen.dart',
  'lib/screens/reports/student_period_report_screen.dart',
]) {
  assert(read(file).includes('showDualCalendarDateRangePicker'), `dual calendar not wired in ${file}`);
}
const plan = read('lib/models/plan.dart');
const schedule = read('lib/services/smart_plan_schedule_service.dart');
assert(plan.includes('final String fridayMode') && plan.includes("this.fridayMode = 'catchup_recitation'"), 'plan Friday mode missing');
assert(schema.includes("friday_mode TEXT NOT NULL DEFAULT 'catchup_recitation'"), 'SQLite Friday mode missing');
assert(schedule.includes('calendarDay.catchupOnly') && schedule.includes('الجمعة: تدارك الفائت + سرد تلاوة'), 'Friday catch-up/sard behavior missing');

// Attendance conflict + revision proposal flexibility.
const guard = read('lib/services/recitation_attendance_guard.dart');
assert(guard.includes("attendance != 'absent' && attendance != 'excused'") && guard.includes('الطالب مسجل مستأذنًا'), 'excused recitation conflict guard missing');
const revision = read('lib/screens/memorization/revision_screen.dart');
assert(revision.includes('مقترح الخطة') || revision.includes('مقترح:'), 'revision plan proposal marker missing');
assert(!revision.includes('onChanged: isMandatory ? null'), 'revision proposal remains locked');

// Legacy memorization reconciliation.
assert(exists('lib/services/legacy_memorized_reconciliation_service.dart'), 'legacy memorization reconciliation service missing');
const reconciliation = read('lib/services/legacy_memorized_reconciliation_service.dart');
const main = read('lib/main.dart');
assert(reconciliation.includes('reconcileAllOnce') && reconciliation.includes('initializeMushafProgressForRange') && reconciliation.includes('memorizationDirection'), 'legacy memorization reconciliation contract incomplete');
assert(main.includes('startup.legacy_memorized_reconciliation') && main.includes('Duration(seconds: 2)'), 'legacy reconciliation is not deferred after startup');

// Reports: batch exclusion, payment transparency, page breakdown, one-page summary.
const reports = read('lib/screens/reports/reports_screen.dart');
assert(reports.includes('استثناء طلاب من ملف PDF') && reports.includes('استبعاد المستجدين في الفترة') && reports.includes('excludedStudentIds'), 'batch PDF exclusion workflow missing');
const studentReportModel = read('lib/models/student_period_report.dart');
const studentReportService = read('lib/services/student_period_report_service.dart');
const studentReportScreen = read('lib/screens/reports/student_period_report_screen.dart');
const halaqahReportModel = read('lib/models/halaqah_period_report.dart');
const pdf = read('lib/services/pdf_service.dart');
for (const token of ['memorizedPages', 'revisedPages', 'recitedPages', 'totalCompletedPages', 'paidAmount']) {
  assert(studentReportModel.includes(token), `student report metric missing: ${token}`);
  assert(halaqahReportModel.includes(token) || token === 'totalCompletedPages', `halaqah report metric missing: ${token}`);
}
assert(studentReportService.includes('fundTransactions') && studentReportService.includes('recitationRecords'), 'report service does not load payments/sard records');
assert(studentReportScreen.includes('مدفوعات الطالب خلال الفترة') && studentReportScreen.includes('_buildPayments'), 'payment transparency is missing from report UI');
for (const token of ['_addStudentPeriodSummaryPage', '_addStudentPeriodReportPages', '_studentPeriodReportContent', 'صفحات حفظ', 'صفحات مراجعة', 'صفحات سرد', 'مدفوعات الطالب خلال الفترة']) {
  assert(pdf.includes(token), `student PDF contract missing ${token}`);
}
assert(pdf.includes('compactSummary') && pdf.includes('pw.Page('), 'compact one-page student summary missing');

// True fractional points and cloud column compatibility.
const pointModel = read('lib/models/behavior_point.dart');
const pointPolicy = read('lib/services/recitation_points_policy.dart');
const settingsModel = read('lib/models/settings.dart');
const sync = read('lib/services/supabase_service.dart');
assert(pointModel.includes('final double points') && pointModel.includes('points.toDouble()'), 'BehaviorPoint does not preserve decimals');
assert(pointPolicy.includes("roundingMode = 'exact'") && pointPolicy.includes('(rawReward * 100).roundToDouble() / 100'), 'exact proportional reward missing');
assert(settingsModel.includes("recitationPointsRounding = 'exact'"), 'exact point mode is not the default');
assert(sync.includes("(row['amount'] as num?)?.toDouble()"), 'cloud point amount is still truncated to int');

// Peer groups are actionable, persistent, and restricted to group members.
const peer = read('lib/screens/competition/peer_level_groups_screen.dart');
const judge = read('lib/screens/competition/competition_judge_screen.dart');
for (const token of ['generatePeerGroupRoster', 'إضافة فعالية خاصة', 'بدء مسابقة لهذه المجموعة', 'competition_allowed_student_ids_']) {
  assert(peer.includes(token), `peer group action missing: ${token}`);
}
assert(judge.includes('allowedStudentIds') && judge.includes('competition_allowed_student_ids_'), 'group competition member restriction is not persisted');
assert(pdf.includes('generatePeerGroupRoster'), 'peer group roster PDF missing');

// ErrorWidget must not recreate the observed 413px overflow.
assert(main.includes('SingleChildScrollView(') && main.includes('fontSize: 15') && main.includes('fontSize: 11.5') && main.includes('maxWidth: 360'), 'ErrorWidget small-screen protection missing');
const fund = read('lib/screens/fund/fund_screen.dart');
assert(fund.includes('تم تحديث المعاملة المالية') && fund.includes('catch (error'), 'fund edit failure handling missing');

// Supervisory competition schema, RLS, guarded writes, and UI.
for (const file of [
  'website/supabase/P1.27_BUILD78_APPLY.sql',
  'website/supabase/P1.27_BUILD78_VERIFY.sql',
  'website/supabase/migrations/20260815000100_build78_reports_plans_supervisor_competitions.sql',
  'website/src/app/supervision/competitions/page.tsx',
]) {
  assert(exists(file), `Build78 artifact missing: ${file}`);
}
const sql = read('website/supabase/P1.27_BUILD78_APPLY.sql');
const migration = read('website/supabase/migrations/20260815000100_build78_reports_plans_supervisor_competitions.sql');
assert(sql === migration, 'Build78 APPLY differs from migration source');
for (const token of [
  'ALTER COLUMN amount TYPE NUMERIC(10,2)',
  'supervisor_competitions',
  'supervisor_competition_categories',
  'supervisor_competition_entries',
  'supervisor_competition_scores',
  'submit_supervisor_competition_entry',
  'score_supervisor_competition_entry',
  'SET search_path = public, pg_temp',
]) {
  assert(sql.includes(token), `Build78 SQL missing ${token}`);
}
assert(!sql.includes('ALTER COLUMN points TYPE NUMERIC'), 'Build78 SQL targets wrong cloud points column');
const competitionPage = read('website/src/app/supervision/competitions/page.tsx');
for (const token of ['إرسال الترشيح للجهة', 'بدء التحكيم', 'نشر النتائج', 'obviousErrors', 'tajweedErrors']) {
  assert(competitionPage.includes(token), `supervisory competition UI missing ${token}`);
}
assert(read('website/src/app/supervision/page.tsx').includes('/supervision/competitions'), 'supervision page has no competitions entry');

assert(read('lib/screens/settings/whats_new_screen.dart').includes('P1.27 Build 78'), "What's New missing Build78");
console.log('Build 78 completion, reports, groups, plans, points, and supervision validation passed.');
