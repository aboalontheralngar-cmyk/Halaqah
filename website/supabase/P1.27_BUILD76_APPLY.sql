-- P1.27 Build 76 / 2026-08-14
-- Completion pass: full delete propagation, supervision drill-down contract,
-- and mushaf-progress tombstones. Idempotent and data preserving.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Tombstones now also cover mushaf_progress. It does not carry halaqa_id,
--    so the capture function derives the halaqah from the student.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.capture_sync_tombstone()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  payload JSONB := to_jsonb(OLD);
  scoped_center UUID;
  scoped_halaqa UUID;
  scoped_record_id TEXT;
BEGIN
  BEGIN
    scoped_center := nullif(payload ->> 'center_id', '')::UUID;
  EXCEPTION WHEN invalid_text_representation THEN
    scoped_center := NULL;
  END;
  BEGIN
    scoped_halaqa := nullif(
      coalesce(payload ->> 'halaqa_id', payload ->> 'halaqah_id'),
      ''
    )::UUID;
  EXCEPTION WHEN invalid_text_representation THEN
    scoped_halaqa := NULL;
  END;

  scoped_record_id := nullif(payload ->> 'id', '');

  IF TG_TABLE_NAME = 'exam_scores' THEN
    scoped_record_id := nullif(payload ->> 'exam_id', '');
    SELECT exam.center_id, exam.halaqa_id
      INTO scoped_center, scoped_halaqa
    FROM public.exams AS exam
    WHERE exam.id = nullif(payload ->> 'exam_id', '')::UUID;
  ELSIF TG_TABLE_NAME = 'mushaf_progress' THEN
    -- mushaf_progress is keyed by student + hizb + thumun in the cloud
    -- schema, so keep a stable composite ledger key even though record_id is
    -- nullable. The client still replays the delete using row_data.
    scoped_record_id := coalesce(payload ->> 'student_id', '') || '|' ||
      coalesce(payload ->> 'hizb_number', '') || '|' ||
      coalesce(payload ->> 'thumun_number', '');
    SELECT student.center_id, student.halaqa_id
      INTO scoped_center, scoped_halaqa
    FROM public.students AS student
    WHERE student.id = nullif(payload ->> 'student_id', '')::UUID;
  ELSIF scoped_record_id IS NULL AND TG_TABLE_NAME = 'attendance' THEN
    scoped_record_id := coalesce(payload ->> 'student_id', '') || '|' ||
      coalesce(payload ->> 'date', '');
  END IF;

  INSERT INTO public.sync_tombstones (
    center_id, halaqa_id, table_name, record_id, row_data, deleted_by
  ) VALUES (
    scoped_center, scoped_halaqa, TG_TABLE_NAME, scoped_record_id, payload,
    auth.uid()
  );
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.capture_sync_tombstone()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS capture_sync_tombstone_after_delete
  ON public.mushaf_progress;
CREATE TRIGGER capture_sync_tombstone_after_delete
AFTER DELETE ON public.mushaf_progress
FOR EACH ROW EXECUTE FUNCTION public.capture_sync_tombstone();

-- ---------------------------------------------------------------------------
-- 2) A local hard-delete of a student may have many cloud dependants. The
--    client outbox calls one guarded RPC so restrictive FKs cannot leave a
--    half-deleted student in the cloud.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_student_for_sync(p_student_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_center UUID;
  target_halaqa UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;

  SELECT center_id, halaqa_id
    INTO target_center, target_halaqa
  FROM public.students
  WHERE id = p_student_id
  FOR UPDATE;

  -- Already deleted is idempotent success.
  IF NOT FOUND THEN
    RETURN jsonb_build_object('deleted', false, 'already_absent', true);
  END IF;

  IF NOT public.current_user_can_access_halaqa(target_center, target_halaqa) THEN
    RAISE EXCEPTION 'scope_not_accessible';
  END IF;

  DELETE FROM public.student_portal_sessions WHERE student_id = p_student_id;
  DELETE FROM public.student_portal_credentials WHERE student_id = p_student_id;
  DELETE FROM public.quran_course_enrollments WHERE student_id = p_student_id;
  DELETE FROM public.plan_recitation_records WHERE student_id = p_student_id;
  DELETE FROM public.talaqqin_records WHERE student_id = p_student_id;
  DELETE FROM public.student_admin_actions WHERE student_id = p_student_id;
  DELETE FROM public.student_holds WHERE student_id = p_student_id;
  DELETE FROM public.daily_achievements WHERE student_id = p_student_id;
  DELETE FROM public.behavior_point_corrections
    WHERE original_student_id = p_student_id OR corrected_student_id = p_student_id;
  DELETE FROM public.student_status_history WHERE student_id = p_student_id;
  DELETE FROM public.competition_entries WHERE student_id = p_student_id;
  DELETE FROM public.recitation_errors WHERE student_id = p_student_id;
  DELETE FROM public.prayer_tracking WHERE student_id = p_student_id;
  DELETE FROM public.appearance_checks WHERE student_id = p_student_id;
  DELETE FROM public.absence_followups WHERE student_id = p_student_id;
  DELETE FROM public.notifications WHERE student_id = p_student_id;
  DELETE FROM public.homework_grades WHERE student_id = p_student_id;
  DELETE FROM public.mushaf_progress WHERE student_id = p_student_id;
  DELETE FROM public.fund_transactions WHERE student_id = p_student_id;
  DELETE FROM public.vacations WHERE student_id = p_student_id;
  DELETE FROM public.attendance WHERE student_id = p_student_id;
  DELETE FROM public.memorization WHERE student_id = p_student_id;
  DELETE FROM public.points WHERE student_id = p_student_id;
  DELETE FROM public.exam_scores WHERE student_id = p_student_id;

  -- Questions belong to templates; clear them before the templates.
  DELETE FROM public.exam_questions
  WHERE template_id IN (
    SELECT id FROM public.exam_templates WHERE student_id = p_student_id
  );
  DELETE FROM public.exam_templates WHERE student_id = p_student_id;
  DELETE FROM public.plans WHERE student_id = p_student_id;
  DELETE FROM public.students WHERE id = p_student_id;

  RETURN jsonb_build_object('deleted', true, 'student_id', p_student_id);
END;
$$;

REVOKE ALL ON FUNCTION public.delete_student_for_sync(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_student_for_sync(UUID)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Supervisor center drill-down: center -> halaqat -> students/performance.
--    Analysts may read it; only the existing manage functions can mutate.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_supervision_center_detail(
  p_supervisor_id UUID,
  p_center_id UUID,
  p_start_date DATE,
  p_end_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  center_row public.centers%ROWTYPE;
  result JSONB;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF p_start_date IS NULL OR p_end_date IS NULL OR p_end_date < p_start_date
     OR p_end_date - p_start_date > 366 THEN
    RAISE EXCEPTION 'invalid_period';
  END IF;
  IF NOT public.current_user_can_access_supervisor(p_supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_access_required';
  END IF;

  SELECT * INTO center_row
  FROM public.centers
  WHERE id = p_center_id AND supervisor_id = p_supervisor_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'supervised_center_not_found';
  END IF;

  SELECT jsonb_build_object(
    'center', jsonb_build_object(
      'id', center_row.id,
      'name', center_row.name,
      'type', center_row.type,
      'address', center_row.address
    ),
    'period', jsonb_build_object(
      'start_date', p_start_date,
      'end_date', p_end_date
    ),
    'halaqat', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', h.id,
        'name', h.name,
        'teacher_name', h.teacher_name,
        'active_students', (
          SELECT count(*) FROM public.students s
          WHERE s.halaqa_id = h.id AND s.status = 'active'
        ),
        'attendance_rate', COALESCE((
          SELECT round(
            100.0 * count(*) FILTER (WHERE a.status IN ('present','late')) /
            NULLIF(count(*), 0), 1
          ) FROM public.attendance a
          WHERE a.halaqa_id = h.id
            AND a.date BETWEEN p_start_date AND p_end_date
        ), 0),
        'new_ayahs', COALESCE((
          SELECT sum(GREATEST(COALESCE(m.to_ayah,0)-COALESCE(m.from_ayah,0)+1,0))
          FROM public.memorization m
          WHERE m.halaqa_id = h.id
            AND m.session_type = 'new'
            AND m.deleted_at IS NULL
            AND m.date BETWEEN p_start_date AND p_end_date
        ), 0),
        'review_ayahs', COALESCE((
          SELECT sum(GREATEST(COALESCE(m.to_ayah,0)-COALESCE(m.from_ayah,0)+1,0))
          FROM public.memorization m
          WHERE m.halaqa_id = h.id
            AND m.session_type = 'review'
            AND m.deleted_at IS NULL
            AND m.date BETWEEN p_start_date AND p_end_date
        ), 0)
      ) ORDER BY h.name)
      FROM public.halaqat h
      WHERE h.center_id = p_center_id
    ), '[]'::jsonb),
    'students', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'id', s.id,
        'name', s.name,
        'status', s.status,
        'halaqa_id', s.halaqa_id,
        'halaqa_name', (SELECT h.name FROM public.halaqat h WHERE h.id = s.halaqa_id),
        'total_memorized', s.total_memorized,
        'attendance_rate', COALESCE((
          SELECT round(
            100.0 * count(*) FILTER (WHERE a.status IN ('present','late')) /
            NULLIF(count(*), 0), 1
          ) FROM public.attendance a
          WHERE a.student_id = s.id
            AND a.date BETWEEN p_start_date AND p_end_date
        ), 0),
        'new_ayahs', COALESCE((
          SELECT sum(GREATEST(COALESCE(m.to_ayah,0)-COALESCE(m.from_ayah,0)+1,0))
          FROM public.memorization m
          WHERE m.student_id = s.id
            AND m.session_type = 'new'
            AND m.deleted_at IS NULL
            AND m.date BETWEEN p_start_date AND p_end_date
        ), 0),
        'review_ayahs', COALESCE((
          SELECT sum(GREATEST(COALESCE(m.to_ayah,0)-COALESCE(m.from_ayah,0)+1,0))
          FROM public.memorization m
          WHERE m.student_id = s.id
            AND m.session_type = 'review'
            AND m.deleted_at IS NULL
            AND m.date BETWEEN p_start_date AND p_end_date
        ), 0),
        'points_balance', COALESCE((
          SELECT sum(CASE WHEN p.type = 'positive' THEN p.amount ELSE -abs(p.amount) END)
          FROM public.points p
          WHERE p.student_id = s.id
            AND p.date BETWEEN p_start_date AND p_end_date
        ), 0)
      ) ORDER BY s.name)
      FROM public.students s
      WHERE s.center_id = p_center_id
        AND s.status IN ('active','suspended')
    ), '[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.get_supervision_center_detail(UUID, UUID, DATE, DATE)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_supervision_center_detail(UUID, UUID, DATE, DATE)
  TO authenticated;


-- ---------------------------------------------------------------------------
-- 4) Health contract advertises the completion-pass capabilities explicitly.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_supervision_health()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'contract_version', 'build76-2026-08-14',
    'authenticated', auth.uid() IS NOT NULL,
    'profile_role', (
      SELECT profile.role::TEXT FROM public.profiles AS profile
      WHERE profile.id = auth.uid()
    ),
    'owned_organizations', (
      SELECT count(*) FROM public.supervisors AS supervisor
      WHERE supervisor.owner_id = auth.uid()
    ),
    'active_memberships', (
      SELECT count(*) FROM public.supervisor_members AS member
      WHERE member.user_id = auth.uid() AND member.status = 'active'
    ),
    'can_create_centers', EXISTS (
      SELECT 1 FROM public.supervisors AS supervisor
      WHERE public.current_user_can_manage_supervisor(supervisor.id)
    ),
    'direct_center_creation', to_regprocedure(
      'public.create_supervised_center(uuid,text,text,text,text,text)'
    ) IS NOT NULL,
    'center_detail', to_regprocedure(
      'public.get_supervision_center_detail(uuid,uuid,date,date)'
    ) IS NOT NULL,
    'delete_student_sync', to_regprocedure(
      'public.delete_student_for_sync(uuid)'
    ) IS NOT NULL,
    'sync_tombstones', to_regprocedure(
      'public.get_sync_tombstones(uuid,uuid,bigint,integer)'
    ) IS NOT NULL,
    'mushaf_tombstones', EXISTS (
      SELECT 1
      FROM pg_trigger trigger_row
      JOIN pg_class table_row ON table_row.oid = trigger_row.tgrelid
      JOIN pg_namespace namespace_row ON namespace_row.oid = table_row.relnamespace
      WHERE namespace_row.nspname = 'public'
        AND table_row.relname = 'mushaf_progress'
        AND trigger_row.tgname = 'capture_sync_tombstone_after_delete'
        AND NOT trigger_row.tgisinternal
    ),
    'ready', auth.uid() IS NOT NULL AND (
      EXISTS (
        SELECT 1 FROM public.supervisors AS supervisor
        WHERE supervisor.owner_id = auth.uid()
      ) OR EXISTS (
        SELECT 1 FROM public.supervisor_members AS member
        WHERE member.user_id = auth.uid() AND member.status = 'active'
      )
    )
  );
$$;
REVOKE ALL ON FUNCTION public.get_supervision_health() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_supervision_health() TO authenticated;

COMMIT;
