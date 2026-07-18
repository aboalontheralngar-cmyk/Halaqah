import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const root = resolve(import.meta.dirname, '../..');
const read = (path) => readFileSync(resolve(root, path), 'utf8');
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const database = read('lib/services/database_service.dart');
const student = read('lib/models/student.dart');
const family = read('lib/models/family.dart');
const guardian = read('lib/models/family_guardian.dart');
const familyScreen = read('lib/screens/students/families_screen.dart');
const studentForm = read('lib/screens/students/student_form_screen.dart');
const home = read('lib/screens/home/home_screen.dart');
const sync = read('lib/services/supabase_service.dart');
const webPage = read('website/src/app/parents/page.tsx');
const webStore = read('website/src/store/useStore.ts');
const migration = read('website/supabase/migrations/20260712000400_p5_families_guardians.sql');

for (const contract of [
  'version: 18',
  'CREATE TABLE IF NOT EXISTS families',
  'CREATE TABLE IF NOT EXISTS family_guardians',
  'ALTER TABLE students ADD COLUMN family_id TEXT',
  'idx_family_one_primary_guardian',
  'assignStudentsToFamily',
  'deleted_family_ids',
  "'families'",
  "'family_guardians'",
]) requireText(database, contract, `SQLite family contract ${contract}`);

requireText(student, 'String? familyId', 'student family membership');
requireText(family, 'String? familyCode', 'cloud family code');
requireText(family, "return 'FAM-", 'stable formatted family code');
requireText(guardian, "'grandfather'", 'extended relationship list');

for (const contract of [
  'العائلات وأولياء الأمور',
  'اختيار أفراد العائلة',
  'جهة الاتصال الأساسية',
  'مرتبط بعائلة أخرى — سيُنقل عند الاختيار',
]) requireText(familyScreen, contract, `Android family UI ${contract}`);
requireText(studentForm, 'الربط الصريح أدق', 'explicit student family selector');
requireText(home, 'const FamiliesScreen()', 'Android family navigation');

for (const contract of [
  '_syncFamilies',
  "table: 'family_guardians'",
  "'family_id': student.familyId",
  'Family sync skipped until P5.4 migration is applied.',
]) requireText(sync, contract, `sync contract ${contract}`);

for (const contract of [
  '.from("families")',
  '.from("family_guardians")',
  'assign_students_to_family',
  'اختيار طالب مرتبط بعائلة أخرى سينقله',
]) requireText(webPage, contract, `web family contract ${contract}`);
if (webPage.includes('محاكاة بيانات أولياء الأمور')) {
  throw new Error('Parents page still contains mock guardian data.');
}
requireText(webStore, 'familyId?: string', 'web student family field');

for (const contract of [
  'CREATE TABLE IF NOT EXISTS public.families',
  'CREATE TABLE IF NOT EXISTS public.family_guardians',
  'ADD COLUMN IF NOT EXISTS family_id UUID',
  'current_user_can_access_halaqa',
  'idx_family_one_primary_guardian',
  'assign_students_to_family',
  'validate_student_family_scope',
  'propagate_primary_guardian_phone',
  'families_scoped_access',
  'family_guardians_scoped_access',
]) requireText(migration, contract, `Supabase family contract ${contract}`);
if (/\b(DROP\s+TABLE|TRUNCATE)\b/i.test(migration)) {
  throw new Error('Family migration contains a destructive table operation.');
}

console.log('Families and guardians contract passed: explicit membership, primary guardian, backup, sync, web, and scoped SQL.');
