-- P1.26 Supabase deep audit - READ ONLY.
-- This file never creates, alters, updates, deletes, or grants anything.
-- Run it when P1.25 preflight returns STOP_BASE_SCOPE_MISSING.

WITH expected(name, category) AS (
  VALUES
    ('profiles','base'),
    ('supervisors','base'),
    ('centers','base'),
    ('halaqat','base'),
    ('center_members','base'),
    ('families','base'),
    ('family_guardians','base'),
    ('students','core'),
    ('attendance','core'),
    ('memorization','core'),
    ('points','core'),
    ('exams','core'),
    ('exam_scores','core'),
    ('vacations','core'),
    ('fund_transactions','core'),
    ('notifications','core'),
    ('plans','learning'),
    ('student_holds','learning'),
    ('talaqqin_records','learning'),
    ('student_admin_actions','learning'),
    ('quran_courses','learning'),
    ('quran_course_enrollments','learning'),
    ('center_settings','operations'),
    ('study_suspensions','operations'),
    ('daily_closings','operations'),
    ('mushaf_progress','operations'),
    ('homework_grades','operations'),
    ('plan_recitation_records','operations'),
    ('daily_achievements','operations')
), state AS (
  SELECT
    expected.name,
    expected.category,
    to_regclass(format('public.%I', expected.name)) IS NOT NULL AS exists
  FROM expected
), summary AS (
  SELECT
    COUNT(*) FILTER (WHERE category='base' AND exists) AS base_present,
    COUNT(*) FILTER (WHERE category='core' AND exists) AS core_present,
    COUNT(*) FILTER (WHERE category IN ('learning','operations') AND exists) AS extension_present,
    array_agg(name ORDER BY category, name) FILTER (WHERE exists) AS present_tables,
    array_agg(name ORDER BY category, name) FILTER (WHERE NOT exists) AS missing_tables
  FROM state
), auth_state AS (
  SELECT
    to_regclass('auth.users') IS NOT NULL AS auth_users_table_exists,
    CASE
      WHEN to_regclass('auth.users') IS NULL THEN NULL
      ELSE (SELECT COUNT(*) FROM auth.users)
    END AS auth_users_count
)
SELECT
  current_database() AS database_name,
  current_schema() AS active_schema,
  current_user AS database_role,
  auth_state.auth_users_table_exists,
  auth_state.auth_users_count,
  summary.base_present,
  summary.core_present,
  summary.extension_present,
  COALESCE(summary.present_tables, ARRAY[]::TEXT[]) AS present_app_tables,
  COALESCE(summary.missing_tables, ARRAY[]::TEXT[]) AS missing_app_tables,
  CASE
    WHEN summary.base_present = 0
      AND summary.core_present = 0
      AND summary.extension_present = 0
      THEN 'EMPTY_PROJECT_READY_FOR_GUARDED_BASE_BOOTSTRAP'
    WHEN summary.base_present = 0
      AND (summary.core_present > 0 OR summary.extension_present > 0)
      THEN 'STOP_ORPHAN_APP_TABLES_WITHOUT_BASE_SCOPE'
    WHEN summary.base_present BETWEEN 1 AND 6
      THEN 'STOP_PARTIAL_BASE_SCOPE'
    WHEN summary.base_present = 7
      THEN 'BASE_SCOPE_PRESENT_RERUN_P1_25_PREFLIGHT'
    ELSE 'STOP_REVIEW_REQUIRED'
  END AS recommendation
FROM summary, auth_state;

-- Compact per-table visibility, useful when the SQL editor truncates arrays.
WITH expected(name, category) AS (
  VALUES
    ('profiles','base'),('supervisors','base'),('centers','base'),
    ('halaqat','base'),('center_members','base'),('families','base'),
    ('family_guardians','base'),('students','core'),('attendance','core'),
    ('memorization','core'),('points','core'),('exams','core'),
    ('exam_scores','core'),('vacations','core'),('fund_transactions','core'),
    ('notifications','core'),('plans','learning'),('student_holds','learning'),
    ('talaqqin_records','learning'),('student_admin_actions','learning'),
    ('quran_courses','learning'),('quran_course_enrollments','learning'),
    ('center_settings','operations'),('study_suspensions','operations'),
    ('daily_closings','operations'),('mushaf_progress','operations'),
    ('homework_grades','operations'),('plan_recitation_records','operations'),
    ('daily_achievements','operations')
)
SELECT category, name, to_regclass(format('public.%I', name)) IS NOT NULL AS exists
FROM expected
ORDER BY category, name;
