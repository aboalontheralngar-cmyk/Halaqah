-- Halaqah P1.27 Build 87 / Hotfix 12
-- Portal runtime hardening + supervision invitation pgcrypto path repair.
-- Safe, additive and idempotent. No application data is deleted.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  required_signature text;
BEGIN
  FOREACH required_signature IN ARRAY ARRAY[
    'public.create_supervisor_center_invitation(uuid,integer,integer)',
    'public.accept_supervisor_center_invitation(uuid,text)',
    'public.create_supervisor_member_invitation(uuid,text,text,integer)',
    'public.accept_supervisor_member_invitation(text)',
    'public.student_portal_authenticate(text,text,text)',
    'public.student_portal_get_dashboard(text,integer)'
  ] LOOP
    IF to_regprocedure(required_signature) IS NULL THEN
      RAISE EXCEPTION 'required Build 87 dependency is missing: %', required_signature;
    END IF;
  END LOOP;
END;
$$;

-- Build 74 invitation RPCs call pgcrypto functions. Supabase commonly installs
-- pgcrypto in the extensions schema, so include it explicitly in SECURITY
-- DEFINER search_path rather than relying on a session-specific path.
ALTER FUNCTION public.create_supervisor_center_invitation(uuid, integer, integer)
  SET search_path TO public, extensions, pg_temp;
ALTER FUNCTION public.accept_supervisor_center_invitation(uuid, text)
  SET search_path TO public, extensions, pg_temp;
ALTER FUNCTION public.create_supervisor_member_invitation(uuid, text, text, integer)
  SET search_path TO public, extensions, pg_temp;
ALTER FUNCTION public.accept_supervisor_member_invitation(text)
  SET search_path TO public, extensions, pg_temp;

REVOKE ALL ON FUNCTION public.create_supervisor_center_invitation(uuid, integer, integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_supervisor_center_invitation(uuid, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_supervisor_member_invitation(uuid, text, text, integer)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_supervisor_member_invitation(text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_supervisor_center_invitation(uuid, integer, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_supervisor_center_invitation(uuid, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_supervisor_member_invitation(uuid, text, text, integer)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_supervisor_member_invitation(text)
  TO authenticated;

-- Reassert the portal pgcrypto path. Build 82 already uses this contract; these
-- ALTERs make a partially replayed database converge safely to the same state.
ALTER FUNCTION public.student_portal_authenticate(text, text, text)
  SET search_path TO public, extensions, pg_temp;
ALTER FUNCTION public.student_portal_get_dashboard(text, integer)
  SET search_path TO public, extensions, pg_temp;

DO $$
BEGIN
  IF to_regprocedure('public.set_student_portal_pin(uuid,text,boolean)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.set_student_portal_pin(uuid,text,boolean) SET search_path TO public, extensions, pg_temp';
  END IF;
  IF to_regprocedure('public.get_student_portal_status(uuid)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.get_student_portal_status(uuid) SET search_path TO public, extensions, pg_temp';
  END IF;
  IF to_regprocedure('public.student_portal_revoke_session(text)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.student_portal_revoke_session(text) SET search_path TO public, extensions, pg_temp';
  END IF;
  IF to_regprocedure('public.family_portal_authenticate(text,text,text)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.family_portal_authenticate(text,text,text) SET search_path TO public, extensions, pg_temp';
  END IF;
  IF to_regprocedure('public.family_portal_get_dashboard(text,integer,uuid)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.family_portal_get_dashboard(text,integer,uuid) SET search_path TO public, extensions, pg_temp';
  END IF;
  IF to_regprocedure('public.family_portal_revoke_session(text)') IS NOT NULL THEN
    EXECUTE 'ALTER FUNCTION public.family_portal_revoke_session(text) SET search_path TO public, extensions, pg_temp';
  END IF;
END;
$$;

-- Service-role-only runtime contract probe used by the Edge Function and
-- deployment diagnostics. It exposes no student data or secrets.
CREATE OR REPLACE FUNCTION public.student_portal_runtime_health()
RETURNS jsonb
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, extensions, pg_temp
AS $$
  SELECT jsonb_build_object(
    'ready',
      to_regclass('public.student_portal_credentials') IS NOT NULL
      AND to_regclass('public.student_portal_sessions') IS NOT NULL
      AND to_regprocedure('public.student_portal_authenticate(text,text,text)') IS NOT NULL
      AND to_regprocedure('public.student_portal_get_dashboard(text,integer)') IS NOT NULL
      AND EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto'),
    'credentials_table', to_regclass('public.student_portal_credentials') IS NOT NULL,
    'sessions_table', to_regclass('public.student_portal_sessions') IS NOT NULL,
    'authenticate_rpc', to_regprocedure('public.student_portal_authenticate(text,text,text)') IS NOT NULL,
    'dashboard_rpc', to_regprocedure('public.student_portal_get_dashboard(text,integer)') IS NOT NULL,
    'pgcrypto', EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto')
  );
$$;

REVOKE ALL ON FUNCTION public.student_portal_runtime_health()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.student_portal_runtime_health()
  TO service_role;

-- Force PostgREST to see the repaired function metadata immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;
