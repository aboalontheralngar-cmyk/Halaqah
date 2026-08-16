import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (file) => fs.readFileSync(path.join(root, file), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 77 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
assert(pubspec.includes('version: 4.3.0-alpha.24+80'), 'pubspec is not Build 77');
assert(buildInfo.includes("versionName = '4.3.0-alpha.24'") && buildInfo.includes('buildNumber = 80'), 'AppBuildInfo is not Build 77');

const home = read('lib/screens/home/home_screen.dart');
assert(home.includes("import '../competition/peer_level_groups_screen.dart';"), 'home does not import peer groups');
assert((home.match(/مجموعات المستوى المتقارب/g) ?? []).length >= 2, 'peer groups are not exposed in both home and drawer');
assert(home.includes('color: Theme.of(context).colorScheme.onPrimary'), 'sync icon does not explicitly contrast with AppBar');

const competitions = read('lib/screens/competition/competitions_screen.dart');
assert(!competitions.includes('peer_level_groups_screen.dart'), 'peer groups are still nested under competitions');

const grouping = read('lib/services/peer_level_grouping_service.dart');
assert(grouping.includes('String get quranRangeTitle'), 'Quran range group title is missing');
assert(grouping.includes('String get juzRangeLabel'), 'juz range label is missing');
assert(grouping.includes("return 'مجموعة سورة $firstName'"), 'single-surah group label is missing');
assert(grouping.includes("return 'نطاق الأجزاء $bandStart–$bandEnd'"), 'five-juz band label is missing');

const reportModel = read('lib/models/halaqah_period_report.dart');
const reportService = read('lib/services/halaqah_period_report_service.dart');
const reportScreen = read('lib/screens/reports/halaqah_period_report_screen.dart');
assert(reportModel.includes('rankingExcludedStudentIds') && reportModel.includes('!rankingExcludedStudentIds.contains'), 'ranking exclusions do not filter top students');
assert(reportService.includes('_rankingExclusionsKey(startDate, endDate)'), 'ranking exclusions are not scoped to the report period');
assert(reportScreen.includes('استبعاد المستجدين داخل الفترة'), 'new-student exclusion shortcut is missing');
assert(reportScreen.includes('استثناءات ترتيب الأوائل'), 'ranking exclusion UI is missing');
assert(reportScreen.includes('startDate: _startDate') && reportScreen.includes('endDate: _endDate'), 'ranking exclusion persistence is not period-scoped');

const pdf = read('lib/services/pdf_service.dart');
const aggregateStart = pdf.indexOf('Future<Uint8List> generateHalaqahPeriodReport');
const aggregateEnd = pdf.indexOf('pw.Widget _compactReportMetric', aggregateStart);
assert(aggregateStart >= 0 && aggregateEnd > aggregateStart, 'aggregate PDF function not found');
const aggregate = pdf.slice(aggregateStart, aggregateEnd);
assert(aggregate.includes('pw.Page('), 'aggregate PDF is not a fixed single page');
assert(!aggregate.includes('pw.MultiPage('), 'aggregate PDF still uses MultiPage');
assert(aggregate.includes('PdfPageFormat.a4.landscape'), 'aggregate PDF is not A4 landscape');
assert(aggregate.includes('pw.FittedBox(') && aggregate.includes('_buildAggregateStudentsTable(report)'), 'aggregate student table is not fitted into the page');
assert(pdf.includes("color: _pdfInk") && pdf.includes("'${item.student.name}${excluded ? '  • مستبعد من الأوائل' : ''}'"), 'aggregate PDF student names do not use explicit dark ink');

const reports = read('lib/screens/reports/reports_screen.dart');
assert(reports.includes('LayoutBuilder(') && reports.includes('التقرير التجميعي') && reports.includes('الحلقة كاملة مع الأوائل والاستثناءات'), 'reports hub redesign is missing');

const revision = read('lib/screens/memorization/revision_screen.dart');
assert(revision.includes("'مقترح: ${_suggestedSurahName!}'"), 'revision suggested surah chip is missing');
assert(revision.includes('if (a.id == _suggestedSurahId && b.id != _suggestedSurahId) return -1;'), 'suggested revision surah is not promoted in the index');

const fundDb = read('lib/services/fund_transaction_service.dart');
const fundScreen = read('lib/screens/fund/fund_screen.dart');
assert(fundDb.includes('class FundTransactionService') && fundDb.includes('Future<void> update('), 'fund transaction update service is missing');
assert(fundScreen.includes('_showEditTransactionDialog') && fundScreen.includes('تم تحديث المعاملة المالية'), 'fund edit UI is missing');

const attendance = read('lib/screens/attendance/attendance_screen.dart');
const raffle = read('lib/screens/students/student_raffle_screen.dart');
const settings = read('lib/screens/settings/settings_screen.dart');
const excellence = read('lib/screens/honor_board/daily_excellence_screen.dart');
assert(attendance.includes('isScrollControlled: true') && attendance.includes('maxHeight: MediaQuery.sizeOf(context).height * 0.82'), 'QR quick actions are not height constrained and scrollable');
assert(raffle.includes('SingleChildScrollView(') && raffle.includes("padding: const EdgeInsets.only(bottom: 12)"), 'raffle screen overflow protection is missing');
assert(settings.includes('Wrap(') && settings.includes('SingleChildScrollView('), 'point-rule dialog overflow protection is missing');
assert(excellence.includes('isExpanded: true') && excellence.includes('SingleChildScrollView('), 'daily excellence dialog overflow protection is missing');

const main = read('lib/main.dart');
const app = read('lib/app/app.dart');
assert(main.includes('await _initializeQuranWithRetry();'), 'Quran startup retry is missing');
assert(main.includes("source: 'startup.theme'") && main.includes('_runNonCriticalStartupTask'), 'theme startup is still fatal');
assert(app.includes("'إعادة المحاولة'") && app.includes('QuranService.instance.initialize()'), 'fatal startup screen has no in-app retry');

for (const dependency of [
  'supabase_flutter: 2.14.2',
  'printing: 5.14.3',
  'share_plus: 10.0.3',
  'pdf: 3.12.0',
]) {
  assert(pubspec.includes(dependency), `known-good dependency changed: ${dependency}`);
}

console.log('Build 77 UX, reports, ranking, overflow, fund, revision, and startup validation passed.');
