-- SUPERSEDED FOR PARTIAL/INCONSISTENT CLOUD SCHEMAS: if public.students is missing,
-- do NOT run this migration again. Run P1.25_SUPABASE_PREFLIGHT.sql first, then
-- follow the P1.25 compatibility-repair instructions.
-- P1.24: independent learning units, talaqqin eligibility, and Quran courses.
-- Prepared for manual execution by the project owner. This migration is
-- intentionally idempotent and must not be marked as deployed until the
-- verification query succeeds in the target Supabase project.

BEGIN;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS review_plan_type TEXT,
  ADD COLUMN IF NOT EXISTS talaqqin_enabled BOOLEAN NOT NULL DEFAULT FALSE;

UPDATE public.students
SET review_plan_type = COALESCE(NULLIF(BTRIM(review_plan_type), ''), plan_type, 'ayahs')
WHERE review_plan_type IS NULL OR BTRIM(review_plan_type) = '';

ALTER TABLE public.students
  ALTER COLUMN review_plan_type SET DEFAULT 'ayahs',
  ALTER COLUMN review_plan_type SET NOT NULL;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_review_plan_type_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_review_plan_type_check
  CHECK (review_plan_type IN ('ayahs', 'pages', 'lines', 'hizbs'));

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS review_unit TEXT;

UPDATE public.plans
SET review_unit = COALESCE(NULLIF(BTRIM(review_unit), ''), unit, 'ayahs')
WHERE review_unit IS NULL OR BTRIM(review_unit) = '';

ALTER TABLE public.plans
  ALTER COLUMN review_unit SET DEFAULT 'ayahs',
  ALTER COLUMN review_unit SET NOT NULL;

ALTER TABLE public.plans
  DROP CONSTRAINT IF EXISTS plans_valid_review_unit;
ALTER TABLE public.plans
  ADD CONSTRAINT plans_valid_review_unit
  CHECK (review_unit IN ('ayahs', 'pages', 'lines', 'hizbs'));

CREATE TABLE IF NOT EXISTS public.quran_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (BTRIM(title) <> ''),
  type TEXT NOT NULL DEFAULT 'mixed'
    CHECK (type IN ('memorization', 'revision', 'mixed')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  memorization_unit TEXT NOT NULL DEFAULT 'ayahs'
    CHECK (memorization_unit IN ('ayahs', 'pages', 'lines', 'hizbs')),
  memorization_amount INTEGER NOT NULL DEFAULT 5 CHECK (memorization_amount > 0),
  revision_unit TEXT NOT NULL DEFAULT 'pages'
    CHECK (revision_unit IN ('ayahs', 'pages', 'lines', 'hizbs')),
  revision_amount INTEGER NOT NULL DEFAULT 2 CHECK (revision_amount > 0),
  study_weekdays JSONB NOT NULL DEFAULT '[7,1,2,3,4]'::JSONB
    CHECK (jsonb_typeof(study_weekdays) = 'array'),
  status TEXT NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quran_courses_valid_range CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_quran_courses_scope_dates
  ON public.quran_courses(center_id, halaqa_id, status, start_date, end_date);

CREATE TABLE IF NOT EXISTS public.quran_course_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.quran_courses(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'completed', 'withdrawn')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(course_id, student_id)
);

CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_course
  ON public.quran_course_enrollments(course_id, status, student_id);
CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_student
  ON public.quran_course_enrollments(student_id, status, course_id);
CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_scope
  ON public.quran_course_enrollments(center_id, halaqa_id, status);

CREATE OR REPLACE FUNCTION public.scope_p1_24_quran_course_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  course_scope RECORD;
  student_scope RECORD;
BEGIN
  SELECT center_id, halaqa_id
  INTO course_scope
  FROM public.quran_courses
  WHERE id = NEW.course_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'quran_course_not_found';
  END IF;

  SELECT center_id, halaqa_id
  INTO student_scope
  FROM public.students
  WHERE id = NEW.student_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;

  IF student_scope.center_id IS DISTINCT FROM course_scope.center_id
     OR student_scope.halaqa_id IS DISTINCT FROM course_scope.halaqa_id THEN
    RAISE EXCEPTION 'quran_course_student_scope_mismatch';
  END IF;

  NEW.center_id := course_scope.center_id;
  NEW.halaqa_id := course_scope.halaqa_id;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.scope_p1_24_quran_course_enrollment()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS scope_quran_course_enrollment
  ON public.quran_course_enrollments;
CREATE TRIGGER scope_quran_course_enrollment
  BEFORE INSERT OR UPDATE ON public.quran_course_enrollments
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_24_quran_course_enrollment();

CREATE OR REPLACE FUNCTION public.touch_p1_24_quran_course()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS touch_quran_course ON public.quran_courses;
CREATE TRIGGER touch_quran_course
  BEFORE UPDATE ON public.quran_courses
  FOR EACH ROW EXECUTE FUNCTION public.touch_p1_24_quran_course();

ALTER TABLE public.quran_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quran_course_enrollments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS quran_courses_scoped_access ON public.quran_courses;
CREATE POLICY quran_courses_scoped_access
  ON public.quran_courses FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS quran_course_enrollments_scoped_access
  ON public.quran_course_enrollments;
CREATE POLICY quran_course_enrollments_scoped_access
  ON public.quran_course_enrollments FOR ALL
  USING (
    public.current_user_can_access_halaqa(center_id, halaqa_id)
    AND public.current_user_can_access_student(student_id)
  )
  WITH CHECK (
    public.current_user_can_access_halaqa(center_id, halaqa_id)
    AND public.current_user_can_access_student(student_id)
  );

GRANT SELECT, INSERT, UPDATE, DELETE ON public.quran_courses TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.quran_course_enrollments TO authenticated;

COMMENT ON COLUMN public.students.review_plan_type IS
  'Independent daily review measurement unit; intentionally separate from memorization plan_type.';
COMMENT ON COLUMN public.students.talaqqin_enabled IS
  'Explicit eligibility flag for the temporary talaqqin learning stage.';
COMMENT ON COLUMN public.plans.review_unit IS
  'Independent smart-plan measurement unit for revision.';
COMMENT ON TABLE public.quran_courses IS
  'Time-bounded Quran memorization/revision courses with study weekdays and independent daily targets.';
COMMENT ON TABLE public.quran_course_enrollments IS
  'Students enrolled in Quran courses; scope is enforced from course and student records.';

COMMIT;
