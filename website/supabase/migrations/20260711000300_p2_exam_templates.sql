-- P2: persistent generated exam templates and editable question metadata.
-- Requires 20260711000200_p0_security_qr_attendance.sql.

BEGIN;

ALTER TABLE public.exam_templates
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'custom',
  ADD COLUMN IF NOT EXISTS criteria_json JSONB NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.exam_questions
  ADD COLUMN IF NOT EXISTS prompt_text TEXT,
  ADD COLUMN IF NOT EXISTS page INTEGER,
  ADD COLUMN IF NOT EXISTS juz INTEGER,
  ADD COLUMN IF NOT EXISTS hizb INTEGER,
  ADD COLUMN IF NOT EXISTS difficulty INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS lines NUMERIC NOT NULL DEFAULT 0;

CREATE UNIQUE INDEX IF NOT EXISTS uq_exam_question_order
  ON public.exam_questions(template_id, question_order);
CREATE INDEX IF NOT EXISTS idx_exam_templates_student
  ON public.exam_templates(student_id, updated_at DESC);

CREATE OR REPLACE FUNCTION public.set_exam_template_scope()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.student_id IS NOT NULL THEN
    SELECT center_id, halaqa_id INTO NEW.center_id, NEW.halaqa_id
    FROM public.students WHERE id = NEW.student_id;
    IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found'; END IF;
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_exam_template_scope ON public.exam_templates;
CREATE TRIGGER set_exam_template_scope
  BEFORE INSERT OR UPDATE OF student_id, criteria_json, title
  ON public.exam_templates
  FOR EACH ROW EXECUTE FUNCTION public.set_exam_template_scope();

REVOKE ALL ON FUNCTION public.set_exam_template_scope()
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.exam_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_questions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access exam_templates by center" ON public.exam_templates;
DROP POLICY IF EXISTS exam_templates_scoped_access ON public.exam_templates;
CREATE POLICY exam_templates_scoped_access ON public.exam_templates FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS "Access exam_questions via template" ON public.exam_questions;
DROP POLICY IF EXISTS exam_questions_access ON public.exam_questions;
DROP POLICY IF EXISTS exam_questions_scoped_access ON public.exam_questions;
CREATE POLICY exam_questions_scoped_access ON public.exam_questions FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.exam_templates template
    WHERE template.id = exam_questions.template_id
      AND public.current_user_can_access_halaqa(
        template.center_id,
        template.halaqa_id
      )
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.exam_templates template
    WHERE template.id = exam_questions.template_id
      AND public.current_user_can_access_halaqa(
        template.center_id,
        template.halaqa_id
      )
  ));

COMMIT;
