-- P5: persistent weekly/monthly plans and the advancement-exam gate.
-- Self-contained compatibility version for databases that do not yet have
-- current_user_is_center_admin/current_user_can_access_halaqa.

BEGIN;

-- Scope helpers are recreated from the actual centers/center_members/halaqat
-- structure. SECURITY DEFINER avoids recursive RLS lookups in policies.
CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1
      FROM public.centers c
      WHERE c.id = p_center_id
        AND c.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1
      FROM public.center_members cm
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
      SELECT 1
      FROM public.center_members cm
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

CREATE TABLE IF NOT EXISTS public.plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  period TEXT NOT NULL DEFAULT 'weekly',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  unit TEXT NOT NULL DEFAULT 'ayahs',
  new_amount INTEGER NOT NULL DEFAULT 5,
  review_amount INTEGER NOT NULL DEFAULT 10,
  status TEXT NOT NULL DEFAULT 'active',
  test_status TEXT NOT NULL DEFAULT 'not_required',
  completion_exam_id UUID REFERENCES public.exams(id) ON DELETE SET NULL,
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS test_status TEXT NOT NULL DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS completion_exam_id UUID REFERENCES public.exams(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- Backfill the scope of historical plans from their student before enabling RLS.
UPDATE public.plans plan
SET center_id = student.center_id,
    halaqa_id = student.halaqa_id
FROM public.students student
WHERE plan.student_id = student.id
  AND (
    plan.center_id IS DISTINCT FROM student.center_id
    OR plan.halaqa_id IS DISTINCT FROM student.halaqa_id
  );

UPDATE public.plans
SET updated_at = COALESCE(updated_at, created_at, now())
WHERE updated_at IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_student_id_fkey' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_student_id_fkey
      FOREIGN KEY (student_id) REFERENCES public.students(id) ON DELETE CASCADE NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_center_id_fkey' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_center_id_fkey
      FOREIGN KEY (center_id) REFERENCES public.centers(id) ON DELETE CASCADE NOT VALID;
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_period' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_period
      CHECK (period IN ('weekly', 'monthly'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_unit' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_unit
      CHECK (unit IN ('ayahs', 'pages', 'lines'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_status' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_status
      CHECK (status IN ('active', 'completed', 'cancelled'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_test_status' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_test_status
      CHECK (test_status IN ('not_required', 'pending', 'passed', 'failed'));
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_amounts' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_amounts
      CHECK (new_amount > 0 AND review_amount > 0);
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'plans_valid_dates' AND conrelid = 'public.plans'::regclass
  ) THEN
    ALTER TABLE public.plans ADD CONSTRAINT plans_valid_dates
      CHECK (end_date >= start_date);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_plans_student_status_test
  ON public.plans(student_id, status, test_status, created_at DESC);

CREATE OR REPLACE FUNCTION public.set_plan_scope_and_validate()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  student_center UUID;
  student_halaqa UUID;
BEGIN
  SELECT center_id, halaqa_id
  INTO student_center, student_halaqa
  FROM public.students
  WHERE id = NEW.student_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  NEW.center_id := student_center;
  NEW.halaqa_id := student_halaqa;
  NEW.updated_at := now();

  IF NEW.status = 'active' AND EXISTS (
    SELECT 1
    FROM public.plans p
    WHERE p.student_id = NEW.student_id
      AND p.id <> NEW.id
      AND p.deleted_at IS NULL
      AND (
        p.status = 'active'
        OR (p.status = 'completed' AND p.test_status IN ('pending', 'failed'))
      )
  ) THEN
    RAISE EXCEPTION 'previous_plan_requires_passing_exam';
  END IF;

  IF NEW.test_status = 'passed' THEN
    IF NEW.completion_exam_id IS NULL THEN
      RAISE EXCEPTION 'completion_exam_required';
    END IF;
    IF NOT EXISTS (
      SELECT 1
      FROM public.exams e
      JOIN public.exam_scores s ON s.exam_id = e.id
      WHERE e.id = NEW.completion_exam_id
        AND s.student_id = NEW.student_id
        AND s.degree >= e.max_degree * 0.60
        AND e.date >= COALESCE(NEW.completed_at::date, NEW.end_date)
    ) THEN
      RAISE EXCEPTION 'invalid_or_early_completion_exam';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_plan_scope_and_validate ON public.plans;
CREATE TRIGGER set_plan_scope_and_validate
  BEFORE INSERT OR UPDATE ON public.plans
  FOR EACH ROW EXECUTE FUNCTION public.set_plan_scope_and_validate();

REVOKE ALL ON FUNCTION public.set_plan_scope_and_validate()
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS plans_scoped_access ON public.plans;
CREATE POLICY plans_scoped_access ON public.plans FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

COMMIT;
