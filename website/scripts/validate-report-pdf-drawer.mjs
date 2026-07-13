import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..', '..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const requireText = (source, text, label) => {
  if (!source.includes(text)) {
    throw new Error(`Missing ${label}: ${text}`);
  }
};

const student = read('lib/models/student.dart');
const pdf = read('lib/services/pdf_service.dart');
const reportService = read('lib/services/student_period_report_service.dart');
const reports = read('lib/screens/reports/reports_screen.dart');
const home = read('lib/screens/home/home_screen.dart');

requireText(student, 'String get displayCode', 'student report code');
requireText(student, "return 'HAL-$suffix';", 'safe code prefix');

requireText(pdf, 'generateAllStudentPeriodReports', 'batch PDF generator');
requireText(pdf, 'textDirection: pw.TextDirection.rtl', 'RTL PDF direction');
requireText(pdf, "'كود الطالب', report.student.displayCode", 'student code in PDF');
requireText(pdf, "'تقييم الفترة'", 'percentage score header');
requireText(
  pdf,
  "['الملاحظة', 'النقاط', 'المراجعة', 'الحفظ', 'الحالة', 'التاريخ']",
  'physically reversed RTL table columns',
);

requireText(reports, "'PDF لجميع الطلاب'", 'batch export action');
requireText(reports, '_BatchReportOptions', 'batch period options');
requireText(reports, 'ValueListenableBuilder<int>', 'batch progress feedback');
requireText(reports, 'generateAllStudentPeriodReports', 'batch PDF integration');
requireText(reportService, 'generateForStudents', 'optimized batch report query');
requireText(
  reportService,
  'onProgress?.call(index + 1, students.length)',
  'batch report progress callback',
);

requireText(home, 'drawer: _buildNavigationDrawer()', 'app drawer');
requireText(home, "label: 'التقارير'", 'reports drawer destination');
requireText(home, "label: 'الحفظ والمراجعة'", 'memorization drawer destination');
requireText(home, 'onOpenMenu: openMenu', 'drawer access from primary tabs');

console.log('Report PDF, batch export, and navigation drawer contract is valid.');
