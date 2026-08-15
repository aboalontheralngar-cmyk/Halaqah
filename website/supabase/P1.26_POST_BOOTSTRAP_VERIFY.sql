-- P1.26 post-bootstrap verification (READ ONLY).
-- Run only after P1.26_POST_BOOTSTRAP_CORE.sql returns Success.

WITH expected_tables(name) AS (
  VALUES
    ('profiles'),('supervisors'),('centers'),('halaqat'),('center_members'),
    ('families'),('family_guardians'),('students'),('attendance'),
    ('memorization'),('points'),('exams'),('exam_scores'),('vacations'),
    ('fund_transactions'),('notifications'),('plans'),('student_holds'),
    ('talaqqin_records'),('student_admin_actions'),('quran_courses'),
    ('quran_course_enrollments')
), missing AS (
  SELECT name FROM expected_tables
  WHERE to_regclass(format('public.%I', name)) IS NULL
)
SELECT
  (SELECT COUNT(*) FROM expected_tables) AS expected_halaqah_tables,
  (SELECT COUNT(*) FROM missing) AS missing_halaqah_tables,
  COALESCE((SELECT string_agg(name, ', ' ORDER BY name) FROM missing), '') AS missing_names,
  CASE WHEN EXISTS (SELECT 1 FROM missing)
    THEN 'STOP_CORE_INCOMPLETE'
    ELSE 'READY_CORE_TABLES'
  END AS table_status;

WITH expected(table_name, column_name) AS (
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
), checked AS (
  SELECT expected.table_name, expected.column_name, columns.udt_name
  FROM expected
  LEFT JOIN information_schema.columns AS columns
    ON columns.table_schema='public'
   AND columns.table_name=expected.table_name
   AND columns.column_name=expected.column_name
)
SELECT
  COUNT(*) FILTER (WHERE udt_name IS NULL) AS missing_uuid_columns,
  COUNT(*) FILTER (WHERE udt_name IS NOT NULL AND udt_name <> 'uuid') AS incompatible_uuid_columns,
  CASE
    WHEN COUNT(*) FILTER (WHERE udt_name IS NULL) = 0
     AND COUNT(*) FILTER (WHERE udt_name IS NOT NULL AND udt_name <> 'uuid') = 0
    THEN 'READY_UUID_REFERENCES'
    ELSE 'STOP_UUID_REFERENCE_PROBLEM'
  END AS uuid_status
FROM checked;

SELECT
  to_regprocedure('public.current_user_is_center_admin(uuid)') IS NOT NULL AS center_admin_helper_ready,
  to_regprocedure('public.current_user_can_access_halaqa(uuid,uuid)') IS NOT NULL AS halaqa_access_helper_ready,
  to_regprocedure('public.current_user_can_access_student(uuid)') IS NOT NULL AS student_access_helper_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='students' AND column_name='review_plan_type'
  ) AS review_plan_type_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='students' AND column_name='talaqqin_enabled'
  ) AS talaqqin_enabled_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='plans' AND column_name='review_unit'
  ) AS plan_review_unit_ready;

SELECT
  tablename,
  rowsecurity
FROM pg_tables
WHERE schemaname='public'
  AND tablename IN (
    'students','attendance','memorization','points','exams','exam_scores',
    'vacations','fund_transactions','notifications','plans','student_holds',
    'talaqqin_records','student_admin_actions','quran_courses','quran_course_enrollments'
  )
ORDER BY tablename;

-- Final single decision row.
WITH required_tables(name) AS (
  VALUES
    ('students'),('attendance'),('memorization'),('points'),('exams'),('exam_scores'),
    ('vacations'),('fund_transactions'),('notifications'),('plans'),('student_holds'),
    ('talaqqin_records'),('student_admin_actions'),('quran_courses'),('quran_course_enrollments')
), missing_tables AS (
  SELECT COUNT(*) AS count FROM required_tables
  WHERE to_regclass(format('public.%I', name)) IS NULL
), helpers AS (
  SELECT
    (to_regprocedure('public.current_user_is_center_admin(uuid)') IS NOT NULL
     AND to_regprocedure('public.current_user_can_access_halaqa(uuid,uuid)') IS NOT NULL
     AND to_regprocedure('public.current_user_can_access_student(uuid)') IS NOT NULL) AS ready
), rls AS (
  SELECT COUNT(*) FILTER (WHERE NOT rowsecurity) AS disabled
  FROM pg_tables
  WHERE schemaname='public'
    AND tablename IN (
      'students','attendance','memorization','points','exams','exam_scores',
      'vacations','fund_transactions','notifications','plans','student_holds',
      'talaqqin_records','student_admin_actions','quran_courses','quran_course_enrollments'
    )
)
SELECT
  missing_tables.count AS missing_core_tables,
  helpers.ready AS scope_helpers_ready,
  rls.disabled AS core_tables_without_rls,
  CASE
    WHEN missing_tables.count > 0 THEN 'STOP_CORE_TABLES_MISSING'
    WHEN NOT helpers.ready THEN 'STOP_SCOPE_HELPERS_MISSING'
    WHEN rls.disabled > 0 THEN 'STOP_RLS_DISABLED'
    ELSE 'READY_FOR_APP_SYNC_TEST'
  END AS recommendation
FROM missing_tables, helpers, rls;
