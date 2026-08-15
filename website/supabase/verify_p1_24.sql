-- SUPERSEDED FOR THE CURRENT PARTIAL/INCONSISTENT CLOUD SCHEMA.
-- Do not run this after a failed P1.24 migration. Run P1.25_SUPABASE_PREFLIGHT.sql first;
-- only run P1.25_VERIFY.sql after the P1.25 compatibility repair succeeds.
-- P1.24 verification. Run only after P1.24_SQL_20260808000200.sql succeeds.
WITH columns_ok AS (
  SELECT
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='students' AND column_name='review_plan_type'
    ) AS students_review_unit,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='students' AND column_name='talaqqin_enabled'
    ) AS students_talaqqin_stage,
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema='public' AND table_name='plans' AND column_name='review_unit'
    ) AS plans_review_unit
), tables_ok AS (
  SELECT
    to_regclass('public.quran_courses') IS NOT NULL AS quran_courses,
    to_regclass('public.quran_course_enrollments') IS NOT NULL AS quran_course_enrollments
), rls_ok AS (
  SELECT
    COALESCE((
      SELECT relrowsecurity
      FROM pg_class
      WHERE oid = to_regclass('public.quran_courses')
    ), FALSE) AS courses_rls,
    COALESCE((
      SELECT relrowsecurity
      FROM pg_class
      WHERE oid = to_regclass('public.quran_course_enrollments')
    ), FALSE) AS enrollments_rls
), policy_ok AS (
  SELECT
    EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public' AND tablename='quran_courses'
        AND policyname='quran_courses_scoped_access'
    ) AS courses_policy,
    EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname='public' AND tablename='quran_course_enrollments'
        AND policyname='quran_course_enrollments_scoped_access'
    ) AS enrollments_policy
)
SELECT * FROM columns_ok CROSS JOIN tables_ok CROSS JOIN rls_ok CROSS JOIN policy_ok;
