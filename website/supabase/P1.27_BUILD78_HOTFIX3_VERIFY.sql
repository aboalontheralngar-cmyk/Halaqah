-- Halaqah P1.27 Build 78 Hotfix 3 verification
-- Read-only. Every row should return passed = true before retrying production
-- cloud synchronization.

WITH checks AS (
  SELECT
    'schema'::text AS area,
    'uq_mushaf_progress_student_hizb_thumun'::text AS check_name,
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'uq_mushaf_progress_student_hizb_thumun'
        AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
        AND indexdef ILIKE '%(student_id, hizb_number, thumun_number)%'
    ) AS passed,
    'web conflict target: student_id,hizb_number,thumun_number'::text AS details

  UNION ALL
  SELECT 'schema', 'uq_attendance_student_date',
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'uq_attendance_student_date'
        AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
        AND indexdef ILIKE '%(student_id, date)%'
    ),
    'web conflict target: student_id,date'

  UNION ALL
  SELECT 'schema', 'uq_daily_achievements_student_date',
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'uq_daily_achievements_student_date'
        AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
        AND indexdef ILIKE '%(student_id, date)%'
    ),
    'web conflict target: student_id,date'

  UNION ALL
  SELECT 'schema', 'uq_exam_scores_exam_student',
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'uq_exam_scores_exam_student'
        AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
        AND indexdef ILIKE '%(exam_id, student_id)%'
    ),
    'web conflict target: exam_id,student_id'

  UNION ALL
  SELECT 'schema', 'uq_quran_course_enrollments_course_student',
    EXISTS (
      SELECT 1 FROM pg_indexes
      WHERE schemaname = 'public'
        AND indexname = 'uq_quran_course_enrollments_course_student'
        AND indexdef ILIKE 'CREATE UNIQUE INDEX%'
        AND indexdef ILIKE '%(course_id, student_id)%'
    ),
    'course enrollment identity'

  UNION ALL
  SELECT 'duplicates', 'mushaf_progress_business_key',
    NOT EXISTS (
      SELECT 1 FROM public.mushaf_progress
      WHERE student_id IS NOT NULL
      GROUP BY student_id, hizb_number, thumun_number
      HAVING count(*) > 1
    ),
    'no duplicate student/hizb/thumun rows'

  UNION ALL
  SELECT 'duplicates', 'attendance_business_key',
    NOT EXISTS (
      SELECT 1 FROM public.attendance
      WHERE student_id IS NOT NULL
      GROUP BY student_id, date
      HAVING count(*) > 1
    ),
    'no duplicate student/date rows'

  UNION ALL
  SELECT 'duplicates', 'daily_achievements_business_key',
    NOT EXISTS (
      SELECT 1 FROM public.daily_achievements
      GROUP BY student_id, date
      HAVING count(*) > 1
    ),
    'no duplicate student/date rows'

  UNION ALL
  SELECT 'duplicates', 'exam_scores_business_key',
    NOT EXISTS (
      SELECT 1 FROM public.exam_scores
      WHERE exam_id IS NOT NULL AND student_id IS NOT NULL
      GROUP BY exam_id, student_id
      HAVING count(*) > 1
    ),
    'no duplicate exam/student rows'

  UNION ALL
  SELECT 'duplicates', 'quran_course_enrollment_business_key',
    NOT EXISTS (
      SELECT 1 FROM public.quran_course_enrollments
      GROUP BY course_id, student_id
      HAVING count(*) > 1
    ),
    'no duplicate course/student rows'

  UNION ALL
  SELECT 'rpc', 'set_study_suspension',
    EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'set_study_suspension'
    ),
    'required for study-suspension synchronization'

  UNION ALL
  SELECT 'rpc', 'get_sync_tombstones',
    EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'get_sync_tombstones'
    ),
    'required for cloud delete reconciliation'

  UNION ALL
  SELECT 'rpc', 'delete_student_for_sync',
    EXISTS (
      SELECT 1
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public' AND p.proname = 'delete_student_for_sync'
    ),
    'required for scoped student deletion'

  UNION ALL
  SELECT 'table', 'study_suspensions',
    to_regclass('public.study_suspensions') IS NOT NULL,
    'required cloud suspension table'

  UNION ALL
  SELECT 'table', 'sync_tombstones',
    to_regclass('public.sync_tombstones') IS NOT NULL,
    'required cloud tombstone table'
)
SELECT area, check_name, passed, details
FROM checks
ORDER BY passed, area, check_name;
