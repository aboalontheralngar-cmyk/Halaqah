import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const database = readFileSync(resolve(root, 'lib/services/database_service.dart'), 'utf8');
const history = readFileSync(
  resolve(root, 'lib/screens/memorization/recitation_history_screen.dart'),
  'utf8',
);
const attendance = readFileSync(
  resolve(root, 'lib/screens/attendance/attendance_screen.dart'),
  'utf8',
);
const sync = readFileSync(resolve(root, 'lib/services/supabase_service.dart'), 'utf8');

for (const fragment of [
  'updateMemorizationProgress',
  'deleteMemorizationProgress',
  '_recomputeRecitationState',
  '_recomputeStudentMemorizedTotal',
  'previousTrackedCount',
  '_findCompanionGradeId',
  'deleted_memorization_progress_ids',
  'deleted_homework_grade_ids',
]) {
  if (!database.includes(fragment)) {
    throw new Error(`Recitation mutation contract is missing: ${fragment}`);
  }
}

for (const fragment of [
  'سجل التسميع والمراجعة',
  'بحث باسم الطالب أو السورة',
  'تعديل السجل',
  'حذف السجل',
  'rebuildStudentProgress',
]) {
  if (!history.includes(fragment)) {
    throw new Error(`Recitation history UI is missing: ${fragment}`);
  }
}

for (const fragment of [
  '_openMemorization(student)',
  '_openRevision(student)',
  '_canOpenRecitation',
  'التسميع المباشر متاح لليوم الحالي فقط',
]) {
  if (!attendance.includes(fragment)) {
    throw new Error(`Attendance recitation action is missing: ${fragment}`);
  }
}

for (const fragment of [
  "table: 'memorization'",
  "table: 'homework_grades'",
  "'session_type': e.isRevision ? 'review' : 'new'",
]) {
  if (!sync.includes(fragment)) {
    throw new Error(`Recitation synchronization is missing: ${fragment}`);
  }
}

console.log(
  'Recitation record contract passed: attendance actions, history, mutation, recalculation, and sync.',
);
