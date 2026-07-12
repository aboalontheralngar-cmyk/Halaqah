import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const service = readFileSync(
  resolve(root, 'lib/services/student_period_report_service.dart'),
  'utf8',
);
const model = readFileSync(
  resolve(root, 'lib/models/student_period_report.dart'),
  'utf8',
);
const screen = readFileSync(
  resolve(root, 'lib/screens/reports/student_period_report_screen.dart'),
  'utf8',
);
const pdf = readFileSync(resolve(root, 'lib/services/pdf_service.dart'), 'utf8');
const database = readFileSync(
  resolve(root, 'lib/services/database_service.dart'),
  'utf8',
);

const requiredServiceFragments = [
  'day.isRecitationRequiredDay &&',
  'holidayWeekdays.contains(date.weekday)',
  'suspendedDates.contains(key)',
];
const requiredModelFragments = ['memorizedLines / 15', 'memorizedPages / 20'];
const requiredScreenFragments = [
  'showDateRangePicker',
  'آخر 7 أيام',
  'الشهر الحالي',
  'مشاركة قالب WhatsApp',
  'PdfPageFormat.a4',
  'PdfPageFormat.a5',
];
const requiredPdfFragments = [
  'generateStudentPeriodReport',
  'مؤشر الأداء اليومي',
  'التفاصيل اليومية',
  'VacationReason.getLabel',
];
const requiredDatabaseFragments = [
  'getStudentRecordsInRange',
  'getStudentMemorizationInRange',
  'getStudentBehaviorPointsInRange',
  'getStudentVacationsInRange',
];

for (const [name, source, fragments] of [
  ['report service', service, requiredServiceFragments],
  ['report model', model, requiredModelFragments],
  ['report screen', screen, requiredScreenFragments],
  ['period PDF', pdf, requiredPdfFragments],
  ['database range queries', database, requiredDatabaseFragments],
]) {
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`${name} is missing: ${fragment}`);
    }
  }
}

console.log('Period report contract passed: ranges, holidays, details, PDF, and WhatsApp.');
