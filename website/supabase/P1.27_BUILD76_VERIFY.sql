-- P1.27 Build 76 verification (read-only)
-- Run after P1.27_BUILD76_APPLY.sql. Every row should return passed = true.

WITH checks AS (
  SELECT
    'rpc'::text AS check_group,
    'completion_rpcs_exist'::text AS check_name,
    (
      to_regprocedure('public.get_supervision_center_detail(uuid,uuid,date,date)') IS NOT NULL
      AND to_regprocedure('public.delete_student_for_sync(uuid)') IS NOT NULL
      AND to_regprocedure('public.get_supervision_health()') IS NOT NULL
      AND to_regprocedure('public.get_sync_tombstones(uuid,uuid,bigint,integer)') IS NOT NULL
    ) AS passed,
    'center drill-down, guarded student delete, health, and tombstone RPCs'::text AS details

  UNION ALL
  SELECT
    'supervision', 'health_contract_build76',
    COALESCE(
      pg_get_functiondef(to_regprocedure('public.get_supervision_health()'))
        LIKE '%build76-2026-08-14%',
      false
    ),
    'health RPC exposes the Build 76 completion contract'

  UNION ALL
  SELECT
    'supervision', 'center_detail_execute_granted',
    has_function_privilege(
      'authenticated',
      'public.get_supervision_center_detail(uuid,uuid,date,date)',
      'EXECUTE'
    ),
    'authenticated supervisor members can call the guarded drill-down RPC'

  UNION ALL
  SELECT
    'sync', 'guarded_student_delete_execute_granted',
    has_function_privilege(
      'authenticated',
      'public.delete_student_for_sync(uuid)',
      'EXECUTE'
    ),
    'authenticated users can call the scope-checked student delete RPC'

  UNION ALL
  SELECT
    'sync', 'mushaf_progress_tombstone_trigger',
    EXISTS (
      SELECT 1
      FROM pg_trigger trigger_row
      JOIN pg_class table_row ON table_row.oid = trigger_row.tgrelid
      JOIN pg_namespace namespace_row ON namespace_row.oid = table_row.relnamespace
      WHERE namespace_row.nspname = 'public'
        AND table_row.relname = 'mushaf_progress'
        AND trigger_row.tgname = 'capture_sync_tombstone_after_delete'
        AND NOT trigger_row.tgisinternal
    ),
    'mushaf progress deletes are recorded for other offline devices'

  UNION ALL
  SELECT
    'sync', 'mushaf_progress_composite_ledger_key',
    COALESCE(
      pg_get_functiondef(to_regprocedure('public.capture_sync_tombstone()'))
        LIKE '%hizb_number%'
      AND pg_get_functiondef(to_regprocedure('public.capture_sync_tombstone()'))
        LIKE '%thumun_number%',
      false
    ),
    'mushaf_progress tombstones keep student+hizb+thumun identity in the ledger'

  UNION ALL
  SELECT
    'sync', 'capture_function_protected_search_path',
    COALESCE(
      (
        SELECT 'search_path=public, pg_temp' = ANY(COALESCE(proc.proconfig, ARRAY[]::text[]))
        FROM pg_proc proc
        JOIN pg_namespace namespace_row ON namespace_row.oid = proc.pronamespace
        WHERE namespace_row.nspname = 'public'
          AND proc.proname = 'capture_sync_tombstone'
        LIMIT 1
      ),
      false
    ),
    'tombstone trigger function pins search_path'

  UNION ALL
  SELECT
    'sync', 'student_delete_protected_search_path',
    COALESCE(
      (
        SELECT 'search_path=public, pg_temp' = ANY(COALESCE(proc.proconfig, ARRAY[]::text[]))
        FROM pg_proc proc
        JOIN pg_namespace namespace_row ON namespace_row.oid = proc.pronamespace
        WHERE namespace_row.nspname = 'public'
          AND proc.proname = 'delete_student_for_sync'
        LIMIT 1
      ),
      false
    ),
    'guarded delete RPC pins search_path'

  UNION ALL
  SELECT
    'sync', 'center_detail_protected_search_path',
    COALESCE(
      (
        SELECT 'search_path=public, pg_temp' = ANY(COALESCE(proc.proconfig, ARRAY[]::text[]))
        FROM pg_proc proc
        JOIN pg_namespace namespace_row ON namespace_row.oid = proc.pronamespace
        WHERE namespace_row.nspname = 'public'
          AND proc.proname = 'get_supervision_center_detail'
        LIMIT 1
      ),
      false
    ),
    'supervision detail RPC pins search_path'

  UNION ALL
  SELECT
    'exam', 'structured_monthly_exam_schema',
    (
      EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'exam_templates'
          AND column_name = 'criteria_json'
      )
      AND EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = 'exam_questions'
          AND column_name = 'question_score'
      )
      AND EXISTS (
        SELECT 1
        FROM pg_constraint c
        JOIN pg_class t ON t.oid = c.conrelid
        JOIN pg_namespace n ON n.oid = t.relnamespace
        WHERE n.nspname = 'public'
          AND t.relname = 'exams'
          AND c.contype = 'c'
          AND pg_get_constraintdef(c.oid) LIKE '%monthly_plan%'
      )
    ),
    'monthly exam templates/questions and monthly_plan exam type are available'
)
SELECT check_group, check_name, passed, details
FROM checks
ORDER BY check_group, check_name;
