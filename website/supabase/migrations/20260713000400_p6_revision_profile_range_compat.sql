-- P6.3: keep the student's assigned memorized range available to revision.
-- Copy this file's CONTENTS (not its filename) into Supabase SQL Editor.

BEGIN;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS qr_code TEXT,
  ADD COLUMN IF NOT EXISTS total_memorized INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS pre_memorized_start_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_start_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

COMMENT ON COLUMN public.students.pre_memorized_start_surah IS
  'First surah in the memorized range assigned in the student profile.';
COMMENT ON COLUMN public.students.pre_memorized_start_ayah IS
  'First ayah in the memorized range assigned in the student profile.';
COMMENT ON COLUMN public.students.pre_memorized_end_surah IS
  'Last surah in the memorized range assigned in the student profile.';
COMMENT ON COLUMN public.students.pre_memorized_end_ayah IS
  'Last ayah in the memorized range assigned in the student profile.';

COMMIT;
