-- P1.22 post-migration verification. Read-only.
-- Run after 20260808000100_p1_22_activity_talaqqin_admin.sql.

SELECT to_regclass('public.student_holds') IS NOT NULL AS student_holds_table_installed;

WITH expected_columns(table_name, column_name) AS (
  VALUES
    ('attendance', 'activity_type'),
    ('attendance', 'activity_note'),
    ('attendance', 'recitation_exempt'),
    ('attendance', 'talaqqin_done'),
    ('attendance', 'talaqqin_amount'),
    ('attendance', 'talaqqin_note'),
    ('student_holds', 'scope')
), column_check AS (
  SELECT
    expected.table_name,
    expected.column_name,
    EXISTS (
      SELECT 1
      FROM information_schema.columns AS columns
      WHERE columns.table_schema = 'public'
        AND columns.table_name = expected.table_name
        AND columns.column_name = expected.column_name
    ) AS installed
  FROM expected_columns AS expected
), table_check AS (
  SELECT 'talaqqin_records' AS table_name,
         to_regclass('public.talaqqin_records') IS NOT NULL AS installed
  UNION ALL
  SELECT 'student_admin_actions',
         to_regclass('public.student_admin_actions') IS NOT NULL
), policy_check AS (
  SELECT 'student_holds_scoped_access' AS policy_name,
         EXISTS (
           SELECT 1 FROM pg_policies
           WHERE schemaname = 'public'
             AND tablename = 'student_holds'
             AND policyname = 'student_holds_scoped_access'
         ) AS installed
  UNION ALL
  SELECT 'talaqqin_records_scoped_access' AS policy_name,
         EXISTS (
           SELECT 1 FROM pg_policies
           WHERE schemaname = 'public'
             AND tablename = 'talaqqin_records'
             AND policyname = 'talaqqin_records_scoped_access'
         ) AS installed
  UNION ALL
  SELECT 'student_admin_actions_scoped_access',
         EXISTS (
           SELECT 1 FROM pg_policies
           WHERE schemaname = 'public'
             AND tablename = 'student_admin_actions'
             AND policyname = 'student_admin_actions_scoped_access'
         )
)
SELECT 'column' AS object_type,
       table_name || '.' || column_name AS object_name,
       installed
FROM column_check
UNION ALL
SELECT 'table', table_name, installed FROM table_check
UNION ALL
SELECT 'policy', policy_name, installed FROM policy_check
ORDER BY object_type, object_name;

-- The migration is structurally complete only when every row above is TRUE.
SELECT
  pg_get_functiondef(
    'public.close_daily_operations(uuid,uuid,date,integer,integer)'::regprocedure
  ) ILIKE '%recitation_exempt%' AS closing_respects_activity_exemption,
  pg_get_functiondef(
    'public.close_daily_operations(uuid,uuid,date,integer,integer)'::regprocedure
  ) ILIKE '%full_pause%' AS closing_respects_full_pause;
