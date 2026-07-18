-- P7.2.1: secure family/guardian portal with multi-child switching.
-- Copy this file's CONTENTS into Supabase SQL Editor after P7.2.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Keep the migration self-contained for projects that pasted earlier SQL files
-- partially or in a different order.
CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, extensions, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.centers center_row
      WHERE center_row.id = p_center_id
        AND center_row.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.center_members member_row
      WHERE member_row.center_id = p_center_id
        AND member_row.user_id = auth.uid()
        AND member_row.role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.centers center_row
      JOIN public.supervisors supervisor_row
        ON supervisor_row.id = center_row.supervisor_id
      WHERE center_row.id = p_center_id
        AND supervisor_row.owner_id = auth.uid()
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
SET search_path = public, extensions, pg_temp
AS $$
  SELECT public.current_user_is_center_admin(p_center_id)
    OR EXISTS (
      SELECT 1 FROM public.center_members member_row
      WHERE member_row.center_id = p_center_id
        AND member_row.user_id = auth.uid()
        AND member_row.role = 'teacher'
        AND p_halaqa_id IS NOT NULL
        AND member_row.halaqah_id = p_halaqa_id
    );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.generate_family_portal_code()
RETURNS TEXT
LANGUAGE sql
VOLATILE
SET search_path = public, extensions, pg_temp
AS $$
  SELECT upper(encode(gen_random_bytes(10), 'hex'));
$$;

ALTER TABLE public.families
  ADD COLUMN IF NOT EXISTS family_code TEXT;

UPDATE public.families
SET family_code = public.generate_family_portal_code()
WHERE family_code IS NULL OR family_code !~ '^[A-F0-9]{20}$';

ALTER TABLE public.families
  ALTER COLUMN family_code SET DEFAULT public.generate_family_portal_code(),
  ALTER COLUMN family_code SET NOT NULL;

ALTER TABLE public.families
  DROP CONSTRAINT IF EXISTS families_family_code_format;
ALTER TABLE public.families
  ADD CONSTRAINT families_family_code_format
  CHECK (family_code ~ '^[A-F0-9]{20}$');

CREATE UNIQUE INDEX IF NOT EXISTS idx_families_family_code
  ON public.families(family_code);

CREATE OR REPLACE FUNCTION public.prepare_family_portal_identity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    -- Codes are server-generated. A client cannot choose a predictable code.
    NEW.family_code := public.generate_family_portal_code();
  ELSIF NEW.family_code IS DISTINCT FROM OLD.family_code THEN
    -- The public identifier is stable across edits and synchronizations.
    NEW.family_code := OLD.family_code;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_family_portal_identity ON public.families;
CREATE TRIGGER prepare_family_portal_identity
  BEFORE INSERT OR UPDATE ON public.families
  FOR EACH ROW EXECUTE FUNCTION public.prepare_family_portal_identity();

CREATE TABLE IF NOT EXISTS public.family_portal_credentials (
  family_id UUID PRIMARY KEY REFERENCES public.families(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  pin_hash TEXT NOT NULL,
  enabled BOOLEAN NOT NULL DEFAULT true,
  failed_attempts INTEGER NOT NULL DEFAULT 0 CHECK (failed_attempts >= 0),
  locked_until TIMESTAMPTZ,
  pin_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.family_portal_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  token_hash BYTEA NOT NULL UNIQUE,
  client_fingerprint_hash BYTEA NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  revoked_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.family_portal_login_attempts (
  subject_hash BYTEA NOT NULL,
  client_fingerprint_hash BYTEA NOT NULL,
  failure_count INTEGER NOT NULL DEFAULT 0 CHECK (failure_count >= 0),
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  blocked_until TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (subject_hash, client_fingerprint_hash)
);

CREATE INDEX IF NOT EXISTS idx_family_portal_sessions_active
  ON public.family_portal_sessions(family_id, expires_at DESC)
  WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_family_portal_attempts_cleanup
  ON public.family_portal_login_attempts(updated_at);

CREATE OR REPLACE FUNCTION public.prepare_family_portal_credential()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = NEW.family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'family_not_found';
  END IF;

  NEW.center_id := target_family.center_id;
  NEW.halaqa_id := target_family.halaqa_id;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_family_portal_credential
  ON public.family_portal_credentials;
CREATE TRIGGER prepare_family_portal_credential
  BEFORE INSERT OR UPDATE OF family_id, center_id, halaqa_id, enabled, pin_hash
  ON public.family_portal_credentials
  FOR EACH ROW EXECUTE FUNCTION public.prepare_family_portal_credential();

CREATE OR REPLACE FUNCTION public.set_family_portal_pin(
  p_family_id UUID,
  p_pin TEXT,
  p_enabled BOOLEAN DEFAULT true
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id,
    target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  IF p_pin IS NULL OR p_pin !~ '^[0-9]{6}$' THEN
    RAISE EXCEPTION 'pin_must_be_six_digits';
  END IF;

  INSERT INTO public.family_portal_credentials (
    family_id,
    center_id,
    halaqa_id,
    pin_hash,
    enabled,
    failed_attempts,
    locked_until,
    pin_changed_at,
    created_by
  ) VALUES (
    target_family.id,
    target_family.center_id,
    target_family.halaqa_id,
    crypt(p_pin, gen_salt('bf', 12)),
    p_enabled,
    0,
    NULL,
    now(),
    auth.uid()
  )
  ON CONFLICT (family_id) DO UPDATE SET
    pin_hash = EXCLUDED.pin_hash,
    enabled = EXCLUDED.enabled,
    failed_attempts = 0,
    locked_until = NULL,
    pin_changed_at = now(),
    created_by = auth.uid(),
    updated_at = now();

  UPDATE public.family_portal_sessions
  SET revoked_at = now()
  WHERE family_id = p_family_id AND revoked_at IS NULL;

  RETURN jsonb_build_object(
    'configured', true,
    'enabled', p_enabled,
    'family_code', target_family.family_code,
    'pin_changed_at', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.disable_family_portal(p_family_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id;

  IF auth.uid() IS NULL OR NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id,
    target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  UPDATE public.family_portal_credentials
  SET enabled = false,
      failed_attempts = 0,
      locked_until = NULL,
      updated_at = now()
  WHERE family_id = p_family_id;

  UPDATE public.family_portal_sessions
  SET revoked_at = now()
  WHERE family_id = p_family_id AND revoked_at IS NULL;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_family_portal_status(p_family_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  credential public.family_portal_credentials%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id;

  IF auth.uid() IS NULL OR NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id,
    target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  SELECT * INTO credential
  FROM public.family_portal_credentials
  WHERE family_id = p_family_id;

  RETURN jsonb_build_object(
    'configured', FOUND,
    'enabled', COALESCE(credential.enabled, false),
    'family_code', target_family.family_code,
    'active_students', (
      SELECT COUNT(*) FROM public.students student
      WHERE student.family_id = target_family.id AND student.status = 'active'
    ),
    'locked_until', credential.locked_until,
    'pin_changed_at', credential.pin_changed_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.record_family_portal_failure(
  p_subject_hash BYTEA,
  p_client_hash BYTEA
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  INSERT INTO public.family_portal_login_attempts (
    subject_hash,
    client_fingerprint_hash,
    failure_count,
    window_started_at,
    blocked_until,
    updated_at
  ) VALUES (
    p_subject_hash,
    p_client_hash,
    1,
    now(),
    NULL,
    now()
  )
  ON CONFLICT (subject_hash, client_fingerprint_hash) DO UPDATE SET
    failure_count = CASE
      WHEN public.family_portal_login_attempts.window_started_at < now() - interval '15 minutes'
        THEN 1
      ELSE public.family_portal_login_attempts.failure_count + 1
    END,
    window_started_at = CASE
      WHEN public.family_portal_login_attempts.window_started_at < now() - interval '15 minutes'
        THEN now()
      ELSE public.family_portal_login_attempts.window_started_at
    END,
    blocked_until = CASE
      WHEN (
        CASE
          WHEN public.family_portal_login_attempts.window_started_at < now() - interval '15 minutes'
            THEN 1
          ELSE public.family_portal_login_attempts.failure_count + 1
        END
      ) >= 5 THEN now() + interval '15 minutes'
      ELSE public.family_portal_login_attempts.blocked_until
    END,
    updated_at = now();
END;
$$;

CREATE OR REPLACE FUNCTION public.family_portal_authenticate(
  p_family_code TEXT,
  p_pin TEXT,
  p_client_fingerprint TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  normalized_code TEXT;
  v_subject_hash BYTEA;
  v_client_hash BYTEA;
  attempt public.family_portal_login_attempts%ROWTYPE;
  target_family public.families%ROWTYPE;
  credential public.family_portal_credentials%ROWTYPE;
  raw_token TEXT;
  session_expiry TIMESTAMPTZ;
BEGIN
  normalized_code := upper(regexp_replace(
    regexp_replace(COALESCE(p_family_code, ''), '^FAM-', '', 'i'),
    '[^A-Za-z0-9]',
    '',
    'g'
  ));
  v_subject_hash := digest(normalized_code, 'sha256');
  v_client_hash := digest(COALESCE(NULLIF(p_client_fingerprint, ''), 'unknown'), 'sha256');

  DELETE FROM public.family_portal_sessions
  WHERE expires_at < now() - interval '1 day' OR revoked_at < now() - interval '7 days';
  DELETE FROM public.family_portal_login_attempts
  WHERE updated_at < now() - interval '2 days';

  SELECT * INTO attempt
  FROM public.family_portal_login_attempts login_attempt
  WHERE login_attempt.subject_hash = v_subject_hash
    AND login_attempt.client_fingerprint_hash = v_client_hash
  FOR UPDATE;

  IF FOUND AND attempt.blocked_until IS NOT NULL AND attempt.blocked_until > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rate_limited');
  END IF;

  IF normalized_code !~ '^[A-F0-9]{20}$' OR COALESCE(p_pin, '') !~ '^[0-9]{6}$' THEN
    PERFORM crypt(COALESCE(p_pin, ''), gen_salt('bf', 12));
    PERFORM public.record_family_portal_failure(v_subject_hash, v_client_hash);
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  SELECT * INTO target_family
  FROM public.families family_row
  WHERE family_row.family_code = normalized_code
    AND EXISTS (
      SELECT 1 FROM public.students student
      WHERE student.family_id = family_row.id AND student.status = 'active'
    );

  IF NOT FOUND THEN
    PERFORM crypt(p_pin, gen_salt('bf', 12));
    PERFORM public.record_family_portal_failure(v_subject_hash, v_client_hash);
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  SELECT * INTO credential
  FROM public.family_portal_credentials
  WHERE family_id = target_family.id
  FOR UPDATE;

  IF NOT FOUND OR NOT credential.enabled THEN
    PERFORM crypt(p_pin, gen_salt('bf', 12));
    PERFORM public.record_family_portal_failure(v_subject_hash, v_client_hash);
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  IF credential.locked_until IS NOT NULL AND credential.locked_until > now() THEN
    RETURN jsonb_build_object('ok', false, 'error', 'rate_limited');
  END IF;

  IF crypt(p_pin, credential.pin_hash) <> credential.pin_hash THEN
    UPDATE public.family_portal_credentials
    SET failed_attempts = credential.failed_attempts + 1,
        locked_until = CASE
          WHEN credential.failed_attempts + 1 >= 10
            THEN now() + interval '30 minutes'
          ELSE NULL
        END,
        updated_at = now()
    WHERE family_id = target_family.id;
    PERFORM public.record_family_portal_failure(v_subject_hash, v_client_hash);
    RETURN jsonb_build_object('ok', false, 'error', 'invalid_credentials');
  END IF;

  DELETE FROM public.family_portal_login_attempts
  WHERE subject_hash = v_subject_hash
    AND client_fingerprint_hash = v_client_hash;

  UPDATE public.family_portal_credentials
  SET failed_attempts = 0,
      locked_until = NULL,
      updated_at = now()
  WHERE family_id = target_family.id;

  raw_token := encode(gen_random_bytes(32), 'hex');
  session_expiry := now() + interval '12 hours';

  INSERT INTO public.family_portal_sessions (
    family_id,
    token_hash,
    client_fingerprint_hash,
    expires_at
  ) VALUES (
    target_family.id,
    digest(raw_token, 'sha256'),
    v_client_hash,
    session_expiry
  );

  RETURN jsonb_build_object(
    'ok', true,
    'session_token', raw_token,
    'expires_at', session_expiry
  );
END;
$$;

-- A private builder shared by student and family sessions. It keeps both
-- portal modes on exactly the same reporting contract.
CREATE OR REPLACE FUNCTION public.build_student_portal_dashboard(
  p_student_id UUID,
  p_days INTEGER,
  p_session_expires TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_student public.students%ROWTYPE;
  result JSONB;
  report_days INTEGER;
BEGIN
  report_days := GREATEST(7, LEAST(COALESCE(p_days, 30), 366));

  SELECT * INTO target_student
  FROM public.students
  WHERE id = p_student_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_available';
  END IF;

  SELECT jsonb_build_object(
    'session_expires_at', p_session_expires,
    'period_days', report_days,
    'student', jsonb_build_object(
      'name', target_student.name,
      'student_code', target_student.student_code,
      'level', target_student.level,
      'join_date', target_student.join_date,
      'plan_type', target_student.plan_type,
      'plan_amount', target_student.plan_amount,
      'review_plan_amount', target_student.review_plan_amount,
      'total_memorized', target_student.total_memorized
    ),
    'organization', jsonb_build_object(
      'center_name', COALESCE(center_row.name, 'المركز'),
      'halaqa_name', COALESCE(halaqa_row.name, 'الحلقة'),
      'teacher_name', halaqa_row.teacher_name
    ),
    'summary', jsonb_build_object(
      'points_balance', COALESCE((
        SELECT SUM(point.amount) FROM public.points point
        WHERE point.student_id = target_student.id
      ), 0),
      'attendance', jsonb_build_object(
        'present', (SELECT COUNT(*) FROM public.attendance attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'present'),
        'late', (SELECT COUNT(*) FROM public.attendance attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'late'),
        'absent', (SELECT COUNT(*) FROM public.attendance attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'absent'),
        'excused', (SELECT COUNT(*) FROM public.attendance attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'excused')
      )
    ),
    'active_plan', (
      SELECT jsonb_build_object(
        'period', plan.period,
        'start_date', plan.start_date,
        'end_date', plan.end_date,
        'unit', plan.unit,
        'new_amount', plan.new_amount,
        'review_amount', plan.review_amount,
        'status', plan.status,
        'test_status', plan.test_status,
        'notes', plan.notes
      )
      FROM public.plans plan
      WHERE plan.student_id = target_student.id
        AND plan.deleted_at IS NULL
        AND plan.status = 'active'
      ORDER BY plan.created_at DESC
      LIMIT 1
    ),
    'recent_memorization', COALESCE((
      SELECT jsonb_agg(to_jsonb(recent_row) ORDER BY recent_row.date DESC, recent_row.created_at DESC)
      FROM (
        SELECT
          memorization.date,
          memorization.surah,
          memorization.from_ayah,
          memorization.to_ayah,
          memorization.degree,
          memorization.session_type,
          memorization.created_at
        FROM public.memorization memorization
        WHERE memorization.student_id = target_student.id
          AND memorization.deleted_at IS NULL
          AND memorization.date >= current_date - report_days
        ORDER BY memorization.date DESC, memorization.created_at DESC
        LIMIT 30
      ) recent_row
    ), '[]'::jsonb),
    'recent_attendance', COALESCE((
      SELECT jsonb_agg(to_jsonb(attendance_row) ORDER BY attendance_row.date DESC)
      FROM (
        SELECT attendance.date, attendance.status, attendance.notes
        FROM public.attendance attendance
        WHERE attendance.student_id = target_student.id
          AND attendance.date >= current_date - report_days
        ORDER BY attendance.date DESC
        LIMIT 30
      ) attendance_row
    ), '[]'::jsonb)
  ) INTO result
  FROM public.centers center_row
  LEFT JOIN public.halaqat halaqa_row ON halaqa_row.id = target_student.halaqa_id
  WHERE center_row.id = target_student.center_id;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.student_portal_get_dashboard(
  p_session_token TEXT,
  p_days INTEGER DEFAULT 30
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  active_session public.student_portal_sessions%ROWTYPE;
BEGIN
  IF p_session_token IS NULL OR p_session_token !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  SELECT * INTO active_session
  FROM public.student_portal_sessions
  WHERE token_hash = digest(p_session_token, 'sha256')
    AND revoked_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  UPDATE public.student_portal_sessions
  SET last_seen_at = now()
  WHERE id = active_session.id;

  RETURN public.build_student_portal_dashboard(
    active_session.student_id,
    p_days,
    active_session.expires_at
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.family_portal_get_dashboard(
  p_session_token TEXT,
  p_days INTEGER DEFAULT 30,
  p_student_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  active_session public.family_portal_sessions%ROWTYPE;
  target_family public.families%ROWTYPE;
  selected_student_id UUID;
  children JSONB;
BEGIN
  IF p_session_token IS NULL OR p_session_token !~ '^[a-f0-9]{64}$' THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  SELECT * INTO active_session
  FROM public.family_portal_sessions
  WHERE token_hash = digest(p_session_token, 'sha256')
    AND revoked_at IS NULL
    AND expires_at > now()
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  UPDATE public.family_portal_sessions
  SET last_seen_at = now()
  WHERE id = active_session.id;

  SELECT * INTO target_family
  FROM public.families
  WHERE id = active_session.family_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  IF p_student_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.students student
    WHERE student.id = p_student_id
      AND student.family_id = target_family.id
      AND student.status = 'active'
  ) THEN
    selected_student_id := p_student_id;
  ELSE
    SELECT student.id INTO selected_student_id
    FROM public.students student
    WHERE student.family_id = target_family.id
      AND student.status = 'active'
    ORDER BY student.name, student.id
    LIMIT 1;
  END IF;

  IF selected_student_id IS NULL THEN
    RAISE EXCEPTION 'no_active_students';
  END IF;

  SELECT COALESCE(jsonb_agg(
    jsonb_build_object(
      'id', student.id,
      'name', student.name,
      'student_code', student.student_code,
      'level', student.level,
      'status', student.status
    ) ORDER BY student.name, student.id
  ), '[]'::jsonb)
  INTO children
  FROM public.students student
  WHERE student.family_id = target_family.id
    AND student.status = 'active';

  RETURN jsonb_build_object(
    'session_expires_at', active_session.expires_at,
    'period_days', GREATEST(7, LEAST(COALESCE(p_days, 30), 366)),
    'family', jsonb_build_object(
      'name', target_family.name,
      'family_code', target_family.family_code,
      'primary_guardian_name', (
        SELECT guardian.name FROM public.family_guardians guardian
        WHERE guardian.family_id = target_family.id AND guardian.is_primary
        LIMIT 1
      ),
      'primary_guardian_relationship', (
        SELECT guardian.relationship FROM public.family_guardians guardian
        WHERE guardian.family_id = target_family.id AND guardian.is_primary
        LIMIT 1
      )
    ),
    'students', children,
    'selected_student_id', selected_student_id,
    'student_dashboard', public.build_student_portal_dashboard(
      selected_student_id,
      p_days,
      active_session.expires_at
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.family_portal_revoke_session(p_session_token TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions, pg_temp
AS $$
BEGIN
  IF p_session_token IS NULL OR p_session_token !~ '^[a-f0-9]{64}$' THEN
    RETURN;
  END IF;

  UPDATE public.family_portal_sessions
  SET revoked_at = now()
  WHERE token_hash = digest(p_session_token, 'sha256')
    AND revoked_at IS NULL;
END;
$$;

ALTER TABLE public.family_portal_credentials ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_portal_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_portal_login_attempts ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.family_portal_credentials
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.family_portal_sessions
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON TABLE public.family_portal_login_attempts
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.generate_family_portal_code()
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.generate_family_portal_code()
  TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.prepare_family_portal_identity()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prepare_family_portal_credential()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.record_family_portal_failure(BYTEA, BYTEA)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.build_student_portal_dashboard(UUID, INTEGER, TIMESTAMPTZ)
  FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.set_family_portal_pin(UUID, TEXT, BOOLEAN)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.disable_family_portal(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_family_portal_status(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_family_portal_pin(UUID, TEXT, BOOLEAN)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.disable_family_portal(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_family_portal_status(UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.student_portal_get_dashboard(TEXT, INTEGER)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.family_portal_authenticate(TEXT, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.family_portal_get_dashboard(TEXT, INTEGER, UUID)
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.family_portal_revoke_session(TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.student_portal_get_dashboard(TEXT, INTEGER)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.family_portal_authenticate(TEXT, TEXT, TEXT)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.family_portal_get_dashboard(TEXT, INTEGER, UUID)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.family_portal_revoke_session(TEXT)
  TO service_role;

-- P7.2 may already have been installed while pgcrypto lived in Supabase's
-- `extensions` schema. Repair the runtime search path of its existing RPCs so
-- student login remains functional without asking operators to rerun P7.2.
ALTER FUNCTION public.set_student_portal_pin(UUID, TEXT, BOOLEAN)
  SET search_path = public, extensions, pg_temp;
ALTER FUNCTION public.student_portal_authenticate(TEXT, TEXT, TEXT)
  SET search_path = public, extensions, pg_temp;
ALTER FUNCTION public.student_portal_get_dashboard(TEXT, INTEGER)
  SET search_path = public, extensions, pg_temp;
ALTER FUNCTION public.student_portal_revoke_session(TEXT)
  SET search_path = public, extensions, pg_temp;

COMMENT ON COLUMN public.families.family_code IS
  'Globally unique, server-generated family portal identifier. Display with the FAM prefix.';
COMMENT ON TABLE public.family_portal_credentials IS
  'Family portal PIN hashes only. Plain PIN values must never be stored or logged.';
COMMENT ON TABLE public.family_portal_sessions IS
  'Short-lived family portal sessions. Only SHA-256 token hashes are stored.';

COMMIT;
