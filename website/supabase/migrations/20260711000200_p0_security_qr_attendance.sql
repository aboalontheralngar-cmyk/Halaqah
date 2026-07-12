-- P0 security hardening: single-use invitations, scoped RLS, opaque QR tokens,
-- and one attendance record per student/day.
-- Apply only after taking a backup and testing on a staging project.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

ALTER TABLE public.center_members
  ADD COLUMN IF NOT EXISTS invitation_code TEXT,
  ADD COLUMN IF NOT EXISTS invitation_expires_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS invitation_used_at TIMESTAMPTZ;

UPDATE public.center_members
SET invitation_expires_at = COALESCE(invitation_expires_at, created_at + INTERVAL '14 days')
WHERE invitation_code IS NOT NULL AND user_id IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_center_members_invitation_code
  ON public.center_members(invitation_code)
  WHERE invitation_code IS NOT NULL;

-- Legacy RPCs trusted a user id supplied by the client or disclosed invite data.
DROP FUNCTION IF EXISTS public.get_member_by_code(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.activate_member_by_code(TEXT, UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.inspect_invitation_code(
  p_code TEXT,
  p_email TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member public.center_members%ROWTYPE;
  v_registered BOOLEAN := FALSE;
BEGIN
  SELECT * INTO v_member
  FROM public.center_members
  WHERE invitation_code = upper(trim(p_code))
    AND lower(email) = lower(trim(p_email))
    AND user_id IS NULL
    AND invitation_used_at IS NULL
    AND COALESCE(invitation_expires_at, '-infinity'::timestamptz) > now()
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('valid', false);
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM auth.users WHERE lower(email) = lower(trim(p_email))
  ) INTO v_registered;

  RETURN json_build_object(
    'valid', true,
    'role', v_member.role,
    'is_registered', v_registered,
    'expires_at', v_member.invitation_expires_at
  );
END;
$$;

REVOKE ALL ON FUNCTION public.inspect_invitation_code(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.inspect_invitation_code(TEXT, TEXT) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.join_center_with_code(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_member public.center_members%ROWTYPE;
  v_email TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();
  SELECT * INTO v_member
  FROM public.center_members
  WHERE invitation_code = upper(trim(p_code))
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'invalid_code');
  END IF;
  IF v_member.invitation_used_at IS NOT NULL OR v_member.user_id IS NOT NULL THEN
    RETURN json_build_object('success', false, 'error', 'already_used');
  END IF;
  IF COALESCE(v_member.invitation_expires_at, '-infinity'::timestamptz) <= now() THEN
    RETURN json_build_object('success', false, 'error', 'expired_code');
  END IF;
  IF lower(v_member.email) <> lower(v_email) THEN
    RETURN json_build_object('success', false, 'error', 'email_mismatch');
  END IF;

  UPDATE public.center_members
  SET user_id = auth.uid(),
      invitation_used_at = now(),
      invitation_code = NULL
  WHERE id = v_member.id;

  UPDATE public.profiles SET role = 'teacher' WHERE id = auth.uid();

  RETURN json_build_object(
    'success', true,
    'center_id', v_member.center_id,
    'halaqah_id', v_member.halaqah_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.join_center_with_code(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_center_with_code(TEXT) TO authenticated;

-- QR tokens identify a student; they are not authorization credentials.
ALTER TABLE public.students ADD COLUMN IF NOT EXISTS qr_code TEXT;
UPDATE public.students
SET qr_code = gen_random_uuid()::text
WHERE qr_code IS NULL OR trim(qr_code) = '';
ALTER TABLE public.students ALTER COLUMN qr_code SET NOT NULL;
ALTER TABLE public.students ALTER COLUMN qr_code SET DEFAULT gen_random_uuid()::text;
CREATE UNIQUE INDEX IF NOT EXISTS uq_students_qr_code ON public.students(qr_code);

-- Preserve the newest old attendance row, then enforce one row per day.
DELETE FROM public.attendance older
USING public.attendance newer
WHERE older.student_id = newer.student_id
  AND older.date = newer.date
  AND (older.created_at, older.id) < (newer.created_at, newer.id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_student_date
  ON public.attendance(student_id, date);

-- Derive scope from the student so clients cannot forge center/halaqah ids.
CREATE OR REPLACE FUNCTION public.set_student_scoped_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_center_id UUID;
  v_halaqa_id UUID;
BEGIN
  SELECT center_id, halaqa_id INTO v_center_id, v_halaqa_id
  FROM public.students WHERE id = NEW.student_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;
  NEW.center_id := v_center_id;
  IF to_jsonb(NEW) ? 'halaqa_id' THEN
    NEW.halaqa_id := v_halaqa_id;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY['attendance', 'memorization', 'points', 'vacations']
  LOOP
    IF to_regclass('public.' || t) IS NOT NULL THEN
      EXECUTE format('DROP TRIGGER IF EXISTS set_%I_student_scope ON public.%I', t, t);
      EXECUTE format(
        'CREATE TRIGGER set_%I_student_scope BEFORE INSERT OR UPDATE OF student_id ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_student_scoped_row()',
        t,
        t
      );
    END IF;
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.set_student_scoped_row() FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.centers c
      WHERE c.id = p_center_id AND c.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.center_members cm
      WHERE cm.center_id = p_center_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.centers c
      JOIN public.supervisors supervisor ON supervisor.id = c.supervisor_id
      WHERE c.id = p_center_id
        AND supervisor.owner_id = auth.uid()
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
      SELECT 1 FROM public.center_members cm
      WHERE cm.center_id = p_center_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'teacher'
        AND cm.halaqah_id = p_halaqa_id
    );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_access_student(p_student_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.students s
    WHERE s.id = p_student_id
      AND public.current_user_can_access_halaqa(s.center_id, s.halaqa_id)
  );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_student(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_student(UUID) TO authenticated;

ALTER TABLE public.centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.center_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memorization ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vacations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS centers_select ON public.centers;
DROP POLICY IF EXISTS "Members can view their center" ON public.centers;
CREATE POLICY centers_select ON public.centers FOR SELECT USING (
  owner_id = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.center_members cm
    WHERE cm.center_id = centers.id AND cm.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS cm_owner_all ON public.center_members;
DROP POLICY IF EXISTS cm_member_select ON public.center_members;
DROP POLICY IF EXISTS cm_admin_all ON public.center_members;
DROP POLICY IF EXISTS "Owner manages members" ON public.center_members;
DROP POLICY IF EXISTS "Member views own rows" ON public.center_members;
DROP POLICY IF EXISTS "Allow select center_members by user or email" ON public.center_members;
DROP POLICY IF EXISTS "Manage center members" ON public.center_members;
CREATE POLICY cm_admin_all ON public.center_members FOR ALL
  USING (public.current_user_is_center_admin(center_id))
  WITH CHECK (public.current_user_is_center_admin(center_id));
CREATE POLICY cm_member_select ON public.center_members FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS halaqat_access ON public.halaqat;
DROP POLICY IF EXISTS halaqat_select ON public.halaqat;
DROP POLICY IF EXISTS halaqat_admin_write ON public.halaqat;
DROP POLICY IF EXISTS "Access halaqat by center_id" ON public.halaqat;
CREATE POLICY halaqat_select ON public.halaqat FOR SELECT
  USING (public.current_user_can_access_halaqa(center_id, id));
CREATE POLICY halaqat_admin_write ON public.halaqat FOR ALL
  USING (public.current_user_is_center_admin(center_id))
  WITH CHECK (public.current_user_is_center_admin(center_id));

DROP POLICY IF EXISTS students_access ON public.students;
DROP POLICY IF EXISTS students_scoped_access ON public.students;
DROP POLICY IF EXISTS "Access students by center_id" ON public.students;
CREATE POLICY students_scoped_access ON public.students FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS attendance_access ON public.attendance;
DROP POLICY IF EXISTS attendance_scoped_access ON public.attendance;
DROP POLICY IF EXISTS "Access attendance by center_id" ON public.attendance;
CREATE POLICY attendance_scoped_access ON public.attendance FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

DROP POLICY IF EXISTS memorization_access ON public.memorization;
DROP POLICY IF EXISTS memorization_scoped_access ON public.memorization;
DROP POLICY IF EXISTS "Access memorization by center_id" ON public.memorization;
CREATE POLICY memorization_scoped_access ON public.memorization FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

DROP POLICY IF EXISTS points_access ON public.points;
DROP POLICY IF EXISTS points_scoped_access ON public.points;
DROP POLICY IF EXISTS "Access points by center_id" ON public.points;
CREATE POLICY points_scoped_access ON public.points FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

ALTER TABLE public.exams ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL;
DROP POLICY IF EXISTS exams_access ON public.exams;
DROP POLICY IF EXISTS exams_scoped_access ON public.exams;
DROP POLICY IF EXISTS "Access exams by center_id" ON public.exams;
CREATE POLICY exams_scoped_access ON public.exams FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS exam_scores_access ON public.exam_scores;
DROP POLICY IF EXISTS exam_scores_scoped_access ON public.exam_scores;
DROP POLICY IF EXISTS "Access exam_scores by center_id" ON public.exam_scores;
CREATE POLICY exam_scores_scoped_access ON public.exam_scores FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.exams e
    WHERE e.id = exam_scores.exam_id
      AND public.current_user_can_access_halaqa(e.center_id, e.halaqa_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.exams e
    WHERE e.id = exam_scores.exam_id
      AND public.current_user_can_access_halaqa(e.center_id, e.halaqa_id)
  ));

DROP POLICY IF EXISTS vacations_access ON public.vacations;
DROP POLICY IF EXISTS vacations_scoped_access ON public.vacations;
DROP POLICY IF EXISTS "Access vacations by center_id" ON public.vacations;
CREATE POLICY vacations_scoped_access ON public.vacations FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

DROP POLICY IF EXISTS activities_access ON public.activities;
DROP POLICY IF EXISTS activities_admin_access ON public.activities;
DROP POLICY IF EXISTS "Access activities by center_id" ON public.activities;
CREATE POLICY activities_admin_access ON public.activities FOR ALL
  USING (public.current_user_is_center_admin(center_id))
  WITH CHECK (public.current_user_is_center_admin(center_id));

COMMIT;
