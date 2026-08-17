-- Halaqah P1.27 Build 84 / Hotfix 9
-- Incremental sync indexes/cursors support + supervision onboarding recovery.
-- Safe to run after Build 83. Does not delete user data.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Reliable updated_at columns for incremental cloud pulls
-- ---------------------------------------------------------------------------
ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.mushaf_progress
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.vacations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.exams
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.exam_scores
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.fund_transactions
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.student_holds
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE public.talaqqin_records
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.halaqah_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DO $$
DECLARE
  target_table text;
BEGIN
  FOREACH target_table IN ARRAY ARRAY[
    'families',
    'family_guardians',
    'students',
    'attendance',
    'homework_grades',
    'study_suspensions',
    'memorization',
    'mushaf_progress',
    'points',
    'daily_achievements',
    'vacations',
    'exam_templates',
    'exams',
    'exam_scores',
    'notifications',
    'fund_transactions',
    'student_holds',
    'talaqqin_records',
    'student_admin_actions',
    'plans',
    'quran_courses',
    'quran_course_enrollments',
    'plan_recitation_records'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I',
      'trg_' || target_table || '_touch_updated_at', target_table);
    EXECUTE format(
      'CREATE TRIGGER %I BEFORE INSERT OR UPDATE ON public.%I '
      'FOR EACH ROW EXECUTE FUNCTION public.halaqah_touch_updated_at()',
      'trg_' || target_table || '_touch_updated_at', target_table
    );
  END LOOP;
END;
$$;

-- Updating/replacing questions must make the parent template visible to an
-- incremental pull. The parent timestamp is the cursor source for the whole
-- template + questions aggregate.
CREATE OR REPLACE FUNCTION public.touch_exam_template_from_question()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_template uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_template := OLD.template_id;
  ELSE
    target_template := NEW.template_id;
  END IF;

  IF target_template IS NOT NULL THEN
    UPDATE public.exam_templates
       SET updated_at = now()
     WHERE id = target_template;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_exam_questions_touch_template
  ON public.exam_questions;
CREATE TRIGGER trg_exam_questions_touch_template
AFTER INSERT OR UPDATE OR DELETE ON public.exam_questions
FOR EACH ROW EXECUTE FUNCTION public.touch_exam_template_from_question();

-- ---------------------------------------------------------------------------
-- 2) Sync path indexes. All are scoped/index-only friendly for the exact
--    predicates used by Build 84.
-- ---------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_sync_tombstones_scope_id
  ON public.sync_tombstones(center_id, halaqa_id, id);
CREATE INDEX IF NOT EXISTS idx_sync_tombstones_center_id
  ON public.sync_tombstones(center_id, id);
CREATE INDEX IF NOT EXISTS idx_attendance_sync_scope_updated
  ON public.attendance(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_homework_sync_scope_updated
  ON public.homework_grades(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_memorization_sync_scope_updated
  ON public.memorization(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_mushaf_sync_student_updated
  ON public.mushaf_progress(center_id, student_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_mushaf_sync_center_updated
  ON public.mushaf_progress(center_id, updated_at DESC, student_id);
CREATE INDEX IF NOT EXISTS idx_points_sync_scope_updated
  ON public.points(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_exam_templates_sync_scope_updated
  ON public.exam_templates(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_exam_questions_template_order
  ON public.exam_questions(template_id, question_order);
CREATE INDEX IF NOT EXISTS idx_notifications_sync_scope_updated
  ON public.notifications(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_families_sync_scope_updated
  ON public.families(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_family_guardians_sync_scope_updated
  ON public.family_guardians(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_students_sync_scope_updated
  ON public.students(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_study_suspensions_sync_scope_updated
  ON public.study_suspensions(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_daily_achievements_sync_scope_updated
  ON public.daily_achievements(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_vacations_sync_scope_updated
  ON public.vacations(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_exams_sync_scope_updated
  ON public.exams(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_exam_scores_sync_exam_updated
  ON public.exam_scores(exam_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_fund_transactions_sync_scope_updated
  ON public.fund_transactions(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_student_holds_sync_scope_updated
  ON public.student_holds(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_talaqqin_sync_scope_updated
  ON public.talaqqin_records(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_admin_actions_sync_scope_updated
  ON public.student_admin_actions(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_plans_sync_scope_updated
  ON public.plans(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_quran_courses_sync_scope_updated
  ON public.quran_courses(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_course_enrollments_sync_scope_updated
  ON public.quran_course_enrollments(center_id, halaqa_id, updated_at);
CREATE INDEX IF NOT EXISTS idx_plan_recitation_sync_scope_updated
  ON public.plan_recitation_records(center_id, halaqa_id, updated_at);

-- One lightweight RPC lets a synchronized device decide which domains actually
-- changed before issuing any table SELECT. This removes dozens of empty network
-- round-trips from the common no-change path.
CREATE OR REPLACE FUNCTION public.get_halaqah_sync_watermarks(
  p_center_id uuid,
  p_halaqa_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF p_center_id IS NULL OR p_halaqa_id IS NULL THEN
    RAISE EXCEPTION 'center_halaqa_required';
  END IF;
  IF NOT public.current_user_can_access_halaqa(p_center_id, p_halaqa_id) THEN
    RAISE EXCEPTION 'scope_not_accessible' USING ERRCODE = '42501';
  END IF;

  RETURN jsonb_build_object(
    'families', (
      SELECT max(ts) FROM (
        VALUES
          ((SELECT max(updated_at) FROM public.families WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id)),
          ((SELECT max(updated_at) FROM public.family_guardians WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id))
      ) AS valueset(ts)
    ),
    'students', (SELECT max(updated_at) FROM public.students WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'homework', (SELECT max(updated_at) FROM public.homework_grades WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'attendance', (SELECT max(updated_at) FROM public.attendance WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'study_suspensions', (SELECT max(updated_at) FROM public.study_suspensions WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'memorization', (SELECT max(updated_at) FROM public.memorization WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'mushaf', (
      SELECT max(progress.updated_at)
        FROM public.mushaf_progress AS progress
        JOIN public.students AS student ON student.id = progress.student_id
       WHERE progress.center_id = p_center_id
         AND student.center_id = p_center_id
         AND student.halaqa_id = p_halaqa_id
    ),
    'points', (SELECT max(updated_at) FROM public.points WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'achievements', (SELECT max(updated_at) FROM public.daily_achievements WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'vacations', (SELECT max(updated_at) FROM public.vacations WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'exam_templates', (SELECT max(updated_at) FROM public.exam_templates WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'exams', (
      SELECT max(ts) FROM (
        VALUES
          ((SELECT max(updated_at) FROM public.exams WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id)),
          ((SELECT max(score.updated_at)
              FROM public.exam_scores AS score
              JOIN public.exams AS exam ON exam.id = score.exam_id
             WHERE exam.center_id = p_center_id AND exam.halaqa_id = p_halaqa_id))
      ) AS valueset(ts)
    ),
    'notifications', (SELECT max(updated_at) FROM public.notifications WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'fund', (SELECT max(updated_at) FROM public.fund_transactions WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'student_holds', (SELECT max(updated_at) FROM public.student_holds WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'talaqqin', (SELECT max(updated_at) FROM public.talaqqin_records WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'admin_actions', (SELECT max(updated_at) FROM public.student_admin_actions WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'plans', (SELECT max(updated_at) FROM public.plans WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'courses', (
      SELECT max(ts) FROM (
        VALUES
          ((SELECT max(updated_at) FROM public.quran_courses WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id)),
          ((SELECT max(updated_at) FROM public.quran_course_enrollments WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id))
      ) AS valueset(ts)
    ),
    'plan_recitation', (SELECT max(updated_at) FROM public.plan_recitation_records WHERE center_id = p_center_id AND halaqa_id = p_halaqa_id),
    'tombstone_max_id', coalesce((
      SELECT max(id)
        FROM public.sync_tombstones
       WHERE center_id = p_center_id
         AND (halaqa_id IS NULL OR halaqa_id = p_halaqa_id)
    ), 0)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_halaqah_sync_watermarks(uuid, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_halaqah_sync_watermarks(uuid, uuid)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Supervision onboarding. Build 82's health script did not explicitly
--    verify create_supervisor_organization(TEXT), so make the endpoint
--    idempotent and ensure PostgREST sees it.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_supervisor_organization(p_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  current_uid uuid := auth.uid();
  normalized_name text := btrim(coalesce(p_name, ''));
  supervisor_row public.supervisors%ROWTYPE;
BEGIN
  IF current_uid IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF char_length(normalized_name) NOT BETWEEN 3 AND 160 THEN
    RAISE EXCEPTION 'invalid_supervisor_name';
  END IF;

  SELECT * INTO supervisor_row
    FROM public.supervisors
   WHERE owner_id = current_uid
   ORDER BY created_at ASC
   LIMIT 1;

  IF supervisor_row.id IS NULL THEN
    INSERT INTO public.supervisors(name, code, owner_id)
    VALUES (
      normalized_name,
      'HAL-SUP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 20)),
      current_uid
    )
    RETURNING * INTO supervisor_row;

    INSERT INTO public.supervisor_audit_events(
      supervisor_id, actor_id, event_type
    ) VALUES (
      supervisor_row.id, current_uid, 'organization.created'
    );
  END IF;

  -- Resume safely after a partially-completed onboarding instead of forcing
  -- the user to recreate an organization that already exists.
  IF EXISTS (
    SELECT 1
      FROM public.supervisor_members
     WHERE supervisor_id = supervisor_row.id
       AND user_id = current_uid
  ) THEN
    UPDATE public.supervisor_members
       SET role = 'owner', status = 'active', updated_at = now()
     WHERE supervisor_id = supervisor_row.id
       AND user_id = current_uid;
  ELSE
    INSERT INTO public.supervisor_members(
      supervisor_id, user_id, role, status, joined_at, created_at, updated_at
    ) VALUES (
      supervisor_row.id, current_uid, 'owner', 'active', now(), now(), now()
    );
  END IF;

  RETURN jsonb_build_object(
    'id', supervisor_row.id,
    'name', supervisor_row.name,
    'role', 'owner'
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_supervisor_organization(text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_supervisor_organization(text)
  TO authenticated;

-- Force PostgREST to reload newly/recreated RPC signatures immediately.
NOTIFY pgrst, 'reload schema';

COMMIT;
