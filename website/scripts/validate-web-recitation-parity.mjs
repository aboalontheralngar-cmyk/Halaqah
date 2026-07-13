import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const raffle = read('website/src/app/students/raffle/page.tsx');
const memorization = read('website/src/app/memorization/page.tsx');
const store = read('website/src/store/useStore.ts');
const migration = read(
  'website/supabase/migrations/20260713000100_p5_web_recitation_parity.sql',
);
const sync = read('lib/services/supabase_service.dart');
const database = read('lib/services/database_service.dart');
const gradeModel = read('lib/models/homework_grade.dart');
const progressModel = read('lib/models/memorization.dart');

for (const contract of [
  'halaqah_raffle_v2_',
  'drawTargetId',
  'drawEndsAt',
  'batchOrder',
  'قرعة دفعة واحدة',
  'excludeAbsent',
  'record.status === "absent" || record.status === "excused"',
  'memorization_prefill_student_id',
]) requireText(raffle, contract, `raffle contract ${contract}`);

for (const contract of [
  'typeFilter',
  'dateFrom',
  'dateTo',
  'openEditForm',
  'handleDelete',
  'updateHomeworkGrade',
  'deleteHomeworkGrade',
  'نطاق الآيات غير صحيح للسورة المحددة',
]) requireText(memorization, contract, `web history ${contract}`);

for (const contract of [
  "rpc('save_recitation_record'",
  "rpc('delete_recitation_record'",
  ".is('deleted_at', null)",
  'rebuildWebMushafProgress',
]) requireText(store, contract, `store mutation ${contract}`);

for (const contract of [
  'CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa',
  'CREATE OR REPLACE FUNCTION public.save_recitation_record',
  'CREATE OR REPLACE FUNCTION public.delete_recitation_record',
  'ADD COLUMN IF NOT EXISTS halaqa_id UUID',
  'ADD COLUMN IF NOT EXISTS updated_at',
  'ADD COLUMN IF NOT EXISTS deleted_at',
  'grade.grade_mark <> \'absent\'',
  'GRANT EXECUTE ON FUNCTION public.save_recitation_record',
  'COMMIT;',
]) requireText(migration, contract, `migration ${contract}`);

const halaqaColumn = migration.indexOf('ADD COLUMN IF NOT EXISTS halaqa_id UUID');
const halaqaBackfill = migration.indexOf('UPDATE public.memorization progress');
if (halaqaColumn < 0 || halaqaColumn > halaqaBackfill) {
  throw new Error('memorization.halaqa_id must be created before its backfill');
}

for (const forbidden of ['DROP TABLE', 'TRUNCATE TABLE']) {
  if (migration.toUpperCase().includes(forbidden)) {
    throw new Error(`Unsafe SQL found in P5.6 migration: ${forbidden}`);
  }
}

for (const contract of [
  '_syncMemorizationProgress(centerId, halaqahId, direction)',
  "row['deleted_at'] != null",
  'updatedAt.isAfter(remote.updatedAt)',
  'upsertMemorizationProgressFromSync',
  'rebuildStudentProgress',
]) requireText(sync, contract, `Android sync ${contract}`);

for (const contract of [
  'version: 14',
  '_upgradeToVersion12',
  'deleteMemorizationProgressFromSync',
  'upsertMemorizationProgressFromSync',
]) requireText(database, contract, `SQLite ${contract}`);
requireText(gradeModel, 'final DateTime updatedAt;', 'grade conflict timestamp');
requireText(progressModel, 'DateTime updatedAt;', 'progress conflict timestamp');

console.log(
  'P5.6 contract passed: persistent/batch raffle, attendance exclusion, editable web history, atomic dual-table RPC, soft deletion, and two-way Android sync.',
);
