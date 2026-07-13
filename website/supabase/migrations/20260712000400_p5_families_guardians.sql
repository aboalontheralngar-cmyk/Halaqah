-- P5.4: explicit families, multiple students, and multiple guardians.
-- Copy this file's CONTENTS into Supabase SQL Editor after taking a backup.

BEGIN;

-- Self-contained scope helpers for databases that did not run earlier files.
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
      WHERE c.id = p_center_id AND supervisor.owner_id = auth.uid()
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
        AND p_halaqa_id IS NOT NULL
        AND cm.halaqah_id = p_halaqa_id
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

CREATE TABLE IF NOT EXISTS public.families (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  reference_name TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (NULLIF(BTRIM(name), '') IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS public.family_guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id UUID NOT NULL REFERENCES public.families(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
  email TEXT,
  relationship TEXT NOT NULL DEFAULT 'guardian',
  is_primary BOOLEAN NOT NULL DEFAULT false,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (NULLIF(BTRIM(name), '') IS NOT NULL),
  CHECK (NULLIF(BTRIM(phone), '') IS NOT NULL),
  CHECK (relationship IN (
    'father', 'mother', 'brother', 'grandfather', 'uncle', 'guardian', 'other'
  ))
);

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS family_id UUID
  REFERENCES public.families(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_families_scope_name
  ON public.families(center_id, halaqa_id, name);
CREATE INDEX IF NOT EXISTS idx_family_guardians_family
  ON public.family_guardians(family_id, is_primary DESC, name);
CREATE INDEX IF NOT EXISTS idx_students_family
  ON public.students(family_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_family_one_primary_guardian
  ON public.family_guardians(family_id) WHERE is_primary;

CREATE OR REPLACE FUNCTION public.prepare_family_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.name := BTRIM(NEW.name);
  NEW.reference_name := NULLIF(BTRIM(NEW.reference_name), '');
  NEW.notes := NULLIF(BTRIM(NEW.notes), '');
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_family_row ON public.families;
CREATE TRIGGER prepare_family_row
  BEFORE INSERT OR UPDATE ON public.families
  FOR EACH ROW EXECUTE FUNCTION public.prepare_family_row();

CREATE OR REPLACE FUNCTION public.prepare_family_guardian_row()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  SELECT * INTO target_family
  FROM public.families WHERE id = NEW.family_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'family_not_found'; END IF;
  NEW.center_id := target_family.center_id;
  NEW.halaqa_id := target_family.halaqa_id;
  NEW.name := BTRIM(NEW.name);
  NEW.phone := BTRIM(NEW.phone);
  NEW.email := NULLIF(BTRIM(NEW.email), '');
  NEW.notes := NULLIF(BTRIM(NEW.notes), '');
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS prepare_family_guardian_row
  ON public.family_guardians;
CREATE TRIGGER prepare_family_guardian_row
  BEFORE INSERT OR UPDATE ON public.family_guardians
  FOR EACH ROW EXECUTE FUNCTION public.prepare_family_guardian_row();

CREATE OR REPLACE FUNCTION public.propagate_primary_guardian_phone()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.is_primary THEN
    UPDATE public.students
    SET parent_phone = NEW.phone,
        updated_at = now()
    WHERE family_id = NEW.family_id;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS propagate_primary_guardian_phone
  ON public.family_guardians;
CREATE TRIGGER propagate_primary_guardian_phone
  AFTER INSERT OR UPDATE OF phone, is_primary ON public.family_guardians
  FOR EACH ROW EXECUTE FUNCTION public.propagate_primary_guardian_phone();

CREATE OR REPLACE FUNCTION public.validate_student_family_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
BEGIN
  IF NEW.family_id IS NULL THEN RETURN NEW; END IF;
  SELECT * INTO target_family
  FROM public.families WHERE id = NEW.family_id;
  IF NOT FOUND
     OR target_family.center_id IS DISTINCT FROM NEW.center_id
     OR target_family.halaqa_id IS DISTINCT FROM NEW.halaqa_id THEN
    RAISE EXCEPTION 'family_outside_student_scope';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_student_family_scope ON public.students;
CREATE TRIGGER validate_student_family_scope
  BEFORE INSERT OR UPDATE OF family_id, center_id, halaqa_id ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.validate_student_family_scope();

CREATE OR REPLACE FUNCTION public.assign_students_to_family(
  p_family_id UUID,
  p_student_ids UUID[]
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  primary_phone TEXT;
  changed_count INTEGER;
BEGIN
  SELECT * INTO target_family FROM public.families WHERE id = p_family_id;
  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id, target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;
  IF p_student_ids IS NULL OR cardinality(p_student_ids) = 0 THEN RETURN 0; END IF;
  IF EXISTS (
    SELECT 1 FROM public.students student
    WHERE student.id = ANY(p_student_ids)
      AND (
        student.center_id IS DISTINCT FROM target_family.center_id
        OR student.halaqa_id IS DISTINCT FROM target_family.halaqa_id
      )
  ) THEN
    RAISE EXCEPTION 'student_outside_family_scope';
  END IF;
  SELECT phone INTO primary_phone
  FROM public.family_guardians
  WHERE family_id = p_family_id AND is_primary
  LIMIT 1;
  UPDATE public.students
  SET family_id = p_family_id,
      parent_phone = COALESCE(primary_phone, parent_phone),
      updated_at = now()
  WHERE id = ANY(p_student_ids)
    AND center_id = target_family.center_id
    AND halaqa_id = target_family.halaqa_id;
  GET DIAGNOSTICS changed_count = ROW_COUNT;
  RETURN changed_count;
END;
$$;

REVOKE ALL ON FUNCTION public.prepare_family_guardian_row()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.validate_student_family_scope()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.propagate_primary_guardian_phone()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.assign_students_to_family(UUID, UUID[])
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.assign_students_to_family(UUID, UUID[])
  TO authenticated;

ALTER TABLE public.families ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_guardians ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS families_scoped_access ON public.families;
CREATE POLICY families_scoped_access
  ON public.families FOR ALL
  TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS family_guardians_scoped_access
  ON public.family_guardians;
CREATE POLICY family_guardians_scoped_access
  ON public.family_guardians FOR ALL
  TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.families TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.family_guardians TO authenticated;

COMMIT;
