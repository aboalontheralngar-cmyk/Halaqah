import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = path => readFileSync(resolve(root, path), 'utf8');
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const generator = read('lib/services/exam_question_generator_service.dart');
const range = read('lib/services/quran_cross_surah_range_service.dart');
const screen = read('lib/screens/exam/exam_generator_screen.dart');
const assessment = read('lib/services/exam_assessment_service.dart');
const model = read('lib/models/exam_template.dart');
const database = read('lib/services/database_service.dart');
const sync = read('lib/services/supabase_service.dart');
const pdf = read('lib/services/pdf_service.dart');
const migration = read(
  'website/supabase/migrations/20260713000200_p5_advanced_mushaf_exams.sql',
);
const compat = read(
  'website/supabase/migrations/20260713000090_p5_memorization_halaqa_compat.sql',
);

for (const contract of [
  'allowedQuarterIds',
  "case 'mushaf':",
  "'to_surah_id': end.surah.number",
  "'is_assessed': false",
]) requireText(generator, contract, `question generator ${contract}`);

for (const contract of [
  'enum QuranRangeBoundary { page, hizb }',
  'class QuranCrossSurahRangeService',
  'startSurahId',
]) requireText(range, contract, `cross-surah range ${contract}`);

for (const contract of [
  "'mushaf': 'خريطة المصحف'",
  '_buildMushafQuarterMap',
  'QuranRangeBoundary.page',
  'QuranRangeBoundary.hizb',
  '_adjustQuestionAssessment',
  '_calculateQuestionScore',
  "'quarterIds': _selectedQuarterIds.toList()..sort()",
]) requireText(screen, contract, `exam UI ${contract}`);

for (const contract of [
  'static const double maximumScore = 10',
  'safeMemorization * 2',
  '.clamp(0, maximumScore)',
]) requireText(assessment, contract, `assessment policy ${contract}`);

for (const contract of [
  'final int toSurahId;',
  'final bool isAssessed;',
  'final int memorizationErrors;',
  'final double questionScore;',
]) requireText(model, contract, `question model ${contract}`);

for (const contract of [
  'version: 18',
  '_upgradeToVersion13',
  "'to_surah_id': 'INTEGER'",
  "'question_score': 'REAL NOT NULL DEFAULT 0'",
]) requireText(database, contract, `SQLite ${contract}`);

for (const contract of [
  "'to_surah': question.toSurahId",
  "'is_assessed': question.isAssessed",
  "'question_score': question.questionScore",
]) requireText(sync, contract, `cloud sync ${contract}`);

for (const contract of [
  'كود الطالب: ${student.displayCode}',
  "count('memorization_errors')",
  'assessedScore',
]) requireText(pdf, contract, `exam PDF ${contract}`);

for (const contract of [
  'CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa',
  'ADD COLUMN IF NOT EXISTS to_surah INTEGER',
  'ADD COLUMN IF NOT EXISTS is_assessed BOOLEAN',
  'exam_questions_assessment_nonnegative',
  'COMMIT;',
]) requireText(migration, contract, `P5.7 migration ${contract}`);

const addHalaqa = compat.indexOf('ADD COLUMN IF NOT EXISTS halaqa_id UUID');
const backfillHalaqa = compat.indexOf('UPDATE public.memorization progress');
if (addHalaqa < 0 || addHalaqa > backfillHalaqa) {
  throw new Error('Compatibility SQL must create memorization.halaqa_id first');
}

for (const sql of [migration, compat]) {
  for (const forbidden of ['DROP TABLE', 'TRUNCATE TABLE']) {
    if (sql.toUpperCase().includes(forbidden)) {
      throw new Error(`Unsafe SQL found: ${forbidden}`);
    }
  }
}

console.log(
  'P5.7 contract passed: visual quarter map, cross-surah page/hizb ranges, digital assessment, PDF output, SQLite upgrade chain, cloud sync, and schema compatibility.',
);
