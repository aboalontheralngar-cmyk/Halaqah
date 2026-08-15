-- P1.20: student revision preference, parent behavior visibility,
-- and permission-scoped supervisory guidance visits.
-- Run after 20260722000400_p1_16_plan_recitation_tracking.sql.

BEGIN;

ALTER TABLE public.students
  ADD COLUMN IF NOT EXISTS review_system TEXT NOT NULL DEFAULT 'adaptive_spaced';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'students_review_system_allowed'
      AND conrelid = 'public.students'::regclass
  ) THEN
    ALTER TABLE public.students
      ADD CONSTRAINT students_review_system_allowed
      CHECK (review_system IN (
        'adaptive_spaced',
        'five_day_stabilization',
        'sabaq_sabqi_manzil',
        'teacher_custom'
      )) NOT VALID;
  END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.supervision_visits (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  scheduled_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned'
    CHECK (status IN ('planned', 'completed', 'cancelled')),
  guidance TEXT NOT NULL CHECK (char_length(trim(guidance)) BETWEEN 3 AND 500),
  findings TEXT,
  recommendations TEXT,
  follow_up_date DATE,
  completed_at TIMESTAMPTZ,
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supervision_visits_schedule
  ON public.supervision_visits(supervisor_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_supervision_visits_center
  ON public.supervision_visits(center_id, scheduled_at DESC);

CREATE OR REPLACE FUNCTION public.validate_supervision_visit_center()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM public.centers AS center_row
    WHERE center_row.id = NEW.center_id
      AND center_row.supervisor_id = NEW.supervisor_id
  ) THEN
    RAISE EXCEPTION 'center_not_linked_to_supervisor';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_supervision_visit_center
  ON public.supervision_visits;
CREATE TRIGGER validate_supervision_visit_center
  BEFORE INSERT OR UPDATE ON public.supervision_visits
  FOR EACH ROW EXECUTE FUNCTION public.validate_supervision_visit_center();

ALTER TABLE public.supervision_visits ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS supervision_visits_select ON public.supervision_visits;
CREATE POLICY supervision_visits_select
  ON public.supervision_visits FOR SELECT TO authenticated
  USING (public.current_user_can_access_supervisor(supervisor_id));

DROP POLICY IF EXISTS supervision_visits_insert ON public.supervision_visits;
CREATE POLICY supervision_visits_insert
  ON public.supervision_visits FOR INSERT TO authenticated
  WITH CHECK (
    created_by = auth.uid()
    AND public.current_user_can_manage_supervisor(supervisor_id)
  );

DROP POLICY IF EXISTS supervision_visits_update ON public.supervision_visits;
CREATE POLICY supervision_visits_update
  ON public.supervision_visits FOR UPDATE TO authenticated
  USING (public.current_user_can_manage_supervisor(supervisor_id))
  WITH CHECK (public.current_user_can_manage_supervisor(supervisor_id));

DROP POLICY IF EXISTS supervision_visits_delete ON public.supervision_visits;
CREATE POLICY supervision_visits_delete
  ON public.supervision_visits FOR DELETE TO authenticated
  USING (public.current_user_can_manage_supervisor(supervisor_id));

REVOKE ALL ON public.supervision_visits FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.supervision_visits TO authenticated;

REVOKE ALL ON FUNCTION public.validate_supervision_visit_center()
  FROM PUBLIC, anon, authenticated;

-- Keep the student and family portals on the same server-generated contract.
-- Behavior notes are deliberately limited to the selected active student.
CREATE OR REPLACE FUNCTION public.build_student_portal_dashboard(
  p_student_id UUID,
  p_days INTEGER,
  p_session_expires TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, extensions, pg_temp
AS $$
DECLARE
  target_student public.students%ROWTYPE;
  result JSONB;
  report_days INTEGER;
BEGIN
  report_days := GREATEST(7, LEAST(COALESCE(p_days, 30), 366));

  SELECT * INTO target_student
  FROM public.students
  WHERE id = p_student_id AND status = 'active';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_available';
  END IF;

  SELECT jsonb_build_object(
    'session_expires_at', p_session_expires,
    'period_days', report_days,
    'student', jsonb_build_object(
      'name', target_student.name,
      'student_code', target_student.student_code,
      'level', target_student.level,
      'join_date', target_student.join_date,
      'plan_type', target_student.plan_type,
      'plan_amount', target_student.plan_amount,
      'review_plan_amount', target_student.review_plan_amount,
      'total_memorized', target_student.total_memorized
    ),
    'organization', jsonb_build_object(
      'center_name', COALESCE(center_row.name, 'المركز'),
      'halaqa_name', COALESCE(halaqa_row.name, 'الحلقة'),
      'teacher_name', halaqa_row.teacher_name
    ),
    'summary', jsonb_build_object(
      'points_balance', COALESCE((
        SELECT SUM(point.amount)
        FROM public.points AS point
        WHERE point.student_id = target_student.id
      ), 0),
      'unresolved_violations', (
        SELECT COUNT(*)
        FROM public.points AS point
        WHERE point.student_id = target_student.id
          AND point.type = 'negative'
          AND NOT COALESCE(point.resolved, false)
      ),
      'attendance', jsonb_build_object(
        'present', (SELECT COUNT(*) FROM public.attendance AS attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'present'),
        'late', (SELECT COUNT(*) FROM public.attendance AS attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'late'),
        'absent', (SELECT COUNT(*) FROM public.attendance AS attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'absent'),
        'excused', (SELECT COUNT(*) FROM public.attendance AS attendance
          WHERE attendance.student_id = target_student.id
            AND attendance.date >= current_date - report_days
            AND attendance.status = 'excused')
      )
    ),
    'active_plan', (
      SELECT jsonb_build_object(
        'period', plan.period,
        'start_date', plan.start_date,
        'end_date', plan.end_date,
        'unit', plan.unit,
        'new_amount', plan.new_amount,
        'review_amount', plan.review_amount,
        'status', plan.status,
        'test_status', plan.test_status,
        'notes', plan.notes
      )
      FROM public.plans AS plan
      WHERE plan.student_id = target_student.id
        AND plan.deleted_at IS NULL
        AND plan.status = 'active'
      ORDER BY plan.created_at DESC
      LIMIT 1
    ),
    'recent_memorization', COALESCE((
      SELECT jsonb_agg(
        to_jsonb(recent_row)
        ORDER BY recent_row.date DESC, recent_row.created_at DESC
      )
      FROM (
        SELECT
          memorization.date,
          memorization.surah,
          memorization.from_ayah,
          memorization.to_ayah,
          memorization.degree,
          memorization.session_type,
          memorization.created_at
        FROM public.memorization AS memorization
        WHERE memorization.student_id = target_student.id
          AND memorization.deleted_at IS NULL
          AND memorization.date >= current_date - report_days
        ORDER BY memorization.date DESC, memorization.created_at DESC
        LIMIT 30
      ) AS recent_row
    ), '[]'::jsonb),
    'recent_attendance', COALESCE((
      SELECT jsonb_agg(to_jsonb(attendance_row) ORDER BY attendance_row.date DESC)
      FROM (
        SELECT attendance.date, attendance.status, attendance.notes
        FROM public.attendance AS attendance
        WHERE attendance.student_id = target_student.id
          AND attendance.date >= current_date - report_days
        ORDER BY attendance.date DESC
        LIMIT 30
      ) AS attendance_row
    ), '[]'::jsonb),
    'recent_behavior', COALESCE((
      SELECT jsonb_agg(to_jsonb(behavior_row) ORDER BY behavior_row.date DESC)
      FROM (
        SELECT
          point.date,
          point.reason,
          point.amount,
          COALESCE(point.resolved, false) AS resolved,
          point.notes
        FROM public.points AS point
        WHERE point.student_id = target_student.id
          AND point.date >= current_date - report_days
        ORDER BY point.date DESC, point.created_at DESC
        LIMIT 30
      ) AS behavior_row
    ), '[]'::jsonb)
  ) INTO result
  FROM public.centers AS center_row
  LEFT JOIN public.halaqat AS halaqa_row
    ON halaqa_row.id = target_student.halaqa_id
  WHERE center_row.id = target_student.center_id;

  RETURN result;
END;
$$;

REVOKE ALL ON FUNCTION public.build_student_portal_dashboard(
  UUID, INTEGER, TIMESTAMPTZ
) FROM PUBLIC, anon, authenticated;

COMMIT;
