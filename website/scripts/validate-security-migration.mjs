import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '..');
const migration = readFileSync(
  resolve(root, 'supabase/migrations/20260711000200_p0_security_qr_attendance.sql'),
  'utf8',
);
const examMigration = readFileSync(
  resolve(root, 'supabase/migrations/20260711000300_p2_exam_templates.sql'),
  'utf8',
);
const holdMigration = readFileSync(
  resolve(root, 'supabase/migrations/20260711000400_p3_student_holds.sql'),
  'utf8',
);
const androidService = readFileSync(
  resolve(root, '../lib/services/supabase_service.dart'),
  'utf8',
);
const webStore = readFileSync(resolve(root, 'src/store/useStore.ts'), 'utf8');

const requiredMigrationFragments = [
  'DROP FUNCTION IF EXISTS public.activate_member_by_code',
  'FOR UPDATE',
  'REVOKE ALL ON FUNCTION public.join_center_with_code(TEXT) FROM PUBLIC, anon',
  'invitation_expires_at',
  'invitation_used_at',
  'uq_attendance_student_date',
  'uq_students_qr_code',
  'current_user_can_access_halaqa',
  'current_user_can_access_student',
];

for (const fragment of requiredMigrationFragments) {
  if (!migration.includes(fragment)) {
    throw new Error(`Security migration is missing: ${fragment}`);
  }
}

const requiredExamMigrationFragments = [
  'ADD COLUMN IF NOT EXISTS halaqa_id',
  'ADD COLUMN IF NOT EXISTS student_id',
  'criteria_json JSONB',
  'CREATE OR REPLACE FUNCTION public.set_exam_template_scope()',
  'current_user_can_access_halaqa(center_id, halaqa_id)',
  'CREATE POLICY exam_questions_scoped_access',
  'uq_exam_question_order',
];

for (const fragment of requiredExamMigrationFragments) {
  if (!examMigration.includes(fragment)) {
    throw new Error(`Exam template migration is missing: ${fragment}`);
  }
}

for (const fragment of [
  'CREATE TABLE IF NOT EXISTS public.student_holds',
  'CREATE OR REPLACE FUNCTION public.set_student_hold_scope()',
  'CREATE POLICY student_holds_scoped_access',
  'current_user_can_access_halaqa(center_id, halaqa_id)',
  'student_holds_valid_range',
]) {
  if (!holdMigration.includes(fragment)) {
    throw new Error(`Student hold migration is missing: ${fragment}`);
  }
}

for (const fragment of [
  "await _syncExamTemplates(centerId, halaqahId)",
  "client.from('exam_templates').upsert",
  "client.from('exam_questions').upsert",
  "await _syncStudentHolds(centerId, halaqahId)",
  "client.from('student_holds').upsert",
]) {
  if (!androidService.includes(fragment)) {
    throw new Error(`Android exam synchronization is missing: ${fragment}`);
  }
}

for (const [name, source] of [
  ['Android Supabase service', androidService],
  ['Web store', webStore],
]) {
  if (source.includes("'activate_member_by_code'") ||
      source.includes("'get_member_by_code'")) {
    throw new Error(`${name} still calls a legacy invitation RPC`);
  }
}

if (!webStore.includes("onConflict: 'student_id,date'")) {
  throw new Error('Web attendance does not use the student/date upsert contract');
}

console.log(
  'Security contract check passed: invitations, RLS, QR, attendance, exams, and student holds.',
);
