-- P1.25 cloud compatibility verification (READ-ONLY).
-- Run only after 20260809000100_p1_25_cloud_compat.sql commits successfully.

SELECT
  to_regclass('public.students') IS NOT NULL AS students_ready,
  to_regclass('public.attendance') IS NOT NULL AS attendance_ready,
  to_regclass('public.memorization') IS NOT NULL AS memorization_ready,
  to_regclass('public.points') IS NOT NULL AS points_ready,
  to_regclass('public.exams') IS NOT NULL AS exams_ready,
  to_regclass('public.exam_scores') IS NOT NULL AS exam_scores_ready,
  to_regclass('public.vacations') IS NOT NULL AS vacations_ready,
  to_regclass('public.fund_transactions') IS NOT NULL AS fund_ready,
  to_regclass('public.notifications') IS NOT NULL AS notifications_ready,
  to_regclass('public.plans') IS NOT NULL AS plans_ready,
  to_regclass('public.quran_courses') IS NOT NULL AS quran_courses_ready,
  to_regclass('public.quran_course_enrollments') IS NOT NULL AS quran_course_enrollments_ready,
  to_regclass('public.student_holds') IS NOT NULL AS student_holds_ready,
  to_regclass('public.talaqqin_records') IS NOT NULL AS talaqqin_records_ready,
  to_regclass('public.student_admin_actions') IS NOT NULL AS student_admin_actions_ready;

SELECT
  to_regprocedure('public.current_user_is_center_admin(uuid)') IS NOT NULL AS center_admin_helper_ready,
  to_regprocedure('public.current_user_can_access_halaqa(uuid,uuid)') IS NOT NULL AS halaqa_scope_helper_ready,
  to_regprocedure('public.current_user_can_access_student(uuid)') IS NOT NULL AS student_scope_helper_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='students' AND column_name='review_plan_type'
  ) AS review_plan_type_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='students' AND column_name='talaqqin_enabled'
  ) AS talaqqin_flag_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='plans' AND column_name='review_unit'
  ) AS plan_review_unit_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='vacations' AND column_name='notes'
  ) AS vacation_notes_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='exams' AND column_name='from_surah'
  ) AS exam_range_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='fund_transactions' AND column_name='settled_negative_points'
  ) AS fund_settlement_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='fund_transactions' AND column_name='halaqa_id'
  ) AS fund_halaqa_scope_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='quran_courses' AND column_name='memorization_unit'
  ) AS course_memorization_unit_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='quran_courses' AND column_name='revision_unit'
  ) AS course_revision_unit_ready,
  EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema='public' AND table_name='quran_courses' AND column_name='study_weekdays'
  ) AS course_weekdays_ready;

-- Every identifier/reference used by current mobile/web sync must still be UUID.
WITH expected(table_name, column_name) AS (
  VALUES
    ('centers','id'),
    ('halaqat','id'), ('halaqat','center_id'),
    ('center_members','id'), ('center_members','center_id'), ('center_members','user_id'), ('center_members','halaqah_id'),
    ('families','id'), ('families','center_id'), ('families','halaqa_id'),
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
SELECT
  COUNT(*) FILTER (WHERE columns.column_name IS NULL) AS missing_expected_columns,
  COUNT(*) FILTER (WHERE columns.column_name IS NOT NULL AND columns.udt_name <> 'uuid') AS incompatible_uuid_columns
FROM expected
LEFT JOIN information_schema.columns AS columns
  ON columns.table_schema='public'
 AND columns.table_name=expected.table_name
 AND columns.column_name=expected.column_name;

-- P1.25 intentionally uses NOT VALID when restoring a missing FK over historical
-- data. This protects all new writes immediately without deleting old rows.
SELECT
  conrelid::regclass::text AS table_name,
  conname,
  convalidated
FROM pg_constraint
WHERE contype='f'
  AND conname LIKE '%p125_fkey'
ORDER BY table_name, conname;

-- Historical orphan audit. A non-zero count is not deleted automatically; send
-- the result before any cleanup so local/synced student IDs can be restored first.
SELECT 'students.center_id' AS relation, COUNT(*) AS orphan_rows
FROM public.students child LEFT JOIN public.centers parent ON parent.id=child.center_id
WHERE child.center_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'students.halaqa_id', COUNT(*)
FROM public.students child LEFT JOIN public.halaqat parent ON parent.id=child.halaqa_id
WHERE child.halaqa_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'students.family_id', COUNT(*)
FROM public.students child LEFT JOIN public.families parent ON parent.id=child.family_id
WHERE child.family_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'attendance.student_id', COUNT(*)
FROM public.attendance child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'memorization.student_id', COUNT(*)
FROM public.memorization child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'points.student_id', COUNT(*)
FROM public.points child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'exam_scores.exam_id', COUNT(*)
FROM public.exam_scores child LEFT JOIN public.exams parent ON parent.id=child.exam_id
WHERE child.exam_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'exam_scores.student_id', COUNT(*)
FROM public.exam_scores child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'vacations.student_id', COUNT(*)
FROM public.vacations child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'fund_transactions.student_id', COUNT(*)
FROM public.fund_transactions child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'notifications.student_id', COUNT(*)
FROM public.notifications child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'plans.student_id', COUNT(*)
FROM public.plans child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'student_holds.student_id', COUNT(*)
FROM public.student_holds child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'talaqqin_records.student_id', COUNT(*)
FROM public.talaqqin_records child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'student_admin_actions.student_id', COUNT(*)
FROM public.student_admin_actions child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'quran_course_enrollments.course_id', COUNT(*)
FROM public.quran_course_enrollments child LEFT JOIN public.quran_courses parent ON parent.id=child.course_id
WHERE child.course_id IS NOT NULL AND parent.id IS NULL
UNION ALL
SELECT 'quran_course_enrollments.student_id', COUNT(*)
FROM public.quran_course_enrollments child LEFT JOIN public.students parent ON parent.id=child.student_id
WHERE child.student_id IS NOT NULL AND parent.id IS NULL
ORDER BY relation;

-- Duplicate audits for the natural keys current sync treats as unique.
SELECT 'attendance(student_id,date)' AS natural_key, COUNT(*) AS duplicate_groups
FROM (
  SELECT student_id, date FROM public.attendance
  WHERE student_id IS NOT NULL
  GROUP BY student_id, date HAVING COUNT(*) > 1
) duplicates
UNION ALL
SELECT 'exam_scores(exam_id,student_id)', COUNT(*)
FROM (
  SELECT exam_id, student_id FROM public.exam_scores
  WHERE exam_id IS NOT NULL AND student_id IS NOT NULL
  GROUP BY exam_id, student_id HAVING COUNT(*) > 1
) duplicates
UNION ALL
SELECT 'quran_course_enrollments(course_id,student_id)', COUNT(*)
FROM (
  SELECT course_id, student_id FROM public.quran_course_enrollments
  WHERE course_id IS NOT NULL AND student_id IS NOT NULL
  GROUP BY course_id, student_id HAVING COUNT(*) > 1
) duplicates;
