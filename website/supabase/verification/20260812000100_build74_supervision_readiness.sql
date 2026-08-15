-- Read-only verification for Build 74 supervision repair.
-- Expected result: every row has passed = true.

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
    ('public.get_supervision_health()')
), checks AS (
  SELECT
    'schema'::text AS check_group,
    'supervision_tables_exist'::text AS check_name,
    (
      to_regclass('public.supervisor_members') IS NOT NULL
      AND to_regclass('public.supervisor_center_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_member_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_audit_events') IS NOT NULL
      AND to_regclass('public.supervision_visits') IS NOT NULL
    ) AS passed,
    'P7.3/P1.20 tables'::text AS details
  UNION ALL
  SELECT
    'schema', 'required_rpcs_exist',
    NOT EXISTS (
      SELECT 1 FROM required_functions
      WHERE to_regprocedure(signature) IS NULL
    ),
    coalesce((
      SELECT string_agg(signature, ', ')
      FROM required_functions
      WHERE to_regprocedure(signature) IS NULL
    ), 'all RPCs present')
  UNION ALL
  SELECT
    'membership', 'membership_pair_unique',
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND tablename = 'supervisor_members'
        AND indexname = 'uq_supervisor_members_supervisor_user'
    ),
    'unique supervisor_id + user_id'
  UNION ALL
  SELECT
    'membership', 'no_duplicate_memberships',
    NOT EXISTS (
      SELECT 1 FROM public.supervisor_members
      GROUP BY supervisor_id, user_id HAVING count(*) > 1
    ),
    'duplicates must be zero'
  UNION ALL
  SELECT
    'membership', 'owners_reconciled',
    NOT EXISTS (
      SELECT 1
      FROM public.supervisors AS supervisor
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
  SELECT
    'membership', 'single_active_owner',
    NOT EXISTS (
      SELECT 1 FROM public.supervisor_members
      WHERE role = 'owner' AND status = 'active'
      GROUP BY supervisor_id HAVING count(*) > 1
    ),
    'at most one active owner per organization'
  UNION ALL
  SELECT
    'rls', 'supervision_rls_enabled',
    NOT EXISTS (
      SELECT 1 FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname IN (
          'supervisor_members', 'supervisor_center_invitations',
          'supervisor_member_invitations', 'supervisor_audit_events',
          'supervision_visits'
        )
        AND NOT c.relrowsecurity
    ),
    'all supervision tables use RLS'
  UNION ALL
  SELECT
    'security', 'security_definer_search_path',
    NOT EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.prosecdef
        AND p.proname IN (
          'current_user_supervisor_role', 'current_user_can_access_supervisor',
          'current_user_can_manage_supervisor', 'create_supervisor_organization',
          'get_my_supervisors', 'create_supervisor_center_invitation',
          'accept_supervisor_center_invitation', 'unlink_center_from_supervisor',
          'create_supervisor_member_invitation', 'accept_supervisor_member_invitation',
          'get_supervisor_members', 'update_supervisor_member',
          'get_supervisor_dashboard', 'get_supervision_health',
          'validate_supervision_visit_center'
        )
        AND NOT EXISTS (
          SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg
          WHERE cfg LIKE 'search_path=%'
        )
    ),
    'SECURITY DEFINER functions pin search_path'
  UNION ALL
  SELECT
    'auth', 'supervisor_enum_role_available',
    EXISTS (
      SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      JOIN pg_namespace n ON n.oid = t.typnamespace
      WHERE n.nspname = 'public'
        AND t.typname = 'user_role'
        AND e.enumlabel = 'supervisor'
    ),
    'profiles.role supports supervisor'
)
SELECT check_group, check_name, passed, details
FROM checks
ORDER BY check_group, check_name;
