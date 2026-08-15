-- P1.26 guarded base-scope bootstrap.
-- RUN ONLY when P1.26_SUPABASE_DEEP_AUDIT.sql says:
-- EMPTY_PROJECT_READY_FOR_GUARDED_BASE_BOOTSTRAP
--
-- This script is intentionally conservative. If ANY Halaqah application table
-- already exists it aborts before making a change. It does not delete rows or
-- replace identifiers.

BEGIN;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$
DECLARE
  existing_count INTEGER;
  existing_names TEXT;
BEGIN
  WITH expected(name) AS (
    VALUES
      ('profiles'),('supervisors'),('centers'),('halaqat'),('center_members'),
      ('families'),('family_guardians'),('students'),('attendance'),
      ('memorization'),('points'),('exams'),('exam_scores'),('vacations'),
      ('fund_transactions'),('notifications'),('plans'),('student_holds'),
      ('talaqqin_records'),('student_admin_actions'),('quran_courses'),
      ('quran_course_enrollments'),('center_settings'),('study_suspensions'),
      ('daily_closings'),('mushaf_progress'),('homework_grades'),
      ('plan_recitation_records'),('daily_achievements')
  ), present AS (
    SELECT name FROM expected
    WHERE to_regclass(format('public.%I', name)) IS NOT NULL
  )
  SELECT COUNT(*), string_agg(name, ', ' ORDER BY name)
  INTO existing_count, existing_names
  FROM present;

  IF existing_count > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.26_BOOTSTRAP_BLOCKED_EXISTING_APP_TABLES',
      DETAIL = COALESCE(existing_names, ''),
      HINT = 'Do not bootstrap over a partial/legacy deployment. Send the P1.26 deep-audit output instead.';
  END IF;
END;
$$;

CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  role TEXT NOT NULL DEFAULT 'center_admin'
    CHECK (role IN ('supervisor', 'center_admin', 'teacher')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.supervisors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  code TEXT UNIQUE NOT NULL DEFAULT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12)),
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.centers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  address TEXT,
  type TEXT NOT NULL DEFAULT 'men' CHECK (type IN ('men', 'women', 'mixed')),
  supervisor_id UUID REFERENCES public.supervisors(id) ON DELETE SET NULL,
  owner_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.halaqat (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  teacher_name TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.center_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'teacher' CHECK (role IN ('admin', 'teacher')),
  halaqah_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(center_id, email)
);

CREATE TABLE public.families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  reference_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE public.family_guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  phone TEXT NOT NULL CHECK (NULLIF(BTRIM(phone), '') IS NOT NULL),
  email TEXT,
  relationship TEXT NOT NULL DEFAULT 'guardian'
    CHECK (relationship IN ('father','mother','brother','grandfather','uncle','guardian','other')),
  is_primary BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_halaqat_center ON public.halaqat(center_id, name);
CREATE INDEX idx_center_members_user ON public.center_members(user_id, center_id);
CREATE INDEX idx_center_members_halaqa ON public.center_members(halaqah_id, user_id);
CREATE INDEX idx_families_scope ON public.families(center_id, halaqa_id, name);
CREATE UNIQUE INDEX uq_family_primary_guardian
  ON public.family_guardians(family_id) WHERE is_primary;

CREATE OR REPLACE FUNCTION public.current_user_owns_center(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.centers c
    WHERE c.id = p_center_id AND c.owner_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_center_member(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.center_members cm
    WHERE cm.center_id = p_center_id AND cm.user_id = auth.uid()
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    public.current_user_owns_center(p_center_id)
    OR EXISTS (
      SELECT 1 FROM public.center_members cm
      WHERE cm.center_id = p_center_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.centers c
      JOIN public.supervisors s ON s.id = c.supervisor_id
      WHERE c.id = p_center_id AND s.owner_id = auth.uid()
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

REVOKE ALL ON FUNCTION public.current_user_owns_center(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_is_center_member(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_owns_center(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_member(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) TO authenticated;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.centers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.halaqat ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.center_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_guardians ENABLE ROW LEVEL SECURITY;

CREATE POLICY profiles_self_select ON public.profiles FOR SELECT TO authenticated
  USING (id = auth.uid());
CREATE POLICY profiles_self_insert ON public.profiles FOR INSERT TO authenticated
  WITH CHECK (id = auth.uid());
CREATE POLICY profiles_self_update ON public.profiles FOR UPDATE TO authenticated
  USING (id = auth.uid()) WITH CHECK (id = auth.uid());

CREATE POLICY supervisors_owner_access ON public.supervisors FOR ALL TO authenticated
  USING (owner_id = auth.uid()) WITH CHECK (owner_id = auth.uid());

CREATE POLICY centers_select_access ON public.centers FOR SELECT TO authenticated
  USING (
    owner_id = auth.uid()
    OR public.current_user_is_center_member(id)
    OR (supervisor_id IS NOT NULL AND EXISTS (
      SELECT 1 FROM public.supervisors s
      WHERE s.id = supervisor_id AND s.owner_id = auth.uid()
    ))
  );
CREATE POLICY centers_insert_owner ON public.centers FOR INSERT TO authenticated
  WITH CHECK (owner_id = auth.uid());
CREATE POLICY centers_update_admin ON public.centers FOR UPDATE TO authenticated
  USING (public.current_user_is_center_admin(id))
  WITH CHECK (public.current_user_is_center_admin(id));
CREATE POLICY centers_delete_owner ON public.centers FOR DELETE TO authenticated
  USING (owner_id = auth.uid());

CREATE POLICY halaqat_scoped_access ON public.halaqat FOR ALL TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, id))
  WITH CHECK (public.current_user_is_center_admin(center_id));

CREATE POLICY center_members_select_access ON public.center_members FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.current_user_owns_center(center_id));
CREATE POLICY center_members_insert_admin ON public.center_members FOR INSERT TO authenticated
  WITH CHECK (public.current_user_is_center_admin(center_id));
CREATE POLICY center_members_update_admin ON public.center_members FOR UPDATE TO authenticated
  USING (public.current_user_is_center_admin(center_id))
  WITH CHECK (public.current_user_is_center_admin(center_id));
CREATE POLICY center_members_delete_admin ON public.center_members FOR DELETE TO authenticated
  USING (public.current_user_is_center_admin(center_id));

CREATE POLICY families_scoped_access ON public.families FOR ALL TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));
CREATE POLICY family_guardians_scoped_access ON public.family_guardians FOR ALL TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.supervisors TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.centers TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.halaqat TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.center_members TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.families TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_guardians TO authenticated;

COMMIT;
