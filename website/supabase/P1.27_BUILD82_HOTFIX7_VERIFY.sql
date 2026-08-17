-- P1.27 Build 82 Hotfix 7 readiness verification.
-- READ ONLY. This script does not change schema or application data.
-- Expected result: every returned row has passed = true.
-- Historical P7.3 should NOT be replayed on the current owner database;
-- this verifies the resulting/current Build 75/76 supervision contract instead.

WITH checks AS (
  SELECT
    'sync'::text AS area,
    'attendance_business_key'::text AS check_name,
    to_regclass('public.uq_attendance_student_date') IS NOT NULL AS passed,
    'required by Flutter/Web upsert on student_id,date'::text AS details

  UNION ALL
  SELECT
    'portal', 'student_code_column',
    EXISTS (
      SELECT 1 FROM information_schema.columns
      WHERE table_schema = 'public' AND table_name = 'students'
        AND column_name = 'student_code' AND is_nullable = 'NO'
    ),
    'P7 student public identity is present'

  UNION ALL
  SELECT
    'portal', 'student_portal_tables',
    to_regclass('public.student_portal_credentials') IS NOT NULL
      AND to_regclass('public.student_portal_sessions') IS NOT NULL
      AND to_regclass('public.student_portal_login_attempts') IS NOT NULL,
    'credential/session/rate-limit tables exist'

  UNION ALL
  SELECT
    'portal', 'student_portal_rpcs',
    to_regprocedure('public.get_student_portal_status(uuid)') IS NOT NULL
      AND to_regprocedure('public.set_student_portal_pin(uuid,text,boolean)') IS NOT NULL
      AND to_regprocedure('public.disable_student_portal(uuid)') IS NOT NULL
      AND to_regprocedure('public.student_portal_authenticate(text,text,text)') IS NOT NULL
      AND to_regprocedure('public.student_portal_get_dashboard(text,integer)') IS NOT NULL
      AND to_regprocedure('public.student_portal_revoke_session(text)') IS NOT NULL,
    'student portal management + Edge Function RPC contract'

  UNION ALL
  SELECT
    'portal', 'student_portal_privileges',
    COALESCE(has_function_privilege('authenticated', to_regprocedure('public.get_student_portal_status(uuid)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('authenticated', to_regprocedure('public.set_student_portal_pin(uuid,text,boolean)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('authenticated', to_regprocedure('public.disable_student_portal(uuid)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('service_role', to_regprocedure('public.student_portal_authenticate(text,text,text)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('service_role', to_regprocedure('public.student_portal_get_dashboard(text,integer)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('service_role', to_regprocedure('public.student_portal_revoke_session(text)'), 'EXECUTE'), false),
    'teacher/admin manages PIN; Edge Function service role authenticates'

  UNION ALL
  SELECT
    'portal', 'student_portal_rls_closed',
    COALESCE((
      SELECT bool_and(c.relrowsecurity)
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      WHERE n.nspname = 'public'
        AND c.relname IN (
          'student_portal_credentials',
          'student_portal_sessions',
          'student_portal_login_attempts'
        )
    ), false)
      AND NOT COALESCE(has_table_privilege('anon', to_regclass('public.student_portal_credentials'), 'SELECT'), false)
      AND NOT COALESCE(has_table_privilege('authenticated', to_regclass('public.student_portal_credentials'), 'SELECT'), false),
    'sensitive portal tables are not directly readable from clients'

  UNION ALL
  SELECT
    'portal', 'at_least_one_active_student_pin',
    EXISTS (
      SELECT 1 FROM public.student_portal_credentials
      WHERE enabled = true
    ),
    format(
      '%s active portal credential(s)',
      COALESCE((SELECT count(*) FROM public.student_portal_credentials WHERE enabled = true), 0)
    )

  UNION ALL
  SELECT
    'supervision', 'p7_3_resulting_tables',
    to_regclass('public.supervisor_members') IS NOT NULL
      AND to_regclass('public.supervisor_center_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_member_invitations') IS NOT NULL
      AND to_regclass('public.supervisor_audit_events') IS NOT NULL
      AND to_regclass('public.supervision_visits') IS NOT NULL,
    'current supervision hierarchy tables exist'

  UNION ALL
  SELECT
    'supervision', 'current_supervision_rpcs',
    to_regprocedure('public.current_user_can_manage_supervisor(uuid)') IS NOT NULL
      AND to_regprocedure('public.create_supervisor_center_invitation(uuid,integer,integer)') IS NOT NULL
      AND to_regprocedure('public.accept_supervisor_center_invitation(uuid,text)') IS NOT NULL
      AND to_regprocedure('public.create_supervised_center(uuid,text,text,text,text,text)') IS NOT NULL
      AND to_regprocedure('public.get_supervision_health()') IS NOT NULL
      AND to_regprocedure('public.get_supervision_center_detail(uuid,uuid,date,date)') IS NOT NULL,
    'Build 75/76 supervision RPC contract exists'

  UNION ALL
  SELECT
    'supervision', 'supervision_execute_privileges',
    COALESCE(has_function_privilege('authenticated', to_regprocedure('public.create_supervisor_center_invitation(uuid,integer,integer)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('authenticated', to_regprocedure('public.accept_supervisor_center_invitation(uuid,text)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('authenticated', to_regprocedure('public.create_supervised_center(uuid,text,text,text,text,text)'), 'EXECUTE'), false)
      AND COALESCE(has_function_privilege('authenticated', to_regprocedure('public.get_supervision_health()'), 'EXECUTE'), false),
    'authenticated users can call guarded supervision RPCs'

  UNION ALL
  SELECT
    'supervision', 'supervision_health_build76',
    COALESCE(
      pg_get_functiondef(to_regprocedure('public.get_supervision_health()'))
        LIKE '%build76-2026-08-14%',
      false
    ),
    'do not replay P7.3 when the current Build 76 contract is present'

  UNION ALL
  SELECT
    'supervision', 'owners_have_active_membership',
    NOT EXISTS (
      SELECT 1
      FROM public.supervisors s
      WHERE s.owner_id IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM public.supervisor_members m
          WHERE m.supervisor_id = s.id
            AND m.user_id = s.owner_id
            AND m.role = 'owner'
            AND m.status = 'active'
        )
    ),
    'every supervisory owner has an active immutable owner membership'

  UNION ALL
  SELECT
    'supervision', 'no_duplicate_memberships',
    NOT EXISTS (
      SELECT 1 FROM public.supervisor_members
      GROUP BY supervisor_id, user_id
      HAVING count(*) > 1
    ),
    'supervisor_id + user_id membership identity is unique'
)
SELECT area, check_name, passed, details
FROM checks
ORDER BY area, check_name;
