-- P0: preserve student memorization state across Android/Web synchronization.
-- This migration is intentionally additive and safe for an existing database.

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS qr_code TEXT,
  ADD COLUMN IF NOT EXISTS total_memorized INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS pre_memorized_start_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_start_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW();

ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL;

ALTER TABLE public.memorization
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL;

ALTER TABLE public.points
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL;

ALTER TABLE public.center_settings
  ADD COLUMN IF NOT EXISTS currency_symbol TEXT NOT NULL DEFAULT 'ر.س';

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_plan_type_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_plan_type_check
  CHECK (plan_type IN ('ayahs', 'pages', 'lines'));

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_status_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_status_check
  CHECK (status IN ('active', 'inactive', 'suspended', 'expelled', 'graduated'));

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_total_memorized_check;

ALTER TABLE public.students
  ADD CONSTRAINT students_total_memorized_check
  CHECK (total_memorized BETWEEN 0 AND 6236);

CREATE INDEX IF NOT EXISTS idx_students_halaqa_name
  ON public.students(halaqa_id, name);

CREATE INDEX IF NOT EXISTS idx_attendance_halaqa_date
  ON public.attendance(halaqa_id, date);

CREATE INDEX IF NOT EXISTS idx_memorization_halaqa_date
  ON public.memorization(halaqa_id, date);

CREATE INDEX IF NOT EXISTS idx_points_halaqa_date
  ON public.points(halaqa_id, date);

COMMENT ON COLUMN public.students.total_memorized IS
  'Cached count of memorized numbered ayahs (basmala number 0 is excluded).';

COMMENT ON COLUMN public.students.pre_memorized_start_surah IS
  'Start of memorization assigned before the student began using Halaqah.';

COMMENT ON COLUMN public.students.pre_memorized_end_surah IS
  'End of memorization assigned before the student began using Halaqah.';
