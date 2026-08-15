-- P1.22: activities, full student pauses, talaqqin, and administrative actions.
-- Prepared for manual execution by the project owner. Do not mark as deployed
-- until it has been executed successfully in the target Supabase project.

BEGIN;


-- Compatibility bootstrap: some deployed databases never received the older
-- P3 student_holds migration. Create the table here before P1.22 alters it.
CREATE TABLE IF NOT EXISTS public.student_holds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  reason TEXT NOT NULL,
  notes TEXT,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  scope TEXT NOT NULL DEFAULT 'recitation_only',
  CONSTRAINT student_holds_valid_range CHECK (end_date >= start_date),
  CONSTRAINT student_holds_scope_check CHECK (
    scope IN ('recitation_only', 'full_pause')
  )
);

CREATE INDEX IF NOT EXISTS idx_student_holds_active
  ON public.student_holds(student_id, start_date, end_date)
  WHERE ended_at IS NULL;

ALTER TABLE public.attendance
  ADD COLUMN IF NOT EXISTS activity_type TEXT,
  ADD COLUMN IF NOT EXISTS activity_note TEXT,
  ADD COLUMN IF NOT EXISTS recitation_exempt BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS talaqqin_done BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS talaqqin_amount INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS talaqqin_note TEXT;

ALTER TABLE public.attendance
  DROP CONSTRAINT IF EXISTS attendance_activity_type_check;
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_activity_type_check CHECK (
    activity_type IS NULL OR activity_type IN (
      'lecture', 'activity', 'league', 'dinner', 'sport',
      'cultural_competition', 'other'
    )
  );

ALTER TABLE public.attendance
  DROP CONSTRAINT IF EXISTS attendance_talaqqin_amount_check;
ALTER TABLE public.attendance
  ADD CONSTRAINT attendance_talaqqin_amount_check CHECK (talaqqin_amount >= 0);

ALTER TABLE public.student_holds
  ADD COLUMN IF NOT EXISTS scope TEXT NOT NULL DEFAULT 'recitation_only';

ALTER TABLE public.student_holds
  DROP CONSTRAINT IF EXISTS student_holds_scope_check;
ALTER TABLE public.student_holds
  ADD CONSTRAINT student_holds_scope_check
  CHECK (scope IN ('recitation_only', 'full_pause'));

CREATE TABLE IF NOT EXISTS public.talaqqin_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  surah_id INTEGER NOT NULL CHECK (surah_id BETWEEN 1 AND 114),
  from_ayah INTEGER NOT NULL CHECK (from_ayah >= 1),
  to_ayah INTEGER NOT NULL CHECK (to_ayah >= from_ayah),
  date DATE NOT NULL,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_talaqqin_records_student_date
  ON public.talaqqin_records(student_id, date DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_talaqqin_records_scope_date
  ON public.talaqqin_records(center_id, halaqa_id, date DESC);

CREATE TABLE IF NOT EXISTS public.student_admin_actions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  action_type TEXT NOT NULL CHECK (
    action_type IN (
      'warning', 'notice', 'pledge', 'guardian_contact',
      'administrative', 'other'
    )
  ),
  date DATE NOT NULL,
  details TEXT NOT NULL CHECK (BTRIM(details) <> ''),
  follow_up TEXT,
  resolved BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_student_admin_actions_student_date
  ON public.student_admin_actions(student_id, date DESC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_student_admin_actions_scope_date
  ON public.student_admin_actions(center_id, halaqa_id, date DESC);

CREATE OR REPLACE FUNCTION public.scope_p1_22_student_record()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  SELECT center_id, halaqa_id INTO NEW.center_id, NEW.halaqa_id
  FROM public.students
  WHERE id = NEW.student_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'student_not_found';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS scope_talaqqin_record ON public.talaqqin_records;
CREATE TRIGGER scope_talaqqin_record
  BEFORE INSERT OR UPDATE ON public.talaqqin_records
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_22_student_record();

DROP TRIGGER IF EXISTS scope_student_admin_action ON public.student_admin_actions;
CREATE TRIGGER scope_student_admin_action
  BEFORE INSERT OR UPDATE ON public.student_admin_actions
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_22_student_record();

REVOKE ALL ON FUNCTION public.scope_p1_22_student_record()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS set_student_hold_scope ON public.student_holds;
DROP TRIGGER IF EXISTS scope_student_hold ON public.student_holds;
CREATE TRIGGER scope_student_hold
  BEFORE INSERT OR UPDATE ON public.student_holds
  FOR EACH ROW EXECUTE FUNCTION public.scope_p1_22_student_record();

ALTER TABLE public.student_holds ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS student_holds_scoped_access ON public.student_holds;
CREATE POLICY student_holds_scoped_access
  ON public.student_holds FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

ALTER TABLE public.talaqqin_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_admin_actions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS talaqqin_records_scoped_access ON public.talaqqin_records;
CREATE POLICY talaqqin_records_scoped_access
  ON public.talaqqin_records FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

DROP POLICY IF EXISTS student_admin_actions_scoped_access ON public.student_admin_actions;
CREATE POLICY student_admin_actions_scoped_access
  ON public.student_admin_actions FOR ALL
  USING (public.current_user_can_access_student(student_id))
  WITH CHECK (public.current_user_can_access_student(student_id));

COMMENT ON COLUMN public.attendance.recitation_exempt IS
  'True when the student attended an activity/event and must not receive a no-recitation penalty for that day.';
COMMENT ON COLUMN public.student_holds.scope IS
  'recitation_only exempts recitation only; full_pause also exempts attendance for the hold period.';
COMMENT ON TABLE public.talaqqin_records IS
  'Talaqqin teaching sessions; kept separate from memorization/revision progress.';
COMMENT ON TABLE public.student_admin_actions IS
  'Warnings, notices, pledges, guardian contacts, and other administrative student actions.';

CREATE OR REPLACE FUNCTION public.close_daily_operations(
  p_center_id UUID,
  p_halaqa_id UUID,
  p_date DATE,
  p_absence_penalty INTEGER DEFAULT -10,
  p_no_recitation_penalty INTEGER DEFAULT -3
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  closing_state JSONB;
  existing_closing public.daily_closings%ROWTYPE;
  new_closing public.daily_closings%ROWTYPE;
  absence_penalty_value INTEGER;
  no_recitation_penalty_value INTEGER;
  late_penalty_value INTEGER := -2;
  no_thobe_penalty_value INTEGER := -3;
  common_penalty_value INTEGER := 8;
  center_points JSONB;
  configured_absence INTEGER;
  configured_no_recitation INTEGER;
  records_created_value INTEGER := 0;
  records_excused_value INTEGER := 0;
  inserted_excused_value INTEGER := 0;
  absence_points_value INTEGER := 0;
  no_recitation_points_value INTEGER := 0;
  completed_students_value INTEGER := 0;
  exempt_students_value INTEGER := 0;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF p_center_id IS NULL OR p_halaqa_id IS NULL OR p_date IS NULL THEN
    RAISE EXCEPTION 'center_halaqa_and_date_required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.halaqat
    WHERE id = p_halaqa_id AND center_id = p_center_id
  ) THEN
    RAISE EXCEPTION 'halaqa_scope_mismatch';
  END IF;
  IF NOT public.current_user_can_access_halaqa(p_center_id, p_halaqa_id) THEN
    RAISE EXCEPTION 'scope_not_accessible';
  END IF;

  PERFORM pg_advisory_xact_lock(
    hashtextextended(p_center_id::TEXT || ':' || p_halaqa_id::TEXT || ':' || p_date::TEXT, 1414)
  );

  SELECT * INTO existing_closing
  FROM public.daily_closings
  WHERE center_id = p_center_id
    AND halaqa_id = p_halaqa_id
    AND closing_date = p_date;

  IF existing_closing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'closing_id', existing_closing.id,
      'date', existing_closing.closing_date,
      'already_closed', TRUE,
      'records_created', existing_closing.records_created,
      'records_excused', existing_closing.records_excused,
      'absence_points_added', existing_closing.absence_points_added,
      'no_recitation_points_added', existing_closing.no_recitation_points_added,
      'completed_students', existing_closing.completed_students,
      'exempt_students', existing_closing.exempt_students,
      'closed_at', existing_closing.closed_at
    );
  END IF;

  closing_state := public.get_daily_closing_state(p_center_id, p_halaqa_id, p_date);
  IF NOT COALESCE((closing_state->>'can_close')::BOOLEAN, FALSE) THEN
    RAISE EXCEPTION 'daily_closing_blocked:%', COALESCE(closing_state->>'blocker', 'unknown');
  END IF;

  SELECT settings.points_config INTO center_points
  FROM public.center_settings AS settings
  WHERE settings.center_id = p_center_id;

  configured_no_recitation := CASE
    WHEN center_points->>'incomplete_penalty' ~ '^-?[0-9]+$'
      THEN (center_points->>'incomplete_penalty')::INTEGER
    ELSE p_no_recitation_penalty
  END;
  configured_absence := CASE
    WHEN center_points->>'unexcused_absence' ~ '^-?[0-9]+$'
      THEN (center_points->>'unexcused_absence')::INTEGER
    ELSE p_absence_penalty
  END;
  late_penalty_value := CASE
    WHEN center_points->>'late_penalty' ~ '^-?[0-9]+$'
      AND (center_points->>'late_penalty')::INTEGER BETWEEN -100 AND -1
      THEN (center_points->>'late_penalty')::INTEGER
    ELSE -2
  END;
  no_thobe_penalty_value := CASE
    WHEN center_points->>'no_thobe' ~ '^-?[0-9]+$'
      AND (center_points->>'no_thobe')::INTEGER BETWEEN -100 AND -1
      THEN (center_points->>'no_thobe')::INTEGER
    ELSE -3
  END;
  no_recitation_penalty_value := CASE
    WHEN configured_no_recitation BETWEEN -100 AND -1 THEN configured_no_recitation
    ELSE -3
  END;
  common_penalty_value :=
    ABS(late_penalty_value) +
    ABS(no_recitation_penalty_value) +
    ABS(no_thobe_penalty_value);
  absence_penalty_value := -LEAST(
    100,
    GREATEST(
      10,
      ABS(CASE WHEN configured_absence BETWEEN -100 AND -1 THEN configured_absence ELSE -10 END),
      LEAST(99, common_penalty_value) + 1
    )
  );

  WITH corrected AS (
    UPDATE public.attendance AS attendance_row
    SET status = 'excused',
        absence_reason = CASE
          WHEN EXISTS (
            SELECT 1 FROM public.vacations AS vacation
            WHERE vacation.student_id = attendance_row.student_id
              AND vacation.approved = TRUE
              AND p_date BETWEEN vacation.start_date AND vacation.end_date
          ) THEN 'إجازة معتمدة'
          ELSE 'توقف مؤقت'
        END,
        notes = COALESCE(NULLIF(attendance_row.notes, ''), 'صُحح تلقائيًا عند إغلاق اليوم')
    WHERE attendance_row.center_id = p_center_id
      AND attendance_row.halaqa_id = p_halaqa_id
      AND attendance_row.date = p_date
      AND attendance_row.status = 'absent'
      AND (
        EXISTS (
          SELECT 1 FROM public.vacations AS vacation
          WHERE vacation.student_id = attendance_row.student_id
            AND vacation.approved = TRUE
            AND p_date BETWEEN vacation.start_date AND vacation.end_date
        )
        OR EXISTS (
          SELECT 1 FROM public.student_holds AS hold
          WHERE hold.student_id = attendance_row.student_id
            AND hold.scope = 'full_pause'
            AND (hold.ended_at IS NULL OR p_date <= hold.ended_at::DATE)
            AND p_date BETWEEN hold.start_date AND hold.end_date
        )
      )
    RETURNING 1
  ) SELECT COUNT(*)::INTEGER INTO records_excused_value FROM corrected;

  WITH inserted AS (
    INSERT INTO public.attendance (
      student_id, center_id, halaqa_id, date, status,
      absence_reason, notes
    )
    SELECT
      student.id,
      p_center_id,
      p_halaqa_id,
      p_date,
      CASE WHEN EXISTS (
        SELECT 1 FROM public.vacations AS vacation
        WHERE vacation.student_id = student.id
          AND vacation.approved = TRUE
          AND p_date BETWEEN vacation.start_date AND vacation.end_date
      ) THEN 'excused' ELSE 'absent' END,
      CASE WHEN EXISTS (
        SELECT 1 FROM public.vacations AS vacation
        WHERE vacation.student_id = student.id
          AND vacation.approved = TRUE
          AND p_date BETWEEN vacation.start_date AND vacation.end_date
      ) THEN 'إجازة معتمدة' ELSE 'بدون عذر' END,
      'أُنشئ تلقائيًا عند إغلاق اليوم'
    FROM public.students AS student
    WHERE student.center_id = p_center_id
      AND student.halaqa_id = p_halaqa_id
      AND student.status IN ('active', 'suspended')
      AND NOT EXISTS (
        SELECT 1 FROM public.student_holds AS hold
        WHERE hold.student_id = student.id
          AND hold.scope = 'full_pause'
          AND (hold.ended_at IS NULL OR p_date <= hold.ended_at::DATE)
          AND p_date BETWEEN hold.start_date AND hold.end_date
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.attendance AS attendance_row
        WHERE attendance_row.student_id = student.id
          AND attendance_row.date = p_date
      )
    RETURNING status
  )
  SELECT
    COUNT(*)::INTEGER,
    COUNT(*) FILTER (WHERE status = 'excused')::INTEGER
  INTO records_created_value, inserted_excused_value
  FROM inserted;
  records_excused_value := records_excused_value + inserted_excused_value;

  WITH inserted AS (
    INSERT INTO public.points (
      student_id, center_id, halaqa_id, type, amount,
      reason, date, resolved
    )
    SELECT
      attendance_row.student_id,
      p_center_id,
      p_halaqa_id,
      'negative',
      absence_penalty_value,
      'غياب بدون عذر (تلقائي)',
      p_date,
      TRUE
    FROM public.attendance AS attendance_row
    WHERE attendance_row.center_id = p_center_id
      AND attendance_row.halaqa_id = p_halaqa_id
      AND attendance_row.date = p_date
      AND attendance_row.status = 'absent'
      AND NOT EXISTS (
        SELECT 1 FROM public.points AS point_row
        WHERE point_row.student_id = attendance_row.student_id
          AND point_row.date = p_date
          AND point_row.reason = 'غياب بدون عذر (تلقائي)'
      )
    RETURNING 1
  ) SELECT COUNT(*)::INTEGER INTO absence_points_value FROM inserted;

  WITH inserted AS (
    INSERT INTO public.points (
      student_id, center_id, halaqa_id, type, amount,
      reason, date, resolved
    )
    SELECT
      attendance_row.student_id,
      p_center_id,
      p_halaqa_id,
      'negative',
      no_recitation_penalty_value,
      'عدم التسميع (تلقائي)',
      p_date,
      TRUE
    FROM public.attendance AS attendance_row
    WHERE attendance_row.center_id = p_center_id
      AND attendance_row.halaqa_id = p_halaqa_id
      AND attendance_row.date = p_date
      AND attendance_row.status IN ('present', 'late')
      AND COALESCE(attendance_row.recitation_exempt, FALSE) = FALSE
      AND COALESCE(attendance_row.talaqqin_done, FALSE) = FALSE
      AND NOT EXISTS (
        SELECT 1 FROM public.homework_grades AS grade
        WHERE grade.student_id = attendance_row.student_id
          AND grade.date = p_date
          AND grade.grade_mark <> 'absent'
          AND grade.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.memorization AS memorization_row
        WHERE memorization_row.student_id = attendance_row.student_id
          AND memorization_row.date = p_date
          AND memorization_row.deleted_at IS NULL
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.student_holds AS hold
        WHERE hold.student_id = attendance_row.student_id
          AND (hold.ended_at IS NULL OR p_date <= hold.ended_at::DATE)
          AND p_date BETWEEN hold.start_date AND hold.end_date
      )
      AND NOT EXISTS (
        SELECT 1 FROM public.points AS point_row
        WHERE point_row.student_id = attendance_row.student_id
          AND point_row.date = p_date
          AND point_row.reason = 'عدم التسميع (تلقائي)'
      )
    RETURNING 1
  ) SELECT COUNT(*)::INTEGER INTO no_recitation_points_value FROM inserted;

  SELECT COUNT(*)::INTEGER INTO completed_students_value
  FROM public.attendance AS attendance_row
  WHERE attendance_row.center_id = p_center_id
    AND attendance_row.halaqa_id = p_halaqa_id
    AND attendance_row.date = p_date
    AND attendance_row.status IN ('present', 'late')
    AND (
      EXISTS (
        SELECT 1 FROM public.homework_grades AS grade
        WHERE grade.student_id = attendance_row.student_id
          AND grade.date = p_date
          AND grade.grade_mark <> 'absent'
          AND grade.deleted_at IS NULL
      )
      OR EXISTS (
        SELECT 1 FROM public.memorization AS memorization_row
        WHERE memorization_row.student_id = attendance_row.student_id
          AND memorization_row.date = p_date
          AND memorization_row.deleted_at IS NULL
      )
    );

  SELECT COUNT(*)::INTEGER INTO exempt_students_value
  FROM public.attendance AS attendance_row
  WHERE attendance_row.center_id = p_center_id
    AND attendance_row.halaqa_id = p_halaqa_id
    AND attendance_row.date = p_date
    AND (
      attendance_row.status = 'excused'
      OR (
        attendance_row.status IN ('present', 'late')
        AND (
          COALESCE(attendance_row.recitation_exempt, FALSE) = TRUE
          OR COALESCE(attendance_row.talaqqin_done, FALSE) = TRUE
        )
      )
      OR (
        attendance_row.status IN ('present', 'late')
        AND EXISTS (
          SELECT 1 FROM public.student_holds AS hold
          WHERE hold.student_id = attendance_row.student_id
            AND (hold.ended_at IS NULL OR p_date <= hold.ended_at::DATE)
            AND p_date BETWEEN hold.start_date AND hold.end_date
        )
      )
    );

  INSERT INTO public.daily_closings (
    center_id, halaqa_id, closing_date,
    records_created, records_excused,
    absence_points_added, no_recitation_points_added,
    completed_students, exempt_students,
    absence_penalty, no_recitation_penalty,
    closed_by
  ) VALUES (
    p_center_id, p_halaqa_id, p_date,
    records_created_value, records_excused_value,
    absence_points_value, no_recitation_points_value,
    completed_students_value, exempt_students_value,
    absence_penalty_value, no_recitation_penalty_value,
    auth.uid()
  ) RETURNING * INTO new_closing;

  IF to_regclass('public.audit_events') IS NOT NULL THEN
    EXECUTE $audit$
      INSERT INTO public.audit_events (
        center_id, halaqa_id, actor_id, event_type, entity_type,
        entity_id, outcome, metadata
      ) VALUES ($1, $2, $3, 'daily_operations_closed', 'daily_closing', $4, 'success', $5)
    $audit$ USING
      p_center_id,
      p_halaqa_id,
      auth.uid(),
      new_closing.id,
      jsonb_build_object(
        'date', p_date,
        'records_created', records_created_value,
        'records_excused', records_excused_value,
        'absence_points_added', absence_points_value,
        'no_recitation_points_added', no_recitation_points_value
      );
  END IF;

  RETURN jsonb_build_object(
    'closing_id', new_closing.id,
    'date', new_closing.closing_date,
    'already_closed', FALSE,
    'records_created', records_created_value,
    'records_excused', records_excused_value,
    'absence_points_added', absence_points_value,
    'no_recitation_points_added', no_recitation_points_value,
    'completed_students', completed_students_value,
    'exempt_students', exempt_students_value,
    'closed_at', new_closing.closed_at
  );
END;
$$;


REVOKE ALL ON FUNCTION public.close_daily_operations(
  UUID, UUID, DATE, INTEGER, INTEGER
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.close_daily_operations(
  UUID, UUID, DATE, INTEGER, INTEGER
) TO authenticated;

COMMIT;
