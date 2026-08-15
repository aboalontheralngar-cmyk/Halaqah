-- Read-only verification for P1.14. Paste the CONTENTS after applying the
-- migration. Every row should return passed = true.

WITH checks AS (
  SELECT
    'table:daily_closings'::TEXT AS check_name,
    to_regclass('public.daily_closings') IS NOT NULL AS passed,
    COALESCE(to_regclass('public.daily_closings')::TEXT, 'missing') AS details
  UNION ALL
  SELECT
    'table:study_suspensions',
    to_regclass('public.study_suspensions') IS NOT NULL,
    COALESCE(to_regclass('public.study_suspensions')::TEXT, 'missing')
  UNION ALL
  SELECT
    'function:close_daily_operations',
    to_regprocedure('public.close_daily_operations(uuid,uuid,date,integer,integer)') IS NOT NULL,
    COALESCE(to_regprocedure('public.close_daily_operations(uuid,uuid,date,integer,integer)')::TEXT, 'missing')
  UNION ALL
  SELECT
    'function:get_daily_closing_state',
    to_regprocedure('public.get_daily_closing_state(uuid,uuid,date)') IS NOT NULL,
    COALESCE(to_regprocedure('public.get_daily_closing_state(uuid,uuid,date)')::TEXT, 'missing')
  UNION ALL
  SELECT
    'function:set_study_suspension',
    to_regprocedure('public.set_study_suspension(uuid,uuid,date,boolean,text)') IS NOT NULL,
    COALESCE(to_regprocedure('public.set_study_suspension(uuid,uuid,date,boolean,text)')::TEXT, 'missing')
  UNION ALL
  SELECT
    'rls:daily_closings',
    COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.daily_closings')), FALSE),
    COALESCE((SELECT COUNT(*)::TEXT FROM pg_policies WHERE schemaname = 'public' AND tablename = 'daily_closings'), '0') || ' policies'
  UNION ALL
  SELECT
    'rls:study_suspensions',
    COALESCE((SELECT relrowsecurity FROM pg_class WHERE oid = to_regclass('public.study_suspensions')), FALSE),
    COALESCE((SELECT COUNT(*)::TEXT FROM pg_policies WHERE schemaname = 'public' AND tablename = 'study_suspensions'), '0') || ' policies'
  UNION ALL
  SELECT
    'columns:center_settings',
    (
      SELECT COUNT(*) = 4
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'center_settings'
        AND column_name IN ('session_end_time', 'timezone_name', 'weekly_holiday_days', 'points_config')
    ),
    (
      SELECT COUNT(*)::TEXT || '/4 columns'
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'center_settings'
        AND column_name IN ('session_end_time', 'timezone_name', 'weekly_holiday_days', 'points_config')
    )
)
SELECT check_name, passed, details
FROM checks
ORDER BY check_name;
