-- P5.2: student archive/status audit and safe behavior-point corrections.
-- Copy the CONTENTS of this file into Supabase SQL Editor, not the filename.

BEGIN;

-- Self-contained scope helpers for installations that did not run earlier files.
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

CREATE TABLE IF NOT EXISTS public.student_status_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  previous_status TEXT NOT NULL,
  new_status TEXT NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  changed_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.behavior_point_corrections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  point_id UUID REFERENCES public.points(id) ON DELETE SET NULL,
  original_student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  corrected_student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  action TEXT NOT NULL CHECK (action IN ('reassign', 'delete')),
  reason TEXT NOT NULL,
  point_reason_snapshot TEXT NOT NULL,
  points_snapshot INTEGER NOT NULL,
  changed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.points
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS resolved_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.points point
SET center_id = student.center_id,
    halaqa_id = student.halaqa_id
FROM public.students student
WHERE point.student_id = student.id
  AND (
    point.center_id IS DISTINCT FROM student.center_id
    OR point.halaqa_id IS DISTINCT FROM student.halaqa_id
  );

-- Repair legacy Android rows that uploaded a negative record as a positive amount.
UPDATE public.points SET amount = -ABS(amount)
WHERE type = 'negative' AND amount > 0;
UPDATE public.points SET amount = ABS(amount)
WHERE type = 'positive' AND amount < 0;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'points_type_matches_amount'
      AND conrelid = 'public.points'::regclass
  ) THEN
    ALTER TABLE public.points ADD CONSTRAINT points_type_matches_amount
      CHECK (
        (type = 'positive' AND amount > 0)
        OR (type = 'negative' AND amount < 0)
      ) NOT VALID;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_student_status_history_student
  ON public.student_status_history(student_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_behavior_corrections_point
  ON public.behavior_point_corrections(point_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_points_student_date
  ON public.points(student_id, date DESC);

CREATE OR REPLACE FUNCTION public.audit_student_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  audit_reason TEXT;
  audit_notes TEXT;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;
  IF NEW.status NOT IN ('active', 'suspended', 'expelled', 'graduated', 'inactive') THEN
    RAISE EXCEPTION 'invalid_student_status';
  END IF;
  audit_reason := NULLIF(current_setting('app.status_change_reason', true), '');
  audit_notes := NULLIF(current_setting('app.status_change_notes', true), '');
  INSERT INTO public.student_status_history (
    student_id, center_id, halaqa_id, previous_status, new_status,
    reason, notes, changed_by, changed_at
  ) VALUES (
    NEW.id, NEW.center_id, NEW.halaqa_id, OLD.status, NEW.status,
    COALESCE(audit_reason, 'تحديث متزامن لحالة الطالب'),
    audit_notes, auth.uid(), now()
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS audit_student_status_change ON public.students;
CREATE TRIGGER audit_student_status_change
  AFTER UPDATE OF status ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.audit_student_status_change();

CREATE OR REPLACE FUNCTION public.change_student_status(
  p_student_id UUID,
  p_new_status TEXT,
  p_reason TEXT,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target public.students%ROWTYPE;
BEGIN
  IF NULLIF(BTRIM(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'status_reason_required';
  END IF;
  IF p_new_status NOT IN ('active', 'suspended', 'expelled', 'graduated', 'inactive') THEN
    RAISE EXCEPTION 'invalid_student_status';
  END IF;
  SELECT * INTO target FROM public.students WHERE id = p_student_id;
  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(target.center_id, target.halaqa_id) THEN
    RAISE EXCEPTION 'student_not_accessible';
  END IF;
  PERFORM set_config('app.status_change_reason', BTRIM(p_reason), true);
  PERFORM set_config('app.status_change_notes', COALESCE(BTRIM(p_notes), ''), true);
  UPDATE public.students SET status = p_new_status WHERE id = p_student_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reassign_behavior_point(
  p_point_id UUID,
  p_corrected_student_id UUID,
  p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  source_point public.points%ROWTYPE;
  target_student public.students%ROWTYPE;
BEGIN
  IF NULLIF(BTRIM(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'correction_reason_required';
  END IF;
  SELECT * INTO source_point FROM public.points WHERE id = p_point_id;
  SELECT * INTO target_student FROM public.students WHERE id = p_corrected_student_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'target_student_not_found'; END IF;
  IF source_point.id IS NULL
     OR source_point.student_id = target_student.id
     OR target_student.status NOT IN ('active', 'suspended')
     OR NOT public.current_user_can_access_halaqa(source_point.center_id, source_point.halaqa_id)
     OR NOT public.current_user_can_access_halaqa(target_student.center_id, target_student.halaqa_id)
     OR source_point.center_id IS DISTINCT FROM target_student.center_id
     OR source_point.halaqa_id IS DISTINCT FROM target_student.halaqa_id THEN
    RAISE EXCEPTION 'point_or_student_not_accessible';
  END IF;
  INSERT INTO public.behavior_point_corrections (
    point_id, original_student_id, corrected_student_id, center_id, halaqa_id,
    action, reason, point_reason_snapshot, points_snapshot, changed_by
  ) VALUES (
    source_point.id, source_point.student_id, target_student.id,
    source_point.center_id, source_point.halaqa_id, 'reassign', BTRIM(p_reason),
    source_point.reason, source_point.amount, auth.uid()
  );
  UPDATE public.points
  SET student_id = target_student.id, updated_at = now()
  WHERE id = source_point.id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_behavior_point_with_audit(
  p_point_id UUID,
  p_reason TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  source_point public.points%ROWTYPE;
BEGIN
  IF NULLIF(BTRIM(p_reason), '') IS NULL THEN
    RAISE EXCEPTION 'correction_reason_required';
  END IF;
  SELECT * INTO source_point FROM public.points WHERE id = p_point_id;
  IF source_point.id IS NULL
     OR NOT public.current_user_can_access_halaqa(source_point.center_id, source_point.halaqa_id) THEN
    RAISE EXCEPTION 'point_not_accessible';
  END IF;
  INSERT INTO public.behavior_point_corrections (
    point_id, original_student_id, center_id, halaqa_id, action, reason,
    point_reason_snapshot, points_snapshot, changed_by
  ) VALUES (
    source_point.id, source_point.student_id, source_point.center_id,
    source_point.halaqa_id, 'delete', BTRIM(p_reason), source_point.reason,
    source_point.amount, auth.uid()
  );
  DELETE FROM public.points WHERE id = source_point.id;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_student_status_change()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.change_student_status(UUID, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reassign_behavior_point(UUID, UUID, TEXT)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_behavior_point_with_audit(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.change_student_status(UUID, TEXT, TEXT, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reassign_behavior_point(UUID, UUID, TEXT)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_behavior_point_with_audit(UUID, TEXT)
  TO authenticated;

ALTER TABLE public.student_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.behavior_point_corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_status_history_scoped_select
  ON public.student_status_history;
CREATE POLICY student_status_history_scoped_select
  ON public.student_status_history FOR SELECT
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS behavior_corrections_scoped_select
  ON public.behavior_point_corrections;
DROP POLICY IF EXISTS behavior_corrections_scoped_insert
  ON public.behavior_point_corrections;
DROP POLICY IF EXISTS behavior_corrections_scoped_update
  ON public.behavior_point_corrections;
CREATE POLICY behavior_corrections_scoped_select
  ON public.behavior_point_corrections FOR SELECT
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));
CREATE POLICY behavior_corrections_scoped_insert
  ON public.behavior_point_corrections FOR INSERT
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));
CREATE POLICY behavior_corrections_scoped_update
  ON public.behavior_point_corrections FOR UPDATE
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS points_scoped_access ON public.points;
CREATE POLICY points_scoped_access ON public.points FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

COMMIT;
