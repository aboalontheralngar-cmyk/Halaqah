import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const model = read('lib/models/halaqah_period_report.dart');
const service = read('lib/services/halaqah_period_report_service.dart');
const screen = read('lib/screens/reports/halaqah_period_report_screen.dart');
const reportsScreen = read('lib/screens/reports/reports_screen.dart');
const pdf = read('lib/services/pdf_service.dart');
const test = read('test/halaqah_period_report_service_test.dart');
const web = read('website/src/app/reports/page.tsx');

for (const contract of [
  'totalMemorizedAyahs',
  'totalRevisedAyahs',
  'attentionStudents',
  'attendanceRecords > 0',
  'topStudents',
  'recitedStudentCount',
]) requireText(model, contract, `aggregate model ${contract}`);

for (const contract of [
  'generateForStudents',
  'attendanceTotal == 0',
  'reports.fold',
  'report.attendanceTotal > 0',
]) requireText(service, contract, `aggregate calculation ${contract}`);

for (const contract of [
  'RepaintBoundary',
  'toImage(pixelRatio: 2.2)',
  'مشاركة كصورة',
  'التقرير التجميعي للحلقة',
  'يحتاج متابعة',
]) requireText(screen, contract, `Android visual report ${contract}`);
requireText(reportsScreen, 'const HalaqahPeriodReportScreen()', 'reports navigation');
requireText(pdf, 'generateHalaqahPeriodReport', 'aggregate PDF');
requireText(test, 'aggregates real student-period reports', 'aggregate regression test');

for (const contract of [
  'periodStart',
  'periodEnd',
  'downloadSummaryImage',
  'canvas.toBlob',
  'attentionStudents',
  'stats.totalMemorizedAyahs',
  'الفترة المختارة',
]) requireText(web, contract, `web visual report ${contract}`);

for (const forbidden of [
  'const avgExams = 92',
  '+12% الشهر الماضي',
  'تقدماً ملحوظاً في معدلات الحفظ بنسبة 15%',
  ': 85;',
]) {
  if (web.includes(forbidden)) {
    throw new Error(`Web report still contains mock metric: ${forbidden}`);
  }
}

console.log('Halaqah period report contract passed: real period metrics, aggregate PDF, Android share image, and web PNG without mock percentages.');
