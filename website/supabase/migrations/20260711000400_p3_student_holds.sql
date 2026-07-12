-- P3: temporary recitation holds that do not remove students from attendance.
-- Requires 20260711000200_p0_security_qr_attendance.sql.

BEGIN;

CREATE TABLE IF NOT EXISTS public.student_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT student_holds_valid_range CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_student_holds_active
  ON public.student_holds(student_id, start_date, end_date)
  WHERE ended_at IS NULL;

CREATE OR REPLACE FUNCTION public.set_student_hold_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT center_id, halaqa_id INTO NEW.center_id, NEW.halaqa_id
  FROM public.students WHERE id = NEW.student_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found'; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_student_hold_scope ON public.student_holds;
CREATE TRIGGER set_student_hold_scope
  BEFORE INSERT OR UPDATE
  ON public.student_holds
  FOR EACH ROW EXECUTE FUNCTION public.set_student_hold_scope();

REVOKE ALL ON FUNCTION public.set_student_hold_scope()
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.student_holds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS student_holds_scoped_access ON public.student_holds;
CREATE POLICY student_holds_scoped_access ON public.student_holds FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

COMMIT;
