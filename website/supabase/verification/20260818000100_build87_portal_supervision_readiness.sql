-- Halaqah P1.27 Build 87 / Hotfix 12 verification (read-only).
WITH function_paths AS (
  SELECT
    p.oid,
    replace(coalesce(array_to_string(p.proconfig, ','), ''), ' ', '') AS config
  FROM pg_proc p
), checks AS (
  SELECT 'portal'::text AS area, 'pgcrypto_extension'::text AS check_name,
    EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') AS passed,
    'portal PIN/session hashing dependency'::text AS details
  UNION ALL
  SELECT 'portal', 'student_portal_tables',
    to_regclass('public.student_portal_credentials') IS NOT NULL
      AND to_regclass('public.student_portal_sessions') IS NOT NULL,
    'credential and short-lived session tables exist'
  UNION ALL
  SELECT 'portal', 'student_portal_rpcs',
    to_regprocedure('public.student_portal_authenticate(text,text,text)') IS NOT NULL
      AND to_regprocedure('public.student_portal_get_dashboard(text,integer)') IS NOT NULL,
    'Edge Function authentication/dashboard contract exists'
  UNION ALL
  SELECT 'portal', 'runtime_health_rpc',
    to_regprocedure('public.student_portal_runtime_health()') IS NOT NULL,
    'service-role diagnostics can verify the live portal contract'
  UNION ALL
  SELECT 'portal', 'portal_pgcrypto_search_path',
    coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.student_portal_authenticate(text,text,text)')), false)
      AND coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.student_portal_get_dashboard(text,integer)')), false),
    'portal SECURITY DEFINER RPCs resolve pgcrypto deterministically'
  UNION ALL
  SELECT 'supervision', 'center_invitation_rpcs',
    to_regprocedure('public.create_supervisor_center_invitation(uuid,integer,integer)') IS NOT NULL
      AND to_regprocedure('public.accept_supervisor_center_invitation(uuid,text)') IS NOT NULL,
    'center invite create/accept contract exists'
  UNION ALL
  SELECT 'supervision', 'member_invitation_rpcs',
    to_regprocedure('public.create_supervisor_member_invitation(uuid,text,text,integer)') IS NOT NULL
      AND to_regprocedure('public.accept_supervisor_member_invitation(text)') IS NOT NULL,
    'supervision-team invite create/accept contract exists'
  UNION ALL
  SELECT 'supervision', 'invitation_pgcrypto_search_path',
    coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.create_supervisor_center_invitation(uuid,integer,integer)')), false)
      AND coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.accept_supervisor_center_invitation(uuid,text)')), false)
      AND coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.create_supervisor_member_invitation(uuid,text,text,integer)')), false)
      AND coalesce((SELECT config LIKE '%search_path=public,extensions,pg_temp%' FROM function_paths WHERE oid = to_regprocedure('public.accept_supervisor_member_invitation(text)')), false),
    'all invite RPCs resolve gen_random_bytes/digest from extensions'
  UNION ALL
  SELECT 'supervision', 'invitation_execute_privileges',
    has_function_privilege('authenticated', 'public.create_supervisor_center_invitation(uuid,integer,integer)', 'EXECUTE')
      AND has_function_privilege('authenticated', 'public.accept_supervisor_center_invitation(uuid,text)', 'EXECUTE')
      AND has_function_privilege('authenticated', 'public.create_supervisor_member_invitation(uuid,text,text,integer)', 'EXECUTE')
      AND has_function_privilege('authenticated', 'public.accept_supervisor_member_invitation(text)', 'EXECUTE'),
    'authenticated supervision users can call guarded invitation RPCs'
)
SELECT area, check_name, passed, details
FROM checks
ORDER BY area, check_name;
