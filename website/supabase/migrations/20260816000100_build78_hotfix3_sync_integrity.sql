-- Halaqah P1.27 Build 78 Hotfix 3
-- Cloud sync integrity + query indexes
--
-- SAFE CONTRACT:
--   * No row is deleted or rewritten by this script.
--   * It aborts before adding a UNIQUE index if duplicate business keys exist.
--   * Run on a backed-up project, then run P1.27_BUILD78_HOTFIX3_VERIFY.sql.

BEGIN;

DO $$
DECLARE
  required_table text;
BEGIN
  FOREACH required_table IN ARRAY ARRAY[
    'students',
    'attendance',
    'memorization',
    'mushaf_progress',
    'points',
    'daily_achievements',
    'vacations',
    'exam_scores',
    'notifications',
    'fund_transactions',
    'plans',
    'study_suspensions',
    'quran_course_enrollments'
  ]
  LOOP
    IF to_regclass('public.' || required_table) IS NULL THEN
      RAISE EXCEPTION
        'HOTFIX3 stopped: required table public.% is missing. Apply the earlier P1.27 schema migrations first.',
        required_table;
    END IF;
  END LOOP;
END;
$$;

-- Do not silently choose a winner when old data contains duplicates. Export and
-- reconcile those rows first, then rerun this script.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.mushaf_progress
    WHERE student_id IS NOT NULL
    GROUP BY student_id, hizb_number, thumun_number
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'HOTFIX3 stopped: duplicate mushaf_progress rows exist for (student_id,hizb_number,thumun_number).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.attendance
    WHERE student_id IS NOT NULL
    GROUP BY student_id, date
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'HOTFIX3 stopped: duplicate attendance rows exist for (student_id,date).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.daily_achievements
    GROUP BY student_id, date
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'HOTFIX3 stopped: duplicate daily_achievements rows exist for (student_id,date).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.exam_scores
    WHERE exam_id IS NOT NULL AND student_id IS NOT NULL
    GROUP BY exam_id, student_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'HOTFIX3 stopped: duplicate exam_scores rows exist for (exam_id,student_id).';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.quran_course_enrollments
    GROUP BY course_id, student_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'HOTFIX3 stopped: duplicate quran_course_enrollments rows exist for (course_id,student_id).';
  END IF;
END;
$$;

-- These are the conflict targets already used by the web application. The
-- mobile client now uses deterministic primary keys where possible, but the
-- database constraints remain important for web upserts and data integrity.
CREATE UNIQUE INDEX IF NOT EXISTS uq_mushaf_progress_student_hizb_thumun
  ON public.mushaf_progress(student_id, hizb_number, thumun_number);

CREATE UNIQUE INDEX IF NOT EXISTS uq_attendance_student_date
  ON public.attendance(student_id, date);

CREATE UNIQUE INDEX IF NOT EXISTS uq_daily_achievements_student_date
  ON public.daily_achievements(student_id, date);

CREATE UNIQUE INDEX IF NOT EXISTS uq_exam_scores_exam_student
  ON public.exam_scores(exam_id, student_id);

CREATE UNIQUE INDEX IF NOT EXISTS uq_quran_course_enrollments_course_student
  ON public.quran_course_enrollments(course_id, student_id);

-- Read-path indexes used by the scoped mobile/web synchronization queries.
-- They are non-destructive and reduce full-table scans as the center grows.
CREATE INDEX IF NOT EXISTS ix_sync_students_halaqa_id
  ON public.students(halaqa_id);

CREATE INDEX IF NOT EXISTS ix_sync_attendance_center_student_date
  ON public.attendance(center_id, student_id, date);

CREATE INDEX IF NOT EXISTS ix_sync_memorization_center_halaqa_student_date
  ON public.memorization(center_id, halaqa_id, student_id, date);

CREATE INDEX IF NOT EXISTS ix_sync_points_center_halaqa_student_date
  ON public.points(center_id, halaqa_id, student_id, date);

CREATE INDEX IF NOT EXISTS ix_sync_vacations_center_student
  ON public.vacations(center_id, student_id);

CREATE INDEX IF NOT EXISTS ix_sync_plans_center_student
  ON public.plans(center_id, student_id);

CREATE INDEX IF NOT EXISTS ix_sync_notifications_center_student_created
  ON public.notifications(center_id, student_id, created_at DESC);

CREATE INDEX IF NOT EXISTS ix_sync_study_suspensions_center_halaqa_date
  ON public.study_suspensions(center_id, halaqa_id, date);

CREATE INDEX IF NOT EXISTS ix_sync_fund_transactions_center_student_date
  ON public.fund_transactions(center_id, student_id, date);

COMMIT;
