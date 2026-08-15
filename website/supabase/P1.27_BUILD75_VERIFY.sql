-- P1.27 Build 75 read-only verification.
-- Run after P1.27_BUILD75_APPLY.sql.
-- Expected result: every returned row has passed = true.
-- This script does not insert, update, or delete application data.

WITH required_functions(signature) AS (
  VALUES
    ('public.current_user_supervisor_role(uuid)'),
    ('public.current_user_can_access_supervisor(uuid)'),
    ('public.current_user_can_manage_supervisor(uuid)'),
    ('public.create_supervisor_organization(text)'),
    ('public.get_my_supervisors()'),
    ('public.create_supervisor_center_invitation(uuid,integer,integer)'),
    ('public.accept_supervisor_center_invitation(uuid,text)'),
    ('public.unlink_center_from_supervisor(uuid,text)'),
    ('public.create_supervisor_member_invitation(uuid,text,text,integer)'),
    ('public.accept_supervisor_member_invitation(text)'),
    ('public.get_supervisor_members(uuid)'),
    ('public.update_supervisor_member(uuid,uuid,text,text)'),
    ('public.get_supervisor_dashboard(uuid,date,date)'),
    ('public.get_supervision_health()'),
    ('public.create_supervised_center(uuid,text,text,text,text,text)'),
    ('public.set_study_suspension(uuid,uuid,date,boolean,text)'),
    ('public.get_sync_tombstones(uuid,uuid,bigint,integer)'),
    ('public.delete_family_atomic(uuid)'),
    ('public.set_family_students_atomic(uuid,uuid[])'),
    ('public.save_family_guardian_atomic(uuid,uuid,text,text,text,text,boolean,text)'),
    ('public.delete_family_guardian_atomic(uuid)')
), protected_functions(name) AS (
  VALUES
    ('current_user_supervisor_role'),
    ('current_user_can_access_supervisor'),
    ('current_user_can_manage_supervisor'),
    ('create_supervisor_organization'),
    ('get_my_supervisors'),
    ('create_supervisor_center_invitation'),
    ('accept_supervisor_center_invitation'),
    ('unlink_center_from_supervisor'),
    ('create_supervisor_member_invitation'),
    ('accept_supervisor_member_invitation'),
    ('get_supervisor_members'),
    ('update_supervisor_member'),
    ('get_supervisor_dashboard'),
    ('get_supervision_health'),
    ('validate_supervision_visit_center'),
    ('create_supervised_center'),
    ('set_study_suspension'),
    ('capture_sync_tombstone'),
    ('get_sync_tombstones'),
    ('delete_family_atomic'),
    ('set_family_students_atomic'),
    ('save_family_guardian_atomic'),
    ('delete_family_guardian_atomic')
), tracked_tables(name) AS (
  VALUES
    ('students'), ('families'), ('family_guardians'), ('attendance'),
    ('homework_grades'), ('memorization'), ('points'), ('daily_achievements'),
    ('vacations'), ('exams'), ('exam_scores'), ('exam_templates'),
    ('fund_transactions'), ('notifications'), ('student_holds'),
    ('talaqqin_records'), ('student_admin_actions'), ('plans'),
    ('quran_courses'), ('quran_course_enrollments'), ('plan_recitation_records')
), checks AS (
  SELECT 'schema'::text AS check_group, 'supervision_tables_exist'::text AS check_name,
    to_regclass('public.supervisor_members') IS NOT NULL
      AND to_regclass('public.supervisor_center_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_member_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_audit_events') IS NOT NULL
      AND to_regclass('public.supervision_visits') IS NOT NULL AS passed,
    'supervision hierarchy tables'::text AS details

  UNION ALL
  SELECT 'schema', 'sync_tombstones_exists',
    to_regclass('public.sync_tombstones') IS NOT NULL,
    'durable cloud delete ledger'

  UNION ALL
  SELECT 'rpc', 'required_rpcs_exist',
    NOT EXISTS (SELECT 1 FROM required_functions WHERE to_regprocedure(signature) IS NULL),
    coalesce((SELECT string_agg(signature, ', ') FROM required_functions WHERE to_regprocedure(signature) IS NULL), 'all present')

  UNION ALL
  SELECT 'supervision', 'owners_reconciled',
    NOT EXISTS (
      SELECT 1 FROM public.supervisors AS supervisor
      WHERE supervisor.owner_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.supervisor_members AS member
          WHERE member.supervisor_id = supervisor.id
            AND member.user_id = supervisor.owner_id
            AND member.role = 'owner'
            AND member.status = 'active'
        )
    ),
    'every supervisors.owner_id has active owner membership'

  UNION ALL
  SELECT 'supervision', 'no_duplicate_memberships',
    NOT EXISTS (
      SELECT 1 FROM public.supervisor_members
      GROUP BY supervisor_id, user_id HAVING count(*) > 1
    ),
    'supervisor_id + user_id pairs are unique'

  UNION ALL
  SELECT 'supervision', 'direct_center_execute_granted',
    has_function_privilege('authenticated', 'public.create_supervised_center(uuid,text,text,text,text,text)', 'EXECUTE'),
    'authenticated can call guarded create_supervised_center RPC'

  UNION ALL
  SELECT 'supervision', 'health_contract_build75',
    position('build75-2026-08-12' in pg_get_functiondef(to_regprocedure('public.get_supervision_health()'))) > 0,
    'health RPC exposes Build 75 contract version'

  UNION ALL
  SELECT 'rls', 'supervision_and_tombstone_rls_enabled',
    NOT EXISTS (
      SELECT 1
      FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname IN (
          'supervisor_members','supervisor_center_invitations',
          'supervisor_member_invitations','supervisor_audit_events',
          'supervision_visits','sync_tombstones'
        )
        AND NOT c.relrowsecurity
    ),
    'all supervision tables and sync_tombstones use RLS'

  UNION ALL
  SELECT 'sync', 'delete_triggers_installed',
    NOT EXISTS (
      SELECT 1 FROM tracked_tables required
      WHERE to_regclass('public.' || required.name) IS NOT NULL
        AND NOT EXISTS (
          SELECT 1
          FROM pg_trigger trigger_row
          JOIN pg_class table_row ON table_row.oid = trigger_row.tgrelid
          JOIN pg_namespace namespace_row ON namespace_row.oid = table_row.relnamespace
          WHERE namespace_row.nspname = 'public'
            AND table_row.relname = required.name
            AND trigger_row.tgname = 'capture_sync_tombstone_after_delete'
            AND NOT trigger_row.tgisinternal
        )
    ),
    'every existing tracked table has an AFTER DELETE tombstone trigger'

  UNION ALL
  SELECT 'sync', 'tombstones_not_directly_exposed',
    NOT has_table_privilege('authenticated', 'public.sync_tombstones', 'SELECT')
      AND NOT has_table_privilege('authenticated', 'public.sync_tombstones', 'INSERT')
      AND has_function_privilege('authenticated', 'public.get_sync_tombstones(uuid,uuid,bigint,integer)', 'EXECUTE'),
    'authenticated reads scoped tombstones only through guarded RPC'

  UNION ALL
  SELECT 'exam', 'monthly_plan_type_enabled',
    EXISTS (
      SELECT 1
      FROM pg_constraint constraint_row
      JOIN pg_class table_row ON table_row.oid = constraint_row.conrelid
      JOIN pg_namespace namespace_row ON namespace_row.oid = table_row.relnamespace
      WHERE namespace_row.nspname = 'public'
        AND table_row.relname = 'exams'
        AND constraint_row.conname = 'exams_type_check'
        AND pg_get_constraintdef(constraint_row.oid) LIKE '%monthly_plan%'
    ),
    'exams.type accepts monthly_plan'

  UNION ALL
  SELECT 'security', 'protected_search_path',
    NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      JOIN protected_functions f ON f.name = p.proname
      WHERE n.nspname = 'public' AND p.prosecdef
        AND NOT EXISTS (
          SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg
          WHERE cfg LIKE 'search_path=%' AND cfg LIKE '%pg_temp%'
        )
    ),
    'all protected SECURITY DEFINER functions pin search_path with pg_temp'

  UNION ALL
  SELECT 'security', 'supervisor_role_available',
    EXISTS (
      SELECT 1 FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public' AND t.typname = 'user_role' AND e.enumlabel = 'supervisor'
    ),
    'profiles.role supports supervisor'
)
SELECT check_group, check_name, passed, details
FROM checks
ORDER BY check_group, check_name;
