-- P1.25 cloud compatibility repair.
-- Purpose:
-- 1) repair a deployment where centers/halaqat exist but students/plans are missing;
-- 2) apply P1.24 learning-unit/course columns without assuming old migrations ran;
-- 3) remain additive/idempotent. No DROP TABLE, TRUNCATE, or row DELETE.
--
-- IMPORTANT: run P1.25_SUPABASE_PREFLIGHT.sql first. If centers_ready or
-- halaqat_ready is false, do not run this file: that indicates the wrong or an
-- uninitialized Supabase project and must be resolved before data tables are made.

BEGIN;

DO $$
DECLARE
  missing_base TEXT[] := ARRAY[]::TEXT[];
BEGIN
  IF to_regclass('public.centers') IS NULL THEN missing_base := array_append(missing_base, 'centers'); END IF;
  IF to_regclass('public.halaqat') IS NULL THEN missing_base := array_append(missing_base, 'halaqat'); END IF;
  IF to_regclass('public.center_members') IS NULL THEN missing_base := array_append(missing_base, 'center_members'); END IF;
  IF to_regclass('public.families') IS NULL THEN missing_base := array_append(missing_base, 'families'); END IF;

  IF cardinality(missing_base) > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.25_BASE_SCHEMA_MISSING',
      DETAIL = 'Missing base scope tables: ' || array_to_string(missing_base, ', '),
      HINT = 'Run P1.25_SUPABASE_PREFLIGHT.sql and send its complete output. This repair deliberately does not invent a center/authentication scope.';
  END IF;
END;
$$;

DO $$
DECLARE
  missing_scope_columns INTEGER := 0;
  bad_scope_types INTEGER := 0;
BEGIN
  WITH required_scope(table_name, column_name, expected_type) AS (
    VALUES
      ('centers','id','uuid'),
      ('halaqat','id','uuid'), ('halaqat','center_id','uuid'),
      ('center_members','center_id','uuid'), ('center_members','user_id','uuid'),
      ('center_members','halaqah_id','uuid'), ('center_members','role','text'),
      ('families','id','uuid'), ('families','center_id','uuid'), ('families','halaqa_id','uuid')
  )
  SELECT
    COUNT(*) FILTER (WHERE columns.column_name IS NULL),
    COUNT(*) FILTER (
      WHERE columns.column_name IS NOT NULL AND (
        (expected.expected_type='uuid' AND columns.udt_name <> 'uuid') OR
        (expected.expected_type='text' AND columns.udt_name NOT IN ('text','varchar'))
      )
    )
  INTO missing_scope_columns, bad_scope_types
  FROM required_scope AS expected
  LEFT JOIN information_schema.columns AS columns
    ON columns.table_schema='public'
   AND columns.table_name=expected.table_name
   AND columns.column_name=expected.column_name;

  IF missing_scope_columns > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.25_BASE_SCOPE_COLUMNS_MISSING',
      DETAIL = missing_scope_columns::TEXT || ' required center/halaqa/member/family column(s) are missing.',
      HINT = 'Stop and send the complete P1.25 preflight output. This migration will not invent or rewrite the authorization scope.';
  END IF;
  IF bad_scope_types > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.25_BASE_SCOPE_TYPE_MISMATCH',
      DETAIL = bad_scope_types::TEXT || ' required scope column(s) use an incompatible type.',
      HINT = 'Stop and send the complete P1.25 preflight output. Existing identifiers and roles will not be coerced.';
  END IF;
END;
$$;

DO $$
DECLARE
  mismatch_count INTEGER := 0;
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'centers'
      AND column_name = 'id' AND udt_name = 'uuid'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'halaqat'
      AND column_name = 'id' AND udt_name = 'uuid'
  ) OR NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'halaqat'
      AND column_name = 'center_id' AND udt_name = 'uuid'
  ) THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.25_SCOPE_KEY_TYPE_MISMATCH',
      DETAIL = 'centers.id, halaqat.id and halaqat.center_id must use UUID keys.',
      HINT = 'Stop and send the P1.25 preflight output. This repair does not coerce or replace existing identifiers.';
  END IF;

  WITH expected(table_name, column_name) AS (
    VALUES
      ('center_members','id'), ('center_members','center_id'), ('center_members','user_id'), ('center_members','halaqah_id'),
      ('families','id'), ('families','center_id'), ('families','halaqa_id'),
      ('family_guardians','id'), ('family_guardians','family_id'), ('family_guardians','center_id'), ('family_guardians','halaqa_id'),
      ('students','id'), ('students','center_id'), ('students','halaqa_id'), ('students','family_id'),
      ('attendance','id'), ('attendance','student_id'), ('attendance','center_id'), ('attendance','halaqa_id'),
      ('memorization','id'), ('memorization','student_id'), ('memorization','center_id'), ('memorization','halaqa_id'),
      ('points','id'), ('points','student_id'), ('points','center_id'), ('points','halaqa_id'),
      ('exams','id'), ('exams','center_id'), ('exams','halaqa_id'),
      ('exam_scores','id'), ('exam_scores','exam_id'), ('exam_scores','student_id'),
      ('vacations','id'), ('vacations','student_id'), ('vacations','center_id'), ('vacations','halaqa_id'),
      ('fund_transactions','id'), ('fund_transactions','center_id'), ('fund_transactions','halaqa_id'), ('fund_transactions','student_id'), ('fund_transactions','behavior_point_id'),
      ('notifications','id'), ('notifications','center_id'), ('notifications','halaqa_id'), ('notifications','student_id'),
      ('plans','id'), ('plans','center_id'), ('plans','halaqa_id'), ('plans','student_id'), ('plans','completion_exam_id'),
      ('student_holds','id'), ('student_holds','student_id'), ('student_holds','center_id'), ('student_holds','halaqa_id'),
      ('talaqqin_records','id'), ('talaqqin_records','session_id'), ('talaqqin_records','student_id'), ('talaqqin_records','center_id'), ('talaqqin_records','halaqa_id'),
      ('student_admin_actions','id'), ('student_admin_actions','student_id'), ('student_admin_actions','center_id'), ('student_admin_actions','halaqa_id'),
      ('quran_courses','id'), ('quran_courses','center_id'), ('quran_courses','halaqa_id'),
      ('quran_course_enrollments','id'), ('quran_course_enrollments','course_id'), ('quran_course_enrollments','student_id'), ('quran_course_enrollments','center_id'), ('quran_course_enrollments','halaqa_id')
  )
  SELECT COUNT(*) INTO mismatch_count
  FROM expected
  JOIN information_schema.columns AS columns
    ON columns.table_schema = 'public'
   AND columns.table_name = expected.table_name
   AND columns.column_name = expected.column_name
  WHERE columns.udt_name <> 'uuid';

  IF mismatch_count > 0 THEN
    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = 'P1.25_REFERENCE_KEY_TYPE_MISMATCH',
      DETAIL = mismatch_count::TEXT || ' existing reference column(s) are not UUID.',
      HINT = 'Stop and send the complete P1.25 preflight output. The repair never changes identifier types.';
  END IF;
END;
$$;

-- Some field deployments have the center/halaqa scope but never received the
-- original students table. Recreate only the compatible student surface the app
-- actually reads/writes. Existing tables are never replaced.
CREATE TABLE IF NOT EXISTS public.students (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  phone TEXT,
  parent_phone TEXT,
  family_id UUID,
  qr_code TEXT UNIQUE DEFAULT gen_random_uuid()::text,
  student_code TEXT UNIQUE DEFAULT upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 20)),
  age INTEGER,
  level TEXT,
  join_date DATE NOT NULL DEFAULT CURRENT_DATE,
  photo_url TEXT,
  plan_type TEXT NOT NULL DEFAULT 'ayahs',
  plan_amount INTEGER NOT NULL DEFAULT 5,
  review_plan_amount INTEGER NOT NULL DEFAULT 10,
  review_plan_type TEXT NOT NULL DEFAULT 'ayahs',
  review_system TEXT NOT NULL DEFAULT 'adaptive_spaced',
  talaqqin_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  total_memorized INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'active',
  notes TEXT,
  memorization_direction TEXT NOT NULL DEFAULT 'desc',
  pre_memorized_start_surah INTEGER,
  pre_memorized_start_ayah INTEGER,
  pre_memorized_end_surah INTEGER,
  pre_memorized_end_ayah INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS name TEXT,
  ADD COLUMN IF NOT EXISTS phone TEXT,
  ADD COLUMN IF NOT EXISTS parent_phone TEXT,
  ADD COLUMN IF NOT EXISTS family_id UUID,
  ADD COLUMN IF NOT EXISTS qr_code TEXT,
  ADD COLUMN IF NOT EXISTS student_code TEXT,
  ADD COLUMN IF NOT EXISTS age INTEGER,
  ADD COLUMN IF NOT EXISTS level TEXT,
  ADD COLUMN IF NOT EXISTS photo_url TEXT,
  ADD COLUMN IF NOT EXISTS plan_type TEXT NOT NULL DEFAULT 'ayahs',
  ADD COLUMN IF NOT EXISTS plan_amount INTEGER NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS review_plan_amount INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS review_plan_type TEXT,
  ADD COLUMN IF NOT EXISTS review_system TEXT NOT NULL DEFAULT 'adaptive_spaced',
  ADD COLUMN IF NOT EXISTS talaqqin_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS total_memorized INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS join_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS memorization_direction TEXT NOT NULL DEFAULT 'desc',
  ADD COLUMN IF NOT EXISTS pre_memorized_start_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_start_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_surah INTEGER,
  ADD COLUMN IF NOT EXISTS pre_memorized_end_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.students
SET name = COALESCE(NULLIF(BTRIM(name), ''), 'طالب ' || LEFT(id::text, 8))
WHERE name IS NULL OR BTRIM(name) = '';
ALTER TABLE public.students ALTER COLUMN name SET NOT NULL;

UPDATE public.students
SET review_plan_type = COALESCE(NULLIF(BTRIM(review_plan_type), ''), NULLIF(BTRIM(plan_type), ''), 'ayahs')
WHERE review_plan_type IS NULL OR BTRIM(review_plan_type) = '';

ALTER TABLE public.students
  ALTER COLUMN review_plan_type SET DEFAULT 'ayahs',
  ALTER COLUMN review_plan_type SET NOT NULL;

ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_plan_type_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_plan_type_check
  CHECK (plan_type IN ('ayahs', 'pages', 'lines', 'hizbs')) NOT VALID;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_review_plan_type_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_review_plan_type_check
  CHECK (review_plan_type IN ('ayahs', 'pages', 'lines', 'hizbs')) NOT VALID;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_status_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_status_check
  CHECK (status IN ('active', 'inactive', 'suspended', 'expelled', 'graduated')) NOT VALID;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_memorization_direction_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_memorization_direction_check
  CHECK (memorization_direction IN ('asc', 'desc')) NOT VALID;
ALTER TABLE public.students DROP CONSTRAINT IF EXISTS students_total_memorized_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_total_memorized_check
  CHECK (total_memorized BETWEEN 0 AND 6236) NOT VALID;

CREATE INDEX IF NOT EXISTS idx_students_center_halaqa_name
  ON public.students(center_id, halaqa_id, name);
CREATE INDEX IF NOT EXISTS idx_students_status_halaqa
  ON public.students(status, halaqa_id, name);

-- Repair the core cloud surfaces used by current mobile/web synchronization.
-- Every CREATE is conditional and every ALTER only adds compatible columns.
CREATE TABLE IF NOT EXISTS public.attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  date DATE NOT NULL,
  status TEXT NOT NULL,
  arrival_time TIME,
  absence_reason TEXT,
  notes TEXT,
  activity_type TEXT,
  activity_note TEXT,
  recitation_exempt BOOLEAN NOT NULL DEFAULT FALSE,
  talaqqin_done BOOLEAN NOT NULL DEFAULT FALSE,
  talaqqin_amount INTEGER NOT NULL DEFAULT 0,
  talaqqin_note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(student_id, date)
);
ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'present',
  ADD COLUMN IF NOT EXISTS arrival_time TIME,
  ADD COLUMN IF NOT EXISTS absence_reason TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS activity_type TEXT,
  ADD COLUMN IF NOT EXISTS activity_note TEXT,
  ADD COLUMN IF NOT EXISTS recitation_exempt BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS talaqqin_done BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS talaqqin_amount INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS talaqqin_note TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_attendance_scope_date
  ON public.attendance(center_id, halaqa_id, date, student_id);

CREATE TABLE IF NOT EXISTS public.memorization (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  surah TEXT NOT NULL,
  from_ayah INTEGER,
  to_ayah INTEGER,
  degree INTEGER,
  session_type TEXT NOT NULL DEFAULT 'new',
  date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at TIMESTAMPTZ
);
ALTER TABLE public.memorization
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS surah TEXT,
  ADD COLUMN IF NOT EXISTS from_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS to_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS degree INTEGER,
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
CREATE INDEX IF NOT EXISTS idx_memorization_scope_date
  ON public.memorization(center_id, halaqa_id, date, student_id);

CREATE TABLE IF NOT EXISTS public.points (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  type TEXT NOT NULL,
  amount INTEGER NOT NULL,
  reason TEXT NOT NULL,
  date DATE NOT NULL,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  resolved_date TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.points
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'positive',
  ADD COLUMN IF NOT EXISTS amount INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS reason TEXT NOT NULL DEFAULT 'سجل سحابي',
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS resolved BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS resolved_date TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_points_scope_date
  ON public.points(center_id, halaqa_id, date, student_id);

CREATE TABLE IF NOT EXISTS public.exams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  title TEXT NOT NULL DEFAULT 'اختبار',
  date DATE NOT NULL,
  type TEXT NOT NULL DEFAULT 'oral',
  max_degree INTEGER NOT NULL DEFAULT 100,
  from_surah INTEGER,
  to_surah INTEGER,
  from_ayah INTEGER,
  to_ayah INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.exams
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'اختبار',
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'oral',
  ADD COLUMN IF NOT EXISTS max_degree INTEGER NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS from_surah INTEGER,
  ADD COLUMN IF NOT EXISTS to_surah INTEGER,
  ADD COLUMN IF NOT EXISTS from_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS to_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_exams_scope_date
  ON public.exams(center_id, halaqa_id, date);

CREATE TABLE IF NOT EXISTS public.exam_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  exam_id UUID REFERENCES public.exams(id) ON DELETE CASCADE,
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  degree INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(exam_id, student_id)
);
ALTER TABLE public.exam_scores
  ADD COLUMN IF NOT EXISTS exam_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS degree INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_exam_scores_student
  ON public.exam_scores(student_id, exam_id);

CREATE TABLE IF NOT EXISTS public.vacations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT,
  approved BOOLEAN NOT NULL DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.vacations
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS reason TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS approved BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_vacations_scope_dates
  ON public.vacations(center_id, halaqa_id, student_id, start_date, end_date);

CREATE TABLE IF NOT EXISTS public.fund_transactions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  student_id UUID REFERENCES public.students(id) ON DELETE SET NULL,
  behavior_point_id UUID REFERENCES public.points(id) ON DELETE SET NULL,
  settled_negative_points INTEGER NOT NULL DEFAULT 0,
  type TEXT NOT NULL,
  amount NUMERIC(12,2) NOT NULL,
  note TEXT,
  date DATE NOT NULL DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.fund_transactions
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'donation',
  ADD COLUMN IF NOT EXISTS amount NUMERIC(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS behavior_point_id UUID,
  ADD COLUMN IF NOT EXISTS settled_negative_points INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS note TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
UPDATE public.fund_transactions
SET settled_negative_points = 0
WHERE settled_negative_points IS NULL OR settled_negative_points < 0;
CREATE INDEX IF NOT EXISTS idx_fund_scope_date
  ON public.fund_transactions(center_id, halaqa_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_fund_student_settlement
  ON public.fund_transactions(student_id, date DESC)
  WHERE type = 'penalty' AND settled_negative_points > 0;

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  student_id UUID REFERENCES public.students(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'general',
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  read BOOLEAN NOT NULL DEFAULT FALSE,
  sent_via TEXT NOT NULL DEFAULT 'none',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'general',
  ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'إشعار',
  ADD COLUMN IF NOT EXISTS body TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS read BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS sent_via TEXT NOT NULL DEFAULT 'none',
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
CREATE INDEX IF NOT EXISTS idx_notifications_scope_created
  ON public.notifications(center_id, halaqa_id, student_id, created_at DESC);

-- P1.22 extension surfaces are repaired too. A previous DROP ... CASCADE can
-- remove their foreign keys while leaving the tables themselves behind; on
-- some deployments the tables may never have been created at all.
CREATE TABLE IF NOT EXISTS public.student_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL,
  center_id UUID NOT NULL,
  halaqa_id UUID,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  scope TEXT NOT NULL DEFAULT 'recitation_only'
);
ALTER TABLE public.student_holds
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS reason TEXT NOT NULL DEFAULT 'توقيف مؤقت',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS ended_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS scope TEXT NOT NULL DEFAULT 'recitation_only';
ALTER TABLE public.student_holds DROP CONSTRAINT IF EXISTS student_holds_valid_range;
ALTER TABLE public.student_holds
  ADD CONSTRAINT student_holds_valid_range CHECK (end_date >= start_date) NOT VALID;
ALTER TABLE public.student_holds DROP CONSTRAINT IF EXISTS student_holds_scope_check;
ALTER TABLE public.student_holds
  ADD CONSTRAINT student_holds_scope_check
  CHECK (scope IN ('recitation_only', 'full_pause')) NOT VALID;
CREATE INDEX IF NOT EXISTS idx_student_holds_p125_active
  ON public.student_holds(student_id, start_date, end_date)
  WHERE ended_at IS NULL;

CREATE TABLE IF NOT EXISTS public.talaqqin_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  student_id UUID NOT NULL,
  center_id UUID NOT NULL,
  halaqa_id UUID,
  surah_id INTEGER NOT NULL,
  from_ayah INTEGER NOT NULL,
  to_ayah INTEGER NOT NULL,
  date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.talaqqin_records
  ADD COLUMN IF NOT EXISTS session_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS surah_id INTEGER,
  ADD COLUMN IF NOT EXISTS from_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS to_ayah INTEGER,
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.talaqqin_records DROP CONSTRAINT IF EXISTS talaqqin_records_surah_check;
ALTER TABLE public.talaqqin_records
  ADD CONSTRAINT talaqqin_records_surah_check CHECK (surah_id BETWEEN 1 AND 114) NOT VALID;
ALTER TABLE public.talaqqin_records DROP CONSTRAINT IF EXISTS talaqqin_records_ayah_range_check;
ALTER TABLE public.talaqqin_records
  ADD CONSTRAINT talaqqin_records_ayah_range_check
  CHECK (from_ayah >= 1 AND to_ayah >= from_ayah) NOT VALID;
CREATE INDEX IF NOT EXISTS idx_talaqqin_records_p125_scope_date
  ON public.talaqqin_records(center_id, halaqa_id, student_id, date DESC);

CREATE TABLE IF NOT EXISTS public.student_admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL,
  center_id UUID NOT NULL,
  halaqa_id UUID,
  action_type TEXT NOT NULL,
  date DATE NOT NULL,
  details TEXT NOT NULL,
  follow_up TEXT,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.student_admin_actions
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS action_type TEXT NOT NULL DEFAULT 'administrative',
  ADD COLUMN IF NOT EXISTS date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS details TEXT NOT NULL DEFAULT 'إجراء إداري',
  ADD COLUMN IF NOT EXISTS follow_up TEXT,
  ADD COLUMN IF NOT EXISTS resolved BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.student_admin_actions DROP CONSTRAINT IF EXISTS student_admin_actions_type_check;
ALTER TABLE public.student_admin_actions
  ADD CONSTRAINT student_admin_actions_type_check CHECK (
    action_type IN ('warning', 'notice', 'pledge', 'guardian_contact', 'administrative', 'other')
  ) NOT VALID;
CREATE INDEX IF NOT EXISTS idx_student_admin_actions_p125_scope_date
  ON public.student_admin_actions(center_id, halaqa_id, student_id, date DESC);

-- Restore compatible single-column foreign keys without validating historical
-- rows. New writes are constrained immediately; old orphan rows remain visible
-- for a separate audit instead of aborting this repair.
DO $$
DECLARE
  item RECORD;
  rel REGCLASS;
  ref_rel REGCLASS;
  column_attnum SMALLINT;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('students','center_id','centers','CASCADE'),
      ('students','halaqa_id','halaqat','SET NULL'),
      ('students','family_id','families','SET NULL'),
      ('family_guardians','family_id','families','CASCADE'),
      ('family_guardians','center_id','centers','CASCADE'),
      ('family_guardians','halaqa_id','halaqat','CASCADE'),
      ('attendance','student_id','students','CASCADE'),
      ('attendance','center_id','centers','CASCADE'),
      ('attendance','halaqa_id','halaqat','SET NULL'),
      ('memorization','student_id','students','CASCADE'),
      ('memorization','center_id','centers','CASCADE'),
      ('memorization','halaqa_id','halaqat','SET NULL'),
      ('points','student_id','students','CASCADE'),
      ('points','center_id','centers','CASCADE'),
      ('points','halaqa_id','halaqat','SET NULL'),
      ('exams','center_id','centers','CASCADE'),
      ('exams','halaqa_id','halaqat','SET NULL'),
      ('exam_scores','exam_id','exams','CASCADE'),
      ('exam_scores','student_id','students','CASCADE'),
      ('vacations','student_id','students','CASCADE'),
      ('vacations','center_id','centers','CASCADE'),
      ('vacations','halaqa_id','halaqat','SET NULL'),
      ('fund_transactions','center_id','centers','CASCADE'),
      ('fund_transactions','halaqa_id','halaqat','SET NULL'),
      ('fund_transactions','student_id','students','SET NULL'),
      ('fund_transactions','behavior_point_id','points','SET NULL'),
      ('notifications','center_id','centers','CASCADE'),
      ('notifications','halaqa_id','halaqat','SET NULL'),
      ('notifications','student_id','students','CASCADE'),
      ('student_holds','student_id','students','CASCADE'),
      ('student_holds','center_id','centers','CASCADE'),
      ('student_holds','halaqa_id','halaqat','CASCADE'),
      ('talaqqin_records','student_id','students','CASCADE'),
      ('talaqqin_records','center_id','centers','CASCADE'),
      ('talaqqin_records','halaqa_id','halaqat','CASCADE'),
      ('student_admin_actions','student_id','students','CASCADE'),
      ('student_admin_actions','center_id','centers','CASCADE'),
      ('student_admin_actions','halaqa_id','halaqat','CASCADE')
    ) AS v(table_name, column_name, ref_table, on_delete)
  LOOP
    rel := to_regclass(format('public.%I', item.table_name));
    ref_rel := to_regclass(format('public.%I', item.ref_table));
    IF rel IS NULL OR ref_rel IS NULL THEN CONTINUE; END IF;

    SELECT attnum INTO column_attnum
    FROM pg_attribute
    WHERE attrelid = rel AND attname = item.column_name AND NOT attisdropped;
    IF column_attnum IS NULL THEN CONTINUE; END IF;

    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint c
      WHERE c.contype = 'f'
        AND c.conrelid = rel
        AND c.confrelid = ref_rel
        AND c.conkey = ARRAY[column_attnum]::SMALLINT[]
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.%I(id) ON DELETE %s NOT VALID',
        item.table_name,
        item.table_name || '_' || item.column_name || '_p125_fkey',
        item.column_name,
        item.ref_table,
        item.on_delete
      );
    END IF;
  END LOOP;
END;
$$;

-- Preserve any already deployed access helpers. Later supervisory migrations
-- contain richer role logic, so P1.25 only supplies a conservative fallback
-- when a helper is genuinely missing.
DO $outer$
BEGIN
  IF to_regprocedure('public.current_user_is_center_admin(uuid)') IS NULL THEN
    EXECUTE $sql$
      CREATE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
      RETURNS BOOLEAN
      LANGUAGE plpgsql
      SECURITY DEFINER
      STABLE
      SET search_path = public, pg_temp
      AS $fn$
      DECLARE
        allowed BOOLEAN := FALSE;
        linked_supervisor UUID;
      BEGIN
        IF auth.uid() IS NULL THEN RETURN FALSE; END IF;

        IF EXISTS (
          SELECT 1 FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'centers' AND column_name = 'owner_id'
        ) THEN
          EXECUTE 'SELECT EXISTS (SELECT 1 FROM public.centers WHERE id = $1 AND owner_id = $2)'
            INTO allowed USING p_center_id, auth.uid();
          IF allowed THEN RETURN TRUE; END IF;
        END IF;

        IF to_regclass('public.center_members') IS NOT NULL THEN
          EXECUTE $q$
            SELECT EXISTS (
              SELECT 1 FROM public.center_members
              WHERE center_id = $1 AND user_id = $2 AND role = 'admin'
            )
          $q$ INTO allowed USING p_center_id, auth.uid();
          IF allowed THEN RETURN TRUE; END IF;
        END IF;

        IF to_regprocedure('public.current_user_supervisor_role(uuid)') IS NOT NULL
           AND EXISTS (
             SELECT 1 FROM information_schema.columns
             WHERE table_schema = 'public' AND table_name = 'centers' AND column_name = 'supervisor_id'
           ) THEN
          EXECUTE 'SELECT supervisor_id FROM public.centers WHERE id = $1'
            INTO linked_supervisor USING p_center_id;
          IF linked_supervisor IS NOT NULL THEN
            EXECUTE 'SELECT public.current_user_supervisor_role($1) IN (''owner'', ''admin'')'
              INTO allowed USING linked_supervisor;
            IF allowed THEN RETURN TRUE; END IF;
          END IF;
        END IF;
        RETURN FALSE;
      END;
      $fn$;
    $sql$;
  END IF;

  IF to_regprocedure('public.current_user_can_access_halaqa(uuid,uuid)') IS NULL THEN
    EXECUTE $sql$
      CREATE FUNCTION public.current_user_can_access_halaqa(
        p_center_id UUID,
        p_halaqa_id UUID
      )
      RETURNS BOOLEAN
      LANGUAGE plpgsql
      SECURITY DEFINER
      STABLE
      SET search_path = public, pg_temp
      AS $fn$
      DECLARE
        allowed BOOLEAN := FALSE;
      BEGIN
        IF public.current_user_is_center_admin(p_center_id) THEN RETURN TRUE; END IF;
        IF auth.uid() IS NULL OR p_halaqa_id IS NULL THEN RETURN FALSE; END IF;
        IF to_regclass('public.center_members') IS NULL THEN RETURN FALSE; END IF;
        EXECUTE $q$
          SELECT EXISTS (
            SELECT 1 FROM public.center_members
            WHERE center_id = $1
              AND user_id = $2
              AND role = 'teacher'
              AND halaqah_id = $3
          )
        $q$ INTO allowed USING p_center_id, auth.uid(), p_halaqa_id;
        RETURN COALESCE(allowed, FALSE);
      END;
      $fn$;
    $sql$;
  END IF;

  IF to_regprocedure('public.current_user_can_access_student(uuid)') IS NULL THEN
    EXECUTE $sql$
      CREATE FUNCTION public.current_user_can_access_student(p_student_id UUID)
      RETURNS BOOLEAN
      LANGUAGE plpgsql
      SECURITY DEFINER
      STABLE
      SET search_path = public, pg_temp
      AS $fn$
      DECLARE
        student_center UUID;
        student_halaqa UUID;
      BEGIN
        SELECT center_id, halaqa_id INTO student_center, student_halaqa
        FROM public.students WHERE id = p_student_id;
        IF NOT FOUND THEN RETURN FALSE; END IF;
        RETURN public.current_user_can_access_halaqa(student_center, student_halaqa);
      END;
      $fn$;
    $sql$;
  END IF;
END;
$outer$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_student(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_student(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.scope_p1_25_student_record()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT center_id, halaqa_id INTO NEW.center_id, NEW.halaqa_id
  FROM public.students
  WHERE id = NEW.student_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found'; END IF;
  RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION public.scope_p1_25_student_record() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.scope_p1_25_student_record() TO authenticated;

DROP TRIGGER IF EXISTS scope_student_hold ON public.student_holds;
DROP TRIGGER IF EXISTS set_student_hold_scope ON public.student_holds;
CREATE TRIGGER scope_student_hold
  BEFORE INSERT OR UPDATE ON public.student_holds
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_25_student_record();
DROP TRIGGER IF EXISTS scope_talaqqin_record ON public.talaqqin_records;
CREATE TRIGGER scope_talaqqin_record
  BEFORE INSERT OR UPDATE ON public.talaqqin_records
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_25_student_record();
DROP TRIGGER IF EXISTS scope_student_admin_action ON public.student_admin_actions;
CREATE TRIGGER scope_student_admin_action
  BEFORE INSERT OR UPDATE ON public.student_admin_actions
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_25_student_record();

ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS students_scoped_access ON public.students;
CREATE POLICY students_scoped_access ON public.students FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));
GRANT SELECT, INSERT, UPDATE, DELETE ON public.students TO authenticated;

-- Scope the repaired core tables. Existing policies with other names remain;
-- these policies add the current helper-based path without broadening anon.
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memorization ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.points ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exams ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.exam_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vacations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fund_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS attendance_p125_scoped ON public.attendance;
CREATE POLICY attendance_p125_scoped ON public.attendance FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS memorization_p125_scoped ON public.memorization;
CREATE POLICY memorization_p125_scoped ON public.memorization FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS points_p125_scoped ON public.points;
CREATE POLICY points_p125_scoped ON public.points FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id) AND public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS exams_p125_scoped ON public.exams;
CREATE POLICY exams_p125_scoped ON public.exams FOR ALL
  USING (public.current_user_is_center_admin(center_id) OR public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_is_center_admin(center_id) OR public.current_user_can_access_halaqa(center_id, halaqa_id));
DROP POLICY IF EXISTS exam_scores_p125_scoped ON public.exam_scores;
CREATE POLICY exam_scores_p125_scoped ON public.exam_scores FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS vacations_p125_scoped ON public.vacations;
CREATE POLICY vacations_p125_scoped ON public.vacations FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS fund_transactions_p125_scoped ON public.fund_transactions;
CREATE POLICY fund_transactions_p125_scoped ON public.fund_transactions FOR ALL
  USING (public.current_user_is_center_admin(center_id) OR public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_is_center_admin(center_id) OR public.current_user_can_access_halaqa(center_id, halaqa_id));
DROP POLICY IF EXISTS notifications_p125_scoped ON public.notifications;
CREATE POLICY notifications_p125_scoped ON public.notifications FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

ALTER TABLE public.student_holds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.talaqqin_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_admin_actions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS student_holds_scoped_access ON public.student_holds;
CREATE POLICY student_holds_scoped_access ON public.student_holds FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS talaqqin_records_scoped_access ON public.talaqqin_records;
CREATE POLICY talaqqin_records_scoped_access ON public.talaqqin_records FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));
DROP POLICY IF EXISTS student_admin_actions_scoped_access ON public.student_admin_actions;
CREATE POLICY student_admin_actions_scoped_access ON public.student_admin_actions FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

GRANT SELECT, INSERT, UPDATE, DELETE ON public.attendance TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.memorization TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.points TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exams TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.exam_scores TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.vacations TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.fund_transactions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_holds TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.talaqqin_records TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.student_admin_actions TO authenticated;

-- Smart plans are another prerequisite for P1.24's independent review unit.
CREATE TABLE IF NOT EXISTS public.plans (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  period TEXT NOT NULL DEFAULT 'weekly',
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  unit TEXT NOT NULL DEFAULT 'ayahs',
  review_unit TEXT NOT NULL DEFAULT 'ayahs',
  new_amount INTEGER NOT NULL DEFAULT 5,
  review_amount INTEGER NOT NULL DEFAULT 10,
  recitation_amount INTEGER NOT NULL DEFAULT 1,
  status TEXT NOT NULL DEFAULT 'active',
  test_status TEXT NOT NULL DEFAULT 'not_required',
  completion_exam_id UUID,
  completed_at TIMESTAMPTZ,
  deleted_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT plans_valid_range CHECK (end_date >= start_date)
);

ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS period TEXT NOT NULL DEFAULT 'weekly',
  ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS unit TEXT NOT NULL DEFAULT 'ayahs',
  ADD COLUMN IF NOT EXISTS review_unit TEXT,
  ADD COLUMN IF NOT EXISTS new_amount INTEGER NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS review_amount INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS recitation_amount INTEGER NOT NULL DEFAULT 1,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS test_status TEXT NOT NULL DEFAULT 'not_required',
  ADD COLUMN IF NOT EXISTS completion_exam_id UUID,
  ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

UPDATE public.plans
SET review_unit = COALESCE(NULLIF(BTRIM(review_unit), ''), NULLIF(BTRIM(unit), ''), 'ayahs')
WHERE review_unit IS NULL OR BTRIM(review_unit) = '';
ALTER TABLE public.plans
  ALTER COLUMN review_unit SET DEFAULT 'ayahs',
  ALTER COLUMN review_unit SET NOT NULL;
ALTER TABLE public.plans DROP CONSTRAINT IF EXISTS plans_valid_review_unit;
ALTER TABLE public.plans
  ADD CONSTRAINT plans_valid_review_unit
  CHECK (review_unit IN ('ayahs', 'pages', 'lines', 'hizbs')) NOT VALID;
ALTER TABLE public.plans DROP CONSTRAINT IF EXISTS plans_valid_range_p125;
ALTER TABLE public.plans
  ADD CONSTRAINT plans_valid_range_p125
  CHECK (end_date >= start_date) NOT VALID;
CREATE INDEX IF NOT EXISTS idx_plans_scope_student_dates
  ON public.plans(center_id, halaqa_id, student_id, start_date, end_date);

ALTER TABLE public.plans ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS plans_scoped_access ON public.plans;
CREATE POLICY plans_scoped_access ON public.plans FOR ALL
  USING (
    public.current_user_can_access_halaqa(center_id, halaqa_id)
    AND public.current_user_can_access_student(student_id)
  )
  WITH CHECK (
    public.current_user_can_access_halaqa(center_id, halaqa_id)
    AND public.current_user_can_access_student(student_id)
  );
GRANT SELECT, INSERT, UPDATE, DELETE ON public.plans TO authenticated;

CREATE TABLE IF NOT EXISTS public.quran_courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (BTRIM(title) <> ''),
  type TEXT NOT NULL DEFAULT 'mixed' CHECK (type IN ('memorization', 'revision', 'mixed')),
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  memorization_unit TEXT NOT NULL DEFAULT 'ayahs' CHECK (memorization_unit IN ('ayahs', 'pages', 'lines', 'hizbs')),
  memorization_amount INTEGER NOT NULL DEFAULT 5 CHECK (memorization_amount > 0),
  revision_unit TEXT NOT NULL DEFAULT 'pages' CHECK (revision_unit IN ('ayahs', 'pages', 'lines', 'hizbs')),
  revision_amount INTEGER NOT NULL DEFAULT 2 CHECK (revision_amount > 0),
  study_weekdays JSONB NOT NULL DEFAULT '[7,1,2,3,4]'::JSONB CHECK (jsonb_typeof(study_weekdays) = 'array'),
  status TEXT NOT NULL DEFAULT 'planned' CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT quran_courses_valid_range CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS public.quran_course_enrollments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID NOT NULL REFERENCES public.quran_courses(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'withdrawn')),
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(course_id, student_id)
);

ALTER TABLE public.quran_courses
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS title TEXT NOT NULL DEFAULT 'Quran Course',
  ADD COLUMN IF NOT EXISTS type TEXT NOT NULL DEFAULT 'mixed',
  ADD COLUMN IF NOT EXISTS start_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS end_date DATE NOT NULL DEFAULT CURRENT_DATE,
  ADD COLUMN IF NOT EXISTS memorization_unit TEXT NOT NULL DEFAULT 'ayahs',
  ADD COLUMN IF NOT EXISTS memorization_amount INTEGER NOT NULL DEFAULT 5,
  ADD COLUMN IF NOT EXISTS revision_unit TEXT NOT NULL DEFAULT 'pages',
  ADD COLUMN IF NOT EXISTS revision_amount INTEGER NOT NULL DEFAULT 2,
  ADD COLUMN IF NOT EXISTS study_weekdays JSONB NOT NULL DEFAULT '[7,1,2,3,4]'::JSONB,
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'planned',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_type_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_type_check
  CHECK (type IN ('memorization', 'revision', 'mixed')) NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_mem_unit_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_mem_unit_check
  CHECK (memorization_unit IN ('ayahs', 'pages', 'lines', 'hizbs')) NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_review_unit_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_review_unit_check
  CHECK (revision_unit IN ('ayahs', 'pages', 'lines', 'hizbs')) NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_amount_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_amount_check
  CHECK (memorization_amount > 0 AND revision_amount > 0) NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_weekdays_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_weekdays_check
  CHECK (jsonb_typeof(study_weekdays) = 'array') NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_status_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_status_check
  CHECK (status IN ('planned', 'active', 'completed', 'cancelled')) NOT VALID;
ALTER TABLE public.quran_courses DROP CONSTRAINT IF EXISTS quran_courses_p125_range_check;
ALTER TABLE public.quran_courses
  ADD CONSTRAINT quran_courses_p125_range_check CHECK (end_date >= start_date) NOT VALID;

ALTER TABLE public.quran_course_enrollments
  ADD COLUMN IF NOT EXISTS course_id UUID,
  ADD COLUMN IF NOT EXISTS student_id UUID,
  ADD COLUMN IF NOT EXISTS center_id UUID,
  ADD COLUMN IF NOT EXISTS halaqa_id UUID,
  ADD COLUMN IF NOT EXISTS enrolled_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active',
  ADD COLUMN IF NOT EXISTS notes TEXT,
  ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE public.quran_course_enrollments DROP CONSTRAINT IF EXISTS quran_course_enrollments_p125_status_check;
ALTER TABLE public.quran_course_enrollments
  ADD CONSTRAINT quran_course_enrollments_p125_status_check
  CHECK (status IN ('active', 'completed', 'withdrawn')) NOT VALID;
-- Plans and Quran courses are created after the core FK repair above, so repair
-- their scope references here using the same NOT VALID strategy.
DO $$
DECLARE
  item RECORD;
  rel REGCLASS;
  ref_rel REGCLASS;
  column_attnum SMALLINT;
BEGIN
  FOR item IN
    SELECT * FROM (VALUES
      ('plans','center_id','centers','CASCADE'),
      ('plans','halaqa_id','halaqat','CASCADE'),
      ('plans','student_id','students','CASCADE'),
      ('plans','completion_exam_id','exams','SET NULL'),
      ('quran_courses','center_id','centers','CASCADE'),
      ('quran_courses','halaqa_id','halaqat','CASCADE'),
      ('quran_course_enrollments','course_id','quran_courses','CASCADE'),
      ('quran_course_enrollments','student_id','students','CASCADE'),
      ('quran_course_enrollments','center_id','centers','CASCADE'),
      ('quran_course_enrollments','halaqa_id','halaqat','CASCADE')
    ) AS v(table_name, column_name, ref_table, on_delete)
  LOOP
    rel := to_regclass(format('public.%I', item.table_name));
    ref_rel := to_regclass(format('public.%I', item.ref_table));
    IF rel IS NULL OR ref_rel IS NULL THEN CONTINUE; END IF;
    SELECT attnum INTO column_attnum
    FROM pg_attribute
    WHERE attrelid = rel AND attname = item.column_name AND NOT attisdropped;
    IF column_attnum IS NULL THEN CONTINUE; END IF;
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint c
      WHERE c.contype = 'f'
        AND c.conrelid = rel
        AND c.confrelid = ref_rel
        AND c.conkey = ARRAY[column_attnum]::SMALLINT[]
    ) THEN
      EXECUTE format(
        'ALTER TABLE public.%I ADD CONSTRAINT %I FOREIGN KEY (%I) REFERENCES public.%I(id) ON DELETE %s NOT VALID',
        item.table_name,
        item.table_name || '_' || item.column_name || '_p125_fkey',
        item.column_name,
        item.ref_table,
        item.on_delete
      );
    END IF;
  END LOOP;
END;
$$;

CREATE INDEX IF NOT EXISTS idx_quran_courses_scope_dates
  ON public.quran_courses(center_id, halaqa_id, status, start_date, end_date);
CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_course
  ON public.quran_course_enrollments(course_id, status, student_id);
CREATE INDEX IF NOT EXISTS idx_quran_course_enrollments_student
  ON public.quran_course_enrollments(student_id, status, course_id);

CREATE OR REPLACE FUNCTION public.scope_p1_25_quran_course_enrollment()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  course_scope RECORD;
  student_scope RECORD;
BEGIN
  SELECT center_id, halaqa_id INTO course_scope
  FROM public.quran_courses WHERE id = NEW.course_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'quran_course_not_found'; END IF;

  SELECT center_id, halaqa_id INTO student_scope
  FROM public.students WHERE id = NEW.student_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found'; END IF;

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

DROP TRIGGER IF EXISTS scope_quran_course_enrollment ON public.quran_course_enrollments;
CREATE TRIGGER scope_quran_course_enrollment
  BEFORE INSERT OR UPDATE ON public.quran_course_enrollments
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_25_quran_course_enrollment();

CREATE OR REPLACE FUNCTION public.touch_p1_25_quran_course()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$;
DROP TRIGGER IF EXISTS touch_quran_course ON public.quran_courses;
CREATE TRIGGER touch_quran_course
  BEFORE UPDATE ON public.quran_courses
  FOR EACH ROW EXECUTE FUNCTION public.touch_p1_25_quran_course();

ALTER TABLE public.quran_courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quran_course_enrollments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS quran_courses_scoped_access ON public.quran_courses;
CREATE POLICY quran_courses_scoped_access ON public.quran_courses FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));
DROP POLICY IF EXISTS quran_course_enrollments_scoped_access ON public.quran_course_enrollments;
CREATE POLICY quran_course_enrollments_scoped_access ON public.quran_course_enrollments FOR ALL
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
  'Independent daily review measurement unit; separate from memorization plan_type.';
COMMENT ON COLUMN public.students.talaqqin_enabled IS
  'Explicit eligibility for the temporary talaqqin stage.';
COMMENT ON COLUMN public.plans.review_unit IS
  'Independent review measurement unit for smart plans.';

COMMIT;
