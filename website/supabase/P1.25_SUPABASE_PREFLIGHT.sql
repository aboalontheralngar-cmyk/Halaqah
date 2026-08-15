-- P1.25 Supabase preflight (READ-ONLY).
-- Run this file before the P1.25 compatibility repair.
-- It only reads PostgreSQL catalog/information_schema metadata.

WITH required_tables(category, name) AS (
  VALUES
    ('base_scope', 'profiles'),
    ('base_scope', 'supervisors'),
    ('base_scope', 'centers'),
    ('base_scope', 'halaqat'),
    ('base_scope', 'center_members'),
    ('base_scope', 'families'),
    ('base_scope', 'family_guardians'),
    ('core_sync', 'students'),
    ('core_sync', 'attendance'),
    ('core_sync', 'memorization'),
    ('core_sync', 'points'),
    ('core_sync', 'exams'),
    ('core_sync', 'exam_scores'),
    ('core_sync', 'vacations'),
    ('core_sync', 'fund_transactions'),
    ('core_sync', 'notifications'),
    ('learning', 'plans'),
    ('learning', 'student_holds'),
    ('learning', 'talaqqin_records'),
    ('learning', 'student_admin_actions'),
    ('learning', 'quran_courses'),
    ('learning', 'quran_course_enrollments'),
    ('operations', 'center_settings'),
    ('operations', 'study_suspensions'),
    ('operations', 'daily_closings'),
    ('operations', 'mushaf_progress'),
    ('operations', 'homework_grades'),
    ('operations', 'plan_recitation_records'),
    ('operations', 'daily_achievements')
)
SELECT
  current_database() AS database_name,
  current_schema() AS active_schema,
  required.category,
  required.name AS object_name,
  cls.oid IS NOT NULL AS exists,
  CASE WHEN cls.oid IS NULL THEN NULL ELSE GREATEST(cls.reltuples::bigint, 0) END AS approx_rows
FROM required_tables AS required
LEFT JOIN pg_namespace AS ns ON ns.nspname = 'public'
LEFT JOIN pg_class AS cls
  ON cls.relnamespace = ns.oid
 AND cls.relname = required.name
 AND cls.relkind IN ('r', 'p')
ORDER BY required.category, required.name;

-- Base authorization/scope columns required by the additive repair. Missing
-- columns are a hard stop because P1.25 must not invent an authentication model.
WITH required(table_name, column_name, expected_type) AS (
  VALUES
    ('centers','id','uuid'),
    ('halaqat','id','uuid'), ('halaqat','center_id','uuid'),
    ('center_members','center_id','uuid'), ('center_members','user_id','uuid'),
    ('center_members','halaqah_id','uuid'), ('center_members','role','text'),
    ('families','id','uuid'), ('families','center_id','uuid'), ('families','halaqa_id','uuid')
)
SELECT
  required.table_name,
  required.column_name,
  required.expected_type,
  columns.udt_name AS actual_type,
  CASE
    WHEN columns.column_name IS NULL THEN 'STOP_MISSING_SCOPE_COLUMN'
    WHEN required.expected_type = 'uuid' AND columns.udt_name <> 'uuid' THEN 'STOP_TYPE_MISMATCH'
    WHEN required.expected_type = 'text' AND columns.udt_name NOT IN ('text','varchar') THEN 'STOP_TYPE_MISMATCH'
    ELSE 'ok'
  END AS compatibility
FROM required
LEFT JOIN information_schema.columns AS columns
  ON columns.table_schema='public'
 AND columns.table_name=required.table_name
 AND columns.column_name=required.column_name
ORDER BY required.table_name, required.column_name;

-- Existing helper functions. P1.25 preserves working helpers rather than
-- overwriting a newer supervisory-aware definition.
SELECT
  'current_user_is_center_admin' AS helper,
  to_regprocedure('public.current_user_is_center_admin(uuid)') IS NOT NULL AS exists
UNION ALL
SELECT
  'current_user_can_access_halaqa',
  to_regprocedure('public.current_user_can_access_halaqa(uuid,uuid)') IS NOT NULL
UNION ALL
SELECT
  'current_user_can_access_student',
  to_regprocedure('public.current_user_can_access_student(uuid)') IS NOT NULL;

-- Inspect every UUID relationship that the compatibility migration may repair.
-- A present column with a non-UUID type is a hard stop: the repair never coerces IDs.
WITH expected(table_name, column_name) AS (
  VALUES
    ('centers','id'),
    ('halaqat','id'), ('halaqat','center_id'),
    ('center_members','id'), ('center_members','id'), ('center_members','center_id'), ('center_members','user_id'), ('center_members','halaqah_id'),
    ('families','id'), ('families','center_id'), ('families','halaqa_id'),
    ('family_guardians','id'), ('family_guardians','family_id'), ('family_guardians','center_id'), ('family_guardians','halaqa_id'),
    ('students','id'), ('students','center_id'), ('students','halaqa_id'), ('students','family_id'),
    ('attendance','id'), ('attendance','id'), ('attendance','student_id'), ('attendance','center_id'), ('attendance','halaqa_id'),
    ('memorization','id'), ('memorization','id'), ('memorization','student_id'), ('memorization','center_id'), ('memorization','halaqa_id'),
    ('points','id'), ('points','student_id'), ('points','center_id'), ('points','halaqa_id'),
    ('exams','id'), ('exams','center_id'), ('exams','halaqa_id'),
    ('exam_scores','id'), ('exam_scores','id'), ('exam_scores','exam_id'), ('exam_scores','student_id'),
    ('vacations','id'), ('vacations','id'), ('vacations','student_id'), ('vacations','center_id'), ('vacations','halaqa_id'),
    ('fund_transactions','id'), ('fund_transactions','id'), ('fund_transactions','center_id'), ('fund_transactions','halaqa_id'), ('fund_transactions','student_id'), ('fund_transactions','behavior_point_id'),
    ('notifications','id'), ('notifications','id'), ('notifications','center_id'), ('notifications','halaqa_id'), ('notifications','student_id'),
    ('plans','id'), ('plans','id'), ('plans','center_id'), ('plans','halaqa_id'), ('plans','student_id'), ('plans','completion_exam_id'),
    ('student_holds','id'), ('student_holds','id'), ('student_holds','student_id'), ('student_holds','center_id'), ('student_holds','halaqa_id'),
    ('talaqqin_records','id'), ('talaqqin_records','id'), ('talaqqin_records','session_id'), ('talaqqin_records','student_id'), ('talaqqin_records','center_id'), ('talaqqin_records','halaqa_id'),
    ('student_admin_actions','id'), ('student_admin_actions','id'), ('student_admin_actions','student_id'), ('student_admin_actions','center_id'), ('student_admin_actions','halaqa_id'),
    ('quran_courses','id'), ('quran_courses','center_id'), ('quran_courses','halaqa_id'),
    ('quran_course_enrollments','id'), ('quran_course_enrollments','id'), ('quran_course_enrollments','course_id'), ('quran_course_enrollments','student_id'), ('quran_course_enrollments','center_id'), ('quran_course_enrollments','halaqa_id')
)
SELECT
  expected.table_name,
  expected.column_name,
  columns.udt_name,
  CASE
    WHEN columns.column_name IS NULL THEN 'missing'
    WHEN columns.udt_name = 'uuid' THEN 'ok'
    ELSE 'STOP_TYPE_MISMATCH'
  END AS compatibility
FROM expected
LEFT JOIN information_schema.columns AS columns
  ON columns.table_schema = 'public'
 AND columns.table_name = expected.table_name
 AND columns.column_name = expected.column_name
WHERE to_regclass(format('public.%I', expected.table_name)) IS NOT NULL
ORDER BY expected.table_name, expected.column_name;

-- One final decision row. Do not continue when recommendation starts with STOP.
WITH required_scope(table_name, column_name, expected_type) AS (
  VALUES
    ('centers','id','uuid'),
    ('halaqat','id','uuid'), ('halaqat','center_id','uuid'),
    ('center_members','center_id','uuid'), ('center_members','user_id','uuid'),
    ('center_members','halaqah_id','uuid'), ('center_members','role','text'),
    ('families','id','uuid'), ('families','center_id','uuid'), ('families','halaqa_id','uuid')
), missing_scope_columns AS (
  SELECT COUNT(*) AS count
  FROM required_scope AS expected
  LEFT JOIN information_schema.columns AS columns
    ON columns.table_schema='public'
   AND columns.table_name=expected.table_name
   AND columns.column_name=expected.column_name
  WHERE columns.column_name IS NULL
), bad_scope_types AS (
  SELECT COUNT(*) AS count
  FROM required_scope AS expected
  JOIN information_schema.columns AS columns
    ON columns.table_schema='public'
   AND columns.table_name=expected.table_name
   AND columns.column_name=expected.column_name
  WHERE (expected.expected_type='uuid' AND columns.udt_name <> 'uuid')
     OR (expected.expected_type='text' AND columns.udt_name NOT IN ('text','varchar'))
), uuid_expected(table_name, column_name) AS (
  VALUES
    ('centers','id'),
    ('halaqat','id'), ('halaqat','center_id'),
    ('center_members','id'), ('center_members','center_id'), ('center_members','user_id'), ('center_members','halaqah_id'),
    ('families','id'), ('families','center_id'), ('families','halaqa_id'),
    ('family_guardians','id'), ('family_guardians','family_id'), ('family_guardians','center_id'), ('family_guardians','halaqa_id'),
    ('students','id'), ('students','center_id'), ('students','halaqa_id'), ('students','family_id'),
    ('attendance','id'), ('attendance','student_id'), ('attendance','center_id'), ('attendance','halaqa_id'),
    ('memorization','id'), ('memorization','student_id'), ('memorization','center_id'), ('memorization','halaqa_id'),
    ('points','id'), ('points','student_id'), ('points','center_id'), ('points','halaqa_id'),
    ('exams','id'), ('exams','center_id'), ('exams','halaqa_id'),
    ('exam_scores','id'), ('exam_scores','exam_id'), ('exam_scores','student_id'),
    ('vacations','id'), ('vacations','student_id'), ('vacations','center_id'), ('vacations','halaqa_id'),
    ('fund_transactions','id'), ('fund_transactions','center_id'), ('fund_transactions','halaqa_id'), ('fund_transactions','student_id'), ('fund_transactions','behavior_point_id'),
    ('notifications','id'), ('notifications','center_id'), ('notifications','halaqa_id'), ('notifications','student_id'),
    ('plans','id'), ('plans','center_id'), ('plans','halaqa_id'), ('plans','student_id'), ('plans','completion_exam_id'),
    ('student_holds','id'), ('student_holds','student_id'), ('student_holds','center_id'), ('student_holds','halaqa_id'),
    ('talaqqin_records','id'), ('talaqqin_records','session_id'), ('talaqqin_records','student_id'), ('talaqqin_records','center_id'), ('talaqqin_records','halaqa_id'),
    ('student_admin_actions','id'), ('student_admin_actions','student_id'), ('student_admin_actions','center_id'), ('student_admin_actions','halaqa_id'),
    ('quran_courses','id'), ('quran_courses','center_id'), ('quran_courses','halaqa_id'),
    ('quran_course_enrollments','id'), ('quran_course_enrollments','course_id'), ('quran_course_enrollments','student_id'), ('quran_course_enrollments','center_id'), ('quran_course_enrollments','halaqa_id')
), type_mismatch AS (
  SELECT COUNT(*) AS count
  FROM uuid_expected AS expected
  JOIN information_schema.columns AS columns
    ON columns.table_schema = 'public'
   AND columns.table_name = expected.table_name
   AND columns.column_name = expected.column_name
  WHERE columns.udt_name <> 'uuid'
)
SELECT
  to_regclass('public.centers') IS NOT NULL AS centers_ready,
  to_regclass('public.halaqat') IS NOT NULL AS halaqat_ready,
  to_regclass('public.center_members') IS NOT NULL AS center_members_ready,
  to_regclass('public.families') IS NOT NULL AS families_ready,
  to_regclass('public.students') IS NOT NULL AS students_ready,
  missing_scope_columns.count AS missing_scope_columns,
  bad_scope_types.count AS bad_scope_types,
  type_mismatch.count AS incompatible_uuid_columns,
  CASE
    WHEN to_regclass('public.centers') IS NULL
      OR to_regclass('public.halaqat') IS NULL
      OR to_regclass('public.center_members') IS NULL
      OR to_regclass('public.families') IS NULL
      THEN 'STOP_BASE_SCOPE_MISSING: send the complete preflight output; do not run the repair.'
    WHEN missing_scope_columns.count > 0
      THEN 'STOP_BASE_SCOPE_COLUMNS_MISSING: send the complete preflight output; do not run the repair.'
    WHEN bad_scope_types.count > 0
      THEN 'STOP_SCOPE_KEY_MISMATCH: send the complete preflight output; IDs/roles will not be coerced.'
    WHEN type_mismatch.count > 0
      THEN 'STOP_REFERENCE_TYPE_MISMATCH: send the complete preflight output; IDs will not be coerced.'
    WHEN to_regclass('public.students') IS NULL
      THEN 'READY_FOR_P1_25_REPAIR: base scope is present; missing student/core surfaces can be rebuilt additively.'
    ELSE 'READY_FOR_P1_25: migration will only add/repair compatible surfaces.'
  END AS recommendation
FROM missing_scope_columns, bad_scope_types, type_mismatch;
