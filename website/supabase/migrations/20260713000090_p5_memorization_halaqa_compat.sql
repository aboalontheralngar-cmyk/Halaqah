-- P5.6 compatibility hotfix for older cloud schemas.
-- Run this file BEFORE 20260713000100_p5_web_recitation_parity.sql only when
-- Supabase reports that public.memorization.halaqa_id does not exist.

BEGIN;

ALTER TABLE public.memorization
  ADD COLUMN IF NOT EXISTS halaqa_id UUID
    REFERENCES public.halaqat(id) ON DELETE SET NULL;

UPDATE public.memorization progress
SET center_id = student.center_id,
    halaqa_id = student.halaqa_id
FROM public.students student
WHERE progress.student_id = student.id
  AND (
    progress.center_id IS NULL
    OR progress.halaqa_id IS NULL
  );

CREATE INDEX IF NOT EXISTS idx_memorization_scope
  ON public.memorization(center_id, halaqa_id, student_id);

COMMIT;
