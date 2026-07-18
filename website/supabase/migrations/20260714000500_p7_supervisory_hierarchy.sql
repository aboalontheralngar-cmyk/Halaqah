-- P7.3: multi-center supervisory organizations, role-scoped access,
-- one-time invitations, and aggregate reporting.
-- Copy this file's CONTENTS into Supabase SQL Editor after P7.2.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS public.supervisor_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'analyst')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked')),
  invited_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (supervisor_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.supervisor_center_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  token_hash BYTEA NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  max_uses INTEGER NOT NULL DEFAULT 1 CHECK (max_uses BETWEEN 1 AND 100),
  used_count INTEGER NOT NULL DEFAULT 0 CHECK (used_count >= 0),
  last_used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.supervisor_member_invitations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('admin', 'analyst')),
  token_hash BYTEA NOT NULL UNIQUE,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at TIMESTAMPTZ,
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.supervisor_audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  center_id UUID REFERENCES public.centers(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (char_length(event_type) BETWEEN 3 AND 80),
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supervisor_members_user
  ON public.supervisor_members(user_id, status, supervisor_id);
CREATE INDEX IF NOT EXISTS idx_supervisor_centers
  ON public.centers(supervisor_id) WHERE supervisor_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_supervisor_center_invites_active
  ON public.supervisor_center_invitations(supervisor_id, expires_at DESC)
  WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_supervisor_member_invites_active
  ON public.supervisor_member_invitations(supervisor_id, expires_at DESC)
  WHERE used_at IS NULL AND revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_supervisor_audit_created
  ON public.supervisor_audit_events(supervisor_id, created_at DESC);

INSERT INTO public.supervisor_members (
  supervisor_id,
  user_id,
  role,
  status,
  joined_at
)
SELECT supervisor.id, supervisor.owner_id, 'owner', 'active', supervisor.created_at
FROM public.supervisors AS supervisor
WHERE supervisor.owner_id IS NOT NULL
ON CONFLICT (supervisor_id, user_id) DO UPDATE SET
  role = 'owner',
  status = 'active',
  updated_at = now();

CREATE UNIQUE INDEX IF NOT EXISTS uq_supervisor_active_owner
  ON public.supervisor_members(supervisor_id)
  WHERE role = 'owner' AND status = 'active';

CREATE OR REPLACE FUNCTION public.ensure_supervisor_owner_membership()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF TG_OP = 'UPDATE'
     AND OLD.owner_id IS DISTINCT FROM NEW.owner_id
     AND OLD.owner_id IS NOT NULL THEN
    UPDATE public.supervisor_members
    SET status = 'revoked',
        updated_at = now()
    WHERE supervisor_id = NEW.id
      AND user_id = OLD.owner_id
      AND role = 'owner';
  END IF;

  IF NEW.owner_id IS NOT NULL THEN
    INSERT INTO public.supervisor_members (
      supervisor_id,
      user_id,
      role,
      status,
      joined_at
    ) VALUES (
      NEW.id,
      NEW.owner_id,
      'owner',
      'active',
      now()
    )
    ON CONFLICT (supervisor_id, user_id) DO UPDATE SET
      role = 'owner',
      status = 'active',
      updated_at = now();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ensure_supervisor_owner_membership
  ON public.supervisors;
CREATE TRIGGER ensure_supervisor_owner_membership
  AFTER INSERT OR UPDATE OF owner_id ON public.supervisors
  FOR EACH ROW EXECUTE FUNCTION public.ensure_supervisor_owner_membership();

CREATE OR REPLACE FUNCTION public.current_user_supervisor_role(
  p_supervisor_id UUID
)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN auth.uid() IS NULL THEN NULL
    WHEN EXISTS (
      SELECT 1
      FROM public.supervisors AS supervisor
      WHERE supervisor.id = p_supervisor_id
        AND supervisor.owner_id = auth.uid()
    ) THEN 'owner'
    ELSE (
      SELECT member.role
      FROM public.supervisor_members AS member
      WHERE member.supervisor_id = p_supervisor_id
        AND member.user_id = auth.uid()
        AND member.status = 'active'
      LIMIT 1
    )
  END;
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_access_supervisor(
  p_supervisor_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.current_user_supervisor_role(p_supervisor_id)
    IN ('owner', 'admin', 'analyst');
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_manage_supervisor(
  p_supervisor_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.current_user_supervisor_role(p_supervisor_id)
    IN ('owner', 'admin');
$$;

-- Supervisory owners and admins retain the existing center-administrator
-- capabilities. Analysts receive aggregate read-only data only through the
-- dedicated dashboard RPC below.
CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.centers AS center_row
      WHERE center_row.id = p_center_id
        AND center_row.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.center_members AS member_row
      WHERE member_row.center_id = p_center_id
        AND member_row.user_id = auth.uid()
        AND member_row.role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.centers AS center_row
      WHERE center_row.id = p_center_id
        AND center_row.supervisor_id IS NOT NULL
        AND public.current_user_supervisor_role(center_row.supervisor_id)
          IN ('owner', 'admin')
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa(
  p_center_id UUID,
  p_halaqa_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.current_user_is_center_admin(p_center_id)
    OR EXISTS (
      SELECT 1 FROM public.center_members AS member_row
      WHERE member_row.center_id = p_center_id
        AND member_row.user_id = auth.uid()
        AND member_row.role = 'teacher'
        AND p_halaqa_id IS NOT NULL
        AND member_row.halaqah_id = p_halaqa_id
    );
$$;

REVOKE ALL ON FUNCTION public.ensure_supervisor_owner_membership()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.current_user_supervisor_role(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_supervisor(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_manage_supervisor(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_supervisor_role(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_supervisor(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_manage_supervisor(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  TO authenticated;

ALTER TABLE public.supervisor_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_center_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_member_invitations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_audit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS supervisor_members_select ON public.supervisor_members;
CREATE POLICY supervisor_members_select
  ON public.supervisor_members FOR SELECT TO authenticated
  USING (public.current_user_can_access_supervisor(supervisor_id));

DROP POLICY IF EXISTS supervisor_audit_select ON public.supervisor_audit_events;
CREATE POLICY supervisor_audit_select
  ON public.supervisor_audit_events FOR SELECT TO authenticated
  USING (public.current_user_can_access_supervisor(supervisor_id));

DROP POLICY IF EXISTS supervisors_member_select ON public.supervisors;
CREATE POLICY supervisors_member_select
  ON public.supervisors FOR SELECT TO authenticated
  USING (public.current_user_can_access_supervisor(id));

DROP POLICY IF EXISTS centers_supervision_select ON public.centers;
CREATE POLICY centers_supervision_select
  ON public.centers FOR SELECT TO authenticated
  USING (
    supervisor_id IS NOT NULL
    AND public.current_user_can_access_supervisor(supervisor_id)
  );

REVOKE ALL ON public.supervisor_members FROM anon;
REVOKE ALL ON public.supervisor_center_invitations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.supervisor_member_invitations FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.supervisor_audit_events FROM anon;
GRANT SELECT ON public.supervisor_members TO authenticated;
GRANT SELECT ON public.supervisor_audit_events TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.supervisors
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.supervisors TO authenticated;

-- The legacy center owner policy allowed updating every center column. Restrict
-- the relationship column itself so linking cannot bypass the invitation RPC.
REVOKE INSERT, UPDATE ON public.centers FROM PUBLIC, anon, authenticated;
GRANT INSERT (name, address, type, owner_id)
  ON public.centers TO authenticated;
GRANT UPDATE (name, address, type)
  ON public.centers TO authenticated;

CREATE OR REPLACE FUNCTION public.create_supervisor_organization(p_name TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_supervisor public.supervisors%ROWTYPE;
  normalized_name TEXT := btrim(coalesce(p_name, ''));
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF char_length(normalized_name) NOT BETWEEN 3 AND 160 THEN
    RAISE EXCEPTION 'invalid_supervisor_name';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.supervisors WHERE owner_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'supervisor_already_exists';
  END IF;

  INSERT INTO public.supervisors (name, code, owner_id)
  VALUES (
    normalized_name,
    'HAL-SUP-LEGACY-' || upper(encode(gen_random_bytes(10), 'hex')),
    auth.uid()
  )
  RETURNING * INTO new_supervisor;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, actor_id, event_type
  ) VALUES (
    new_supervisor.id, auth.uid(), 'organization.created'
  );

  RETURN jsonb_build_object(
    'id', new_supervisor.id,
    'name', new_supervisor.name,
    'role', 'owner'
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_supervisors()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT coalesce(jsonb_agg(
    jsonb_build_object(
      'id', supervisor.id,
      'name', supervisor.name,
      'role', member.role
    ) ORDER BY
      CASE member.role WHEN 'owner' THEN 1 WHEN 'admin' THEN 2 ELSE 3 END,
      supervisor.name
  ), '[]'::jsonb)
  FROM public.supervisor_members AS member
  JOIN public.supervisors AS supervisor ON supervisor.id = member.supervisor_id
  WHERE member.user_id = auth.uid()
    AND member.status = 'active';
$$;

CREATE OR REPLACE FUNCTION public.create_supervisor_center_invitation(
  p_supervisor_id UUID,
  p_expires_hours INTEGER DEFAULT 72,
  p_max_uses INTEGER DEFAULT 1
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  raw_token TEXT;
  expiry TIMESTAMPTZ;
BEGIN
  IF NOT public.current_user_can_manage_supervisor(p_supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_manager_required';
  END IF;
  IF p_expires_hours NOT BETWEEN 1 AND 168
     OR p_max_uses NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'invalid_invitation_limits';
  END IF;

  raw_token := 'HAL-SUP-' || upper(encode(gen_random_bytes(18), 'hex'));
  expiry := now() + (p_expires_hours * interval '1 hour');

  INSERT INTO public.supervisor_center_invitations (
    supervisor_id, token_hash, created_by, expires_at, max_uses
  ) VALUES (
    p_supervisor_id,
    digest(raw_token, 'sha256'),
    auth.uid(),
    expiry,
    p_max_uses
  );

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, actor_id, event_type,
    metadata
  ) VALUES (
    p_supervisor_id,
    auth.uid(),
    'center_invitation.created',
    jsonb_build_object('expires_at', expiry, 'max_uses', p_max_uses)
  );

  RETURN jsonb_build_object(
    'code', raw_token,
    'expires_at', expiry,
    'max_uses', p_max_uses
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_supervisor_center_invitation(
  p_center_id UUID,
  p_code TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  invitation public.supervisor_center_invitations%ROWTYPE;
  target_center public.centers%ROWTYPE;
  supervisor_name TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  SELECT * INTO target_center
  FROM public.centers
  WHERE id = p_center_id
    AND owner_id = auth.uid()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'center_owner_required';
  END IF;

  SELECT * INTO invitation
  FROM public.supervisor_center_invitations
  WHERE token_hash = digest(upper(btrim(coalesce(p_code, ''))), 'sha256')
  FOR UPDATE;

  IF NOT FOUND
     OR invitation.revoked_at IS NOT NULL
     OR invitation.expires_at <= now()
     OR invitation.used_count >= invitation.max_uses THEN
    RAISE EXCEPTION 'invalid_or_expired_invitation';
  END IF;

  IF target_center.supervisor_id = invitation.supervisor_id THEN
    SELECT name INTO supervisor_name
    FROM public.supervisors WHERE id = invitation.supervisor_id;
    RETURN jsonb_build_object(
      'success', true,
      'already_linked', true,
      'supervisor_id', invitation.supervisor_id,
      'supervisor_name', supervisor_name
    );
  END IF;

  IF target_center.supervisor_id IS NOT NULL THEN
    RAISE EXCEPTION 'center_already_linked';
  END IF;

  UPDATE public.centers
  SET supervisor_id = invitation.supervisor_id
  WHERE id = target_center.id;

  UPDATE public.supervisor_center_invitations
  SET used_count = used_count + 1,
      last_used_at = now()
  WHERE id = invitation.id;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, center_id, actor_id, event_type
  ) VALUES (
    invitation.supervisor_id,
    target_center.id,
    auth.uid(),
    'center.linked'
  );

  SELECT name INTO supervisor_name
  FROM public.supervisors WHERE id = invitation.supervisor_id;

  RETURN jsonb_build_object(
    'success', true,
    'already_linked', false,
    'supervisor_id', invitation.supervisor_id,
    'supervisor_name', supervisor_name
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.unlink_center_from_supervisor(
  p_center_id UUID,
  p_reason TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_center public.centers%ROWTYPE;
BEGIN
  SELECT * INTO target_center
  FROM public.centers
  WHERE id = p_center_id
  FOR UPDATE;

  IF NOT FOUND OR target_center.supervisor_id IS NULL THEN
    RAISE EXCEPTION 'linked_center_not_found';
  END IF;
  IF target_center.owner_id <> auth.uid()
     AND NOT public.current_user_can_manage_supervisor(target_center.supervisor_id) THEN
    RAISE EXCEPTION 'unlink_not_allowed';
  END IF;

  UPDATE public.centers SET supervisor_id = NULL WHERE id = p_center_id;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, center_id, actor_id, event_type, metadata
  ) VALUES (
    target_center.supervisor_id,
    target_center.id,
    auth.uid(),
    'center.unlinked',
    jsonb_build_object('reason', left(btrim(coalesce(p_reason, '')), 300))
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_supervisor_member_invitation(
  p_supervisor_id UUID,
  p_email TEXT,
  p_role TEXT,
  p_expires_hours INTEGER DEFAULT 72
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  normalized_email TEXT := lower(btrim(coalesce(p_email, '')));
  raw_token TEXT;
  expiry TIMESTAMPTZ;
BEGIN
  IF NOT public.current_user_can_manage_supervisor(p_supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_manager_required';
  END IF;
  IF normalized_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
     OR p_role NOT IN ('admin', 'analyst')
     OR p_expires_hours NOT BETWEEN 1 AND 168 THEN
    RAISE EXCEPTION 'invalid_member_invitation';
  END IF;

  UPDATE public.supervisor_member_invitations
  SET revoked_at = now()
  WHERE supervisor_id = p_supervisor_id
    AND lower(email) = normalized_email
    AND used_at IS NULL
    AND revoked_at IS NULL;

  raw_token := 'HAL-TEAM-' || upper(encode(gen_random_bytes(18), 'hex'));
  expiry := now() + (p_expires_hours * interval '1 hour');

  INSERT INTO public.supervisor_member_invitations (
    supervisor_id, email, role, token_hash, created_by, expires_at
  ) VALUES (
    p_supervisor_id,
    normalized_email,
    p_role,
    digest(raw_token, 'sha256'),
    auth.uid(),
    expiry
  );

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, actor_id, event_type, metadata
  ) VALUES (
    p_supervisor_id,
    auth.uid(),
    'member_invitation.created',
    jsonb_build_object('role', p_role, 'expires_at', expiry)
  );

  RETURN jsonb_build_object(
    'code', raw_token,
    'expires_at', expiry,
    'role', p_role
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_supervisor_member_invitation(p_code TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  invitation public.supervisor_member_invitations%ROWTYPE;
  account_email TEXT;
  supervisor_name TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  SELECT lower(email) INTO account_email
  FROM auth.users WHERE id = auth.uid();

  SELECT * INTO invitation
  FROM public.supervisor_member_invitations
  WHERE token_hash = digest(upper(btrim(coalesce(p_code, ''))), 'sha256')
  FOR UPDATE;

  IF NOT FOUND
     OR invitation.used_at IS NOT NULL
     OR invitation.revoked_at IS NOT NULL
     OR invitation.expires_at <= now()
     OR lower(invitation.email) <> account_email THEN
    RAISE EXCEPTION 'invalid_or_expired_member_invitation';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.supervisor_members AS member
    WHERE member.supervisor_id = invitation.supervisor_id
      AND member.user_id = auth.uid()
      AND member.role = 'owner'
  ) THEN
    RAISE EXCEPTION 'owner_membership_is_immutable';
  END IF;

  INSERT INTO public.supervisor_members (
    supervisor_id, user_id, role, status, invited_by, joined_at
  ) VALUES (
    invitation.supervisor_id,
    auth.uid(),
    invitation.role,
    'active',
    invitation.created_by,
    now()
  )
  ON CONFLICT (supervisor_id, user_id) DO UPDATE SET
    role = EXCLUDED.role,
    status = 'active',
    invited_by = EXCLUDED.invited_by,
    joined_at = now(),
    updated_at = now();

  UPDATE public.supervisor_member_invitations
  SET used_at = now()
  WHERE id = invitation.id;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, actor_id, event_type, metadata
  ) VALUES (
    invitation.supervisor_id,
    auth.uid(),
    'member.joined',
    jsonb_build_object('role', invitation.role)
  );

  SELECT name INTO supervisor_name
  FROM public.supervisors WHERE id = invitation.supervisor_id;

  RETURN jsonb_build_object(
    'success', true,
    'supervisor_id', invitation.supervisor_id,
    'supervisor_name', supervisor_name,
    'role', invitation.role
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_supervisor_members(p_supervisor_id UUID)
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN NOT public.current_user_can_manage_supervisor(p_supervisor_id)
      THEN '[]'::jsonb
    ELSE coalesce((
      SELECT jsonb_agg(jsonb_build_object(
        'user_id', member.user_id,
        'full_name', coalesce(profile.full_name, 'عضو الفريق'),
        'email', account.email,
        'role', member.role,
        'status', member.status,
        'joined_at', member.joined_at
      ) ORDER BY
        CASE member.role WHEN 'owner' THEN 1 WHEN 'admin' THEN 2 ELSE 3 END,
        coalesce(profile.full_name, account.email))
      FROM public.supervisor_members AS member
      LEFT JOIN public.profiles AS profile ON profile.id = member.user_id
      LEFT JOIN auth.users AS account ON account.id = member.user_id
      WHERE member.supervisor_id = p_supervisor_id
    ), '[]'::jsonb)
  END;
$$;

CREATE OR REPLACE FUNCTION public.update_supervisor_member(
  p_supervisor_id UUID,
  p_user_id UUID,
  p_role TEXT,
  p_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  existing_role TEXT;
BEGIN
  IF NOT public.current_user_can_manage_supervisor(p_supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_manager_required';
  END IF;
  IF p_role NOT IN ('admin', 'analyst')
     OR p_status NOT IN ('active', 'revoked') THEN
    RAISE EXCEPTION 'invalid_member_update';
  END IF;

  SELECT role INTO existing_role
  FROM public.supervisor_members
  WHERE supervisor_id = p_supervisor_id AND user_id = p_user_id
  FOR UPDATE;

  IF NOT FOUND OR existing_role = 'owner' THEN
    RAISE EXCEPTION 'owner_membership_is_immutable';
  END IF;

  UPDATE public.supervisor_members
  SET role = p_role,
      status = p_status,
      updated_at = now()
  WHERE supervisor_id = p_supervisor_id AND user_id = p_user_id;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, actor_id, event_type, metadata
  ) VALUES (
    p_supervisor_id,
    auth.uid(),
    'member.updated',
    jsonb_build_object('target_user_id', p_user_id, 'role', p_role, 'status', p_status)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_supervisor_dashboard(
  p_supervisor_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  caller_role TEXT;
  result JSONB;
BEGIN
  caller_role := public.current_user_supervisor_role(p_supervisor_id);
  IF caller_role NOT IN ('owner', 'admin', 'analyst') THEN
    RAISE EXCEPTION 'supervisor_access_required';
  END IF;
  IF p_start_date IS NULL OR p_end_date IS NULL
     OR p_end_date < p_start_date
     OR p_end_date - p_start_date > 366 THEN
    RAISE EXCEPTION 'invalid_dashboard_period';
  END IF;

  WITH scoped_centers AS (
    SELECT center.id, center.name, center.type, center.address
    FROM public.centers AS center
    WHERE center.supervisor_id = p_supervisor_id
  ),
  center_metrics AS (
    SELECT
      center.id,
      center.name,
      center.type,
      center.address,
      (SELECT count(*) FROM public.halaqat AS halaqa
        WHERE halaqa.center_id = center.id)::INTEGER AS halaqat_count,
      (SELECT count(*) FROM public.students AS student
        WHERE student.center_id = center.id
          AND student.status = 'active')::INTEGER AS active_students,
      (SELECT count(*) FROM public.attendance AS attendance_row
        WHERE attendance_row.center_id = center.id
          AND attendance_row.date BETWEEN p_start_date AND p_end_date)::INTEGER
        AS attendance_records,
      (SELECT count(*) FROM public.attendance AS attendance_row
        WHERE attendance_row.center_id = center.id
          AND attendance_row.date BETWEEN p_start_date AND p_end_date
          AND attendance_row.status IN ('present', 'late'))::INTEGER
        AS attended_records,
      (SELECT count(*) FROM public.attendance AS attendance_row
        WHERE attendance_row.center_id = center.id
          AND attendance_row.date BETWEEN p_start_date AND p_end_date
          AND attendance_row.status = 'absent')::INTEGER AS absent_records,
      (SELECT count(*) FROM public.attendance AS attendance_row
        WHERE attendance_row.center_id = center.id
          AND attendance_row.date BETWEEN p_start_date AND p_end_date
          AND attendance_row.status = 'excused')::INTEGER AS excused_records,
      (SELECT count(*) FROM public.memorization AS recitation
        WHERE recitation.center_id = center.id
          AND recitation.date BETWEEN p_start_date AND p_end_date
          AND recitation.session_type = 'new'
          AND recitation.deleted_at IS NULL)::INTEGER AS new_sessions,
      coalesce((SELECT sum(greatest(
          coalesce(recitation.to_ayah, 0) - coalesce(recitation.from_ayah, 0) + 1,
          0
        ))
        FROM public.memorization AS recitation
        WHERE recitation.center_id = center.id
          AND recitation.date BETWEEN p_start_date AND p_end_date
          AND recitation.session_type = 'new'
          AND recitation.deleted_at IS NULL), 0)::INTEGER AS new_ayahs,
      (SELECT count(*) FROM public.memorization AS recitation
        WHERE recitation.center_id = center.id
          AND recitation.date BETWEEN p_start_date AND p_end_date
          AND recitation.session_type = 'review'
          AND recitation.deleted_at IS NULL)::INTEGER AS review_sessions,
      coalesce((SELECT sum(greatest(
          coalesce(recitation.to_ayah, 0) - coalesce(recitation.from_ayah, 0) + 1,
          0
        ))
        FROM public.memorization AS recitation
        WHERE recitation.center_id = center.id
          AND recitation.date BETWEEN p_start_date AND p_end_date
          AND recitation.session_type = 'review'
          AND recitation.deleted_at IS NULL), 0)::INTEGER AS review_ayahs,
      coalesce((SELECT sum(abs(point.amount))
        FROM public.points AS point
        WHERE point.center_id = center.id
          AND point.date BETWEEN p_start_date AND p_end_date
          AND point.type = 'positive'), 0)::INTEGER AS positive_points,
      coalesce((SELECT sum(abs(point.amount))
        FROM public.points AS point
        WHERE point.center_id = center.id
          AND point.date BETWEEN p_start_date AND p_end_date
          AND point.type = 'negative'), 0)::INTEGER AS negative_points
    FROM scoped_centers AS center
  ),
  center_payload AS (
    SELECT
      metric.*,
      CASE WHEN metric.attendance_records = 0 THEN 0
        ELSE round(metric.attended_records * 100.0 / metric.attendance_records)
      END::INTEGER AS attendance_rate
    FROM center_metrics AS metric
  ),
  totals AS (
    SELECT
      count(*)::INTEGER AS centers_count,
      coalesce(sum(halaqat_count), 0)::INTEGER AS halaqat_count,
      coalesce(sum(active_students), 0)::INTEGER AS active_students,
      coalesce(sum(attendance_records), 0)::INTEGER AS attendance_records,
      coalesce(sum(attended_records), 0)::INTEGER AS attended_records,
      coalesce(sum(absent_records), 0)::INTEGER AS absent_records,
      coalesce(sum(excused_records), 0)::INTEGER AS excused_records,
      coalesce(sum(new_sessions), 0)::INTEGER AS new_sessions,
      coalesce(sum(new_ayahs), 0)::INTEGER AS new_ayahs,
      coalesce(sum(review_sessions), 0)::INTEGER AS review_sessions,
      coalesce(sum(review_ayahs), 0)::INTEGER AS review_ayahs,
      coalesce(sum(positive_points), 0)::INTEGER AS positive_points,
      coalesce(sum(negative_points), 0)::INTEGER AS negative_points
    FROM center_payload
  )
  SELECT jsonb_build_object(
    'supervisor', jsonb_build_object(
      'id', supervisor.id,
      'name', supervisor.name,
      'role', caller_role
    ),
    'period', jsonb_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date
    ),
    'totals', jsonb_build_object(
      'centers_count', totals.centers_count,
      'halaqat_count', totals.halaqat_count,
      'active_students', totals.active_students,
      'attendance_records', totals.attendance_records,
      'attended_records', totals.attended_records,
      'attendance_rate', CASE WHEN totals.attendance_records = 0 THEN 0
        ELSE round(totals.attended_records * 100.0 / totals.attendance_records)
      END::INTEGER,
      'absent_records', totals.absent_records,
      'excused_records', totals.excused_records,
      'new_sessions', totals.new_sessions,
      'new_ayahs', totals.new_ayahs,
      'review_sessions', totals.review_sessions,
      'review_ayahs', totals.review_ayahs,
      'positive_points', totals.positive_points,
      'negative_points', totals.negative_points
    ),
    'centers', coalesce((
      SELECT jsonb_agg(to_jsonb(center_payload) ORDER BY center_payload.name)
      FROM center_payload
    ), '[]'::jsonb)
  ) INTO result
  FROM public.supervisors AS supervisor
  CROSS JOIN totals
  WHERE supervisor.id = p_supervisor_id;

  IF result IS NULL THEN
    RAISE EXCEPTION 'supervisor_not_found';
  END IF;
  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.create_supervisor_organization(TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_my_supervisors()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_supervisor_center_invitation(UUID, INTEGER, INTEGER)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_supervisor_center_invitation(UUID, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.unlink_center_from_supervisor(UUID, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.create_supervisor_member_invitation(UUID, TEXT, TEXT, INTEGER)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.accept_supervisor_member_invitation(TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_supervisor_members(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.update_supervisor_member(UUID, UUID, TEXT, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_supervisor_dashboard(UUID, DATE, DATE)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_supervisor_organization(TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_supervisors()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_supervisor_center_invitation(UUID, INTEGER, INTEGER)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_supervisor_center_invitation(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.unlink_center_from_supervisor(UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_supervisor_member_invitation(UUID, TEXT, TEXT, INTEGER)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.accept_supervisor_member_invitation(TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_supervisor_members(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_supervisor_member(UUID, UUID, TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_supervisor_dashboard(UUID, DATE, DATE)
  TO authenticated;

COMMIT;
