import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const database = readFileSync(resolve(root, 'lib/services/database_service.dart'), 'utf8');
const vacations = readFileSync(
  resolve(root, 'lib/screens/vacations/vacations_screen.dart'),
  'utf8',
);
const detail = readFileSync(
  resolve(root, 'lib/screens/students/student_detail_screen.dart'),
  'utf8',
);
const memorization = readFileSync(
  resolve(root, 'lib/screens/memorization/memorization_screen.dart'),
  'utf8',
);

for (const fragment of [
  'version: 14',
  'CREATE TABLE IF NOT EXISTS student_holds',
  'Future<void> insertVacations(List<Vacation> vacations)',
  'await db.transaction((txn) async',
  'getConsecutiveNoRecitationDays',
  "type: 'consecutive_no_recitation'",
  'settings.autoExpulsionEnabled',
  'settings.absenceDaysBeforeExpulsion',
  '_isPastClassEndTime',
  'getActiveStudentHold(record.studentId, date: targetDate)',
]) {
  if (!database.includes(fragment)) {
    throw new Error(`Discipline database contract is missing: ${fragment}`);
  }
}

for (const fragment of [
  '_pickVacationStudents',
  'selectedStudentIds.length',
  'await _db.insertVacations(vacations)',
  'اختيار الكل',
]) {
  if (!vacations.includes(fragment)) {
    throw new Error(`Group vacation UI is missing: ${fragment}`);
  }
}

for (const fragment of [
  'إيقاف التسميع مؤقتًا',
  'يبقى تسجيل الحضور متاحًا خلال الإيقاف',
  'await _db.saveStudentHold',
  'await _db.endStudentHold',
]) {
  if (!detail.includes(fragment)) {
    throw new Error(`Student hold UI is missing: ${fragment}`);
  }
}

for (const fragment of [
  'getActiveStudentHolds',
  '_showHoldMessage',
  'موقوف مؤقتًا',
]) {
  if (!memorization.includes(fragment)) {
    throw new Error(`Memorization hold guard is missing: ${fragment}`);
  }
}

console.log(
  'Discipline contract passed: group vacations, recitation holds, reminders, and expulsion.',
);
