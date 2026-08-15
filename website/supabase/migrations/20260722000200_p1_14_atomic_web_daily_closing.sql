-- P1.14: atomic Web daily closing, cloud study suspensions, and weekly holidays.
-- In Supabase SQL Editor paste this file's CONTENTS only, not its filename.
-- Prerequisites: the core schema, P3 student holds, P5 Web recitation, and the
-- current_user_can_access_halaqa(UUID, UUID) compatibility helper.

BEGIN;

ALTER TABLE public.center_settings
  ADD COLUMN IF NOT EXISTS session_end_time TIME NOT NULL DEFAULT '18:00',
  ADD COLUMN IF NOT EXISTS timezone_name TEXT NOT NULL DEFAULT 'Asia/Aden',
  ADD COLUMN IF NOT EXISTS weekly_holiday_days SMALLINT[] NOT NULL DEFAULT ARRAY[5]::SMALLINT[],
  ADD COLUMN IF NOT EXISTS points_config JSONB NOT NULL DEFAULT '{
    "daily_memorization": 5,
    "extra_memorization": 2,
    "early_attendance": 2,
    "revision_complete": 3,
    "late_penalty": -2,
    "incomplete_penalty": -3,
    "unexcused_absence": -10,
    "appearance_violation": -3,
    "no_thobe": -3
  }'::JSONB;

ALTER TABLE public.center_settings
  DROP CONSTRAINT IF EXISTS center_settings_weekly_holiday_days_check;
ALTER TABLE public.center_settings
  ADD CONSTRAINT center_settings_weekly_holiday_days_check
  CHECK (
    weekly_holiday_days <@ ARRAY[0, 1, 2, 3, 4, 5, 6]::SMALLINT[]
  );

CREATE OR REPLACE FUNCTION public.validate_daily_schedule_settings()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_catalog.pg_timezone_names
    WHERE name = NEW.timezone_name
  ) THEN
    RAISE EXCEPTION 'invalid_timezone_name';
  END IF;
  NEW.weekly_holiday_days := ARRAY(
    SELECT DISTINCT day_value
    FROM unnest(NEW.weekly_holiday_days) AS day_value
    ORDER BY day_value
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS validate_daily_schedule_settings
  ON public.center_settings;
CREATE TRIGGER validate_daily_schedule_settings
  BEFORE INSERT OR UPDATE OF timezone_name, weekly_holiday_days
  ON public.center_settings
  FOR EACH ROW EXECUTE FUNCTION public.validate_daily_schedule_settings();

REVOKE ALL ON FUNCTION public.validate_daily_schedule_settings()
  FROM PUBLIC, anon, authenticated;

CREATE TABLE IF NOT EXISTS public.study_suspensions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  reason TEXT NOT NULL CHECK (char_length(BTRIM(reason)) BETWEEN 3 AND 500),
  created_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_study_suspensions_scope_date
  ON public.study_suspensions(
    center_id,
    COALESCE(halaqa_id, '00000000-0000-0000-0000-000000000000'::UUID),
    date
  );
CREATE INDEX IF NOT EXISTS idx_study_suspensions_scope_date
  ON public.study_suspensions(center_id, halaqa_id, date DESC);

CREATE TABLE IF NOT EXISTS public.daily_closings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID NOT NULL REFERENCES public.halaqat(id) ON DELETE CASCADE,
  closing_date DATE NOT NULL,
  records_created INTEGER NOT NULL DEFAULT 0 CHECK (records_created >= 0),
  records_excused INTEGER NOT NULL DEFAULT 0 CHECK (records_excused >= 0),
  absence_points_added INTEGER NOT NULL DEFAULT 0 CHECK (absence_points_added >= 0),
  no_recitation_points_added INTEGER NOT NULL DEFAULT 0 CHECK (no_recitation_points_added >= 0),
  completed_students INTEGER NOT NULL DEFAULT 0 CHECK (completed_students >= 0),
  exempt_students INTEGER NOT NULL DEFAULT 0 CHECK (exempt_students >= 0),
  absence_penalty INTEGER NOT NULL CHECK (absence_penalty BETWEEN -100 AND -1),
  no_recitation_penalty INTEGER NOT NULL CHECK (no_recitation_penalty BETWEEN -100 AND -1),
  closed_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE RESTRICT,
  closed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(center_id, halaqa_id, closing_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_closings_scope_date
  ON public.daily_closings(center_id, halaqa_id, closing_date DESC);

ALTER TABLE public.study_suspensions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_closings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS study_suspensions_scoped_select
  ON public.study_suspensions;
CREATE POLICY study_suspensions_scoped_select
  ON public.study_suspensions FOR SELECT TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS daily_closings_scoped_select
  ON public.daily_closings;
CREATE POLICY daily_closings_scoped_select
  ON public.daily_closings FOR SELECT TO authenticated
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id));

REVOKE ALL ON public.study_suspensions FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.daily_closings FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.study_suspensions TO authenticated;
GRANT SELECT ON public.daily_closings TO authenticated;

CREATE OR REPLACE FUNCTION public.set_study_suspension(
  p_center_id UUID,
  p_halaqa_id UUID,
  p_date DATE,
  p_suspended BOOLEAN,
  p_reason TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_id UUID;
  target_reason TEXT;
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

  IF EXISTS (
    SELECT 1 FROM public.daily_closings
    WHERE center_id = p_center_id
      AND halaqa_id = p_halaqa_id
      AND closing_date = p_date
  ) THEN
    RAISE EXCEPTION 'day_already_closed';
  END IF;

  IF p_suspended THEN
    target_reason := BTRIM(COALESCE(p_reason, ''));
    IF char_length(target_reason) NOT BETWEEN 3 AND 500 THEN
      RAISE EXCEPTION 'suspension_reason_required';
    END IF;

    SELECT id INTO target_id
    FROM public.study_suspensions
    WHERE center_id = p_center_id
      AND halaqa_id = p_halaqa_id
      AND date = p_date;

    IF target_id IS NULL THEN
      INSERT INTO public.study_suspensions (
        center_id, halaqa_id, date, reason, created_by
      ) VALUES (
        p_center_id, p_halaqa_id, p_date, target_reason, auth.uid()
      ) RETURNING id INTO target_id;
    ELSE
      UPDATE public.study_suspensions
      SET reason = target_reason,
          updated_at = now()
      WHERE id = target_id;
    END IF;
  ELSE
    DELETE FROM public.study_suspensions
    WHERE center_id = p_center_id
      AND halaqa_id = p_halaqa_id
      AND date = p_date
    RETURNING id, reason INTO target_id, target_reason;
  END IF;

  IF to_regclass('public.audit_events') IS NOT NULL THEN
    EXECUTE $audit$
      INSERT INTO public.audit_events (
        center_id, halaqa_id, actor_id, event_type, entity_type,
        entity_id, outcome, metadata
      ) VALUES ($1, $2, $3, $4, 'study_suspension', $5, 'success', $6)
    $audit$ USING
      p_center_id,
      p_halaqa_id,
      auth.uid(),
      CASE WHEN p_suspended THEN 'study_suspension_set' ELSE 'study_suspension_removed' END,
      target_id,
      jsonb_build_object('date', p_date, 'reason', target_reason);
  END IF;

  RETURN jsonb_build_object(
    'id', target_id,
    'date', p_date,
    'suspended', p_suspended,
    'reason', target_reason
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_daily_closing_state(
  p_center_id UUID,
  p_halaqa_id UUID,
  p_date DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  session_end TIME := '18:00';
  timezone_value TEXT := 'Asia/Aden';
  holiday_days SMALLINT[] := ARRAY[5]::SMALLINT[];
  local_now TIMESTAMP;
  is_weekly BOOLEAN := FALSE;
  suspension_reason TEXT;
  existing_closing public.daily_closings%ROWTYPE;
  blocker_value TEXT;
  can_close_value BOOLEAN := FALSE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF p_center_id IS NULL OR p_date IS NULL THEN
    RAISE EXCEPTION 'center_and_date_required';
  END IF;
  IF NOT public.current_user_can_access_halaqa(p_center_id, p_halaqa_id) THEN
    RAISE EXCEPTION 'scope_not_accessible';
  END IF;
  IF p_halaqa_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.halaqat
    WHERE id = p_halaqa_id AND center_id = p_center_id
  ) THEN
    RAISE EXCEPTION 'halaqa_scope_mismatch';
  END IF;

  SELECT
    COALESCE(settings.session_end_time, '18:00'::TIME),
    COALESCE(NULLIF(BTRIM(settings.timezone_name), ''), 'Asia/Aden'),
    COALESCE(settings.weekly_holiday_days, ARRAY[5]::SMALLINT[])
  INTO session_end, timezone_value, holiday_days
  FROM public.center_settings AS settings
  WHERE settings.center_id = p_center_id;

  session_end := COALESCE(session_end, '18:00'::TIME);
  timezone_value := COALESCE(NULLIF(BTRIM(timezone_value), ''), 'Asia/Aden');
  holiday_days := COALESCE(holiday_days, ARRAY[5]::SMALLINT[]);

  BEGIN
    local_now := now() AT TIME ZONE timezone_value;
  EXCEPTION WHEN invalid_parameter_value THEN
    timezone_value := 'Asia/Aden';
    local_now := now() AT TIME ZONE timezone_value;
  END;

  is_weekly := EXTRACT(DOW FROM p_date)::SMALLINT = ANY(holiday_days);
  SELECT suspension.reason INTO suspension_reason
  FROM public.study_suspensions AS suspension
  WHERE suspension.center_id = p_center_id
    AND suspension.date = p_date
    AND (suspension.halaqa_id IS NULL OR suspension.halaqa_id = p_halaqa_id)
  ORDER BY suspension.halaqa_id NULLS LAST
  LIMIT 1;

  IF p_halaqa_id IS NOT NULL THEN
    SELECT * INTO existing_closing
    FROM public.daily_closings
    WHERE center_id = p_center_id
      AND halaqa_id = p_halaqa_id
      AND closing_date = p_date;
  END IF;

  blocker_value := CASE
    WHEN p_halaqa_id IS NULL THEN 'halaqa_required'
    WHEN existing_closing.id IS NOT NULL THEN 'already_closed'
    WHEN is_weekly OR suspension_reason IS NOT NULL THEN 'study_suspended'
    WHEN p_date > local_now::DATE THEN 'future_date'
    WHEN p_date = local_now::DATE AND local_now::TIME < session_end THEN 'before_end_time'
    ELSE NULL
  END;
  can_close_value := blocker_value IS NULL;

  RETURN jsonb_build_object(
    'date', p_date,
    'is_closed', existing_closing.id IS NOT NULL,
    'is_suspended', is_weekly OR suspension_reason IS NOT NULL,
    'is_weekly_holiday', is_weekly,
    'suspension_reason', COALESCE(suspension_reason, CASE WHEN is_weekly THEN 'إجازة أسبوعية' END),
    'can_close', can_close_value,
    'blocker', blocker_value,
    'session_end_time', to_char(session_end, 'HH24:MI'),
    'timezone_name', timezone_value,
    'closed_at', existing_closing.closed_at,
    'closed_by', existing_closing.closed_by
  );
END;
$$;

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
        absence_reason = 'إجازة معتمدة',
        notes = COALESCE(NULLIF(attendance_row.notes, ''), 'صُحح تلقائيًا عند إغلاق اليوم')
    WHERE attendance_row.center_id = p_center_id
      AND attendance_row.halaqa_id = p_halaqa_id
      AND attendance_row.date = p_date
      AND attendance_row.status = 'absent'
      AND EXISTS (
        SELECT 1 FROM public.vacations AS vacation
        WHERE vacation.student_id = attendance_row.student_id
          AND vacation.approved = TRUE
          AND p_date BETWEEN vacation.start_date AND vacation.end_date
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
          AND hold.ended_at IS NULL
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
        AND EXISTS (
          SELECT 1 FROM public.student_holds AS hold
          WHERE hold.student_id = attendance_row.student_id
            AND hold.ended_at IS NULL
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

REVOKE ALL ON FUNCTION public.set_study_suspension(
  UUID, UUID, DATE, BOOLEAN, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.get_daily_closing_state(
  UUID, UUID, DATE
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.close_daily_operations(
  UUID, UUID, DATE, INTEGER, INTEGER
) FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.set_study_suspension(
  UUID, UUID, DATE, BOOLEAN, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_daily_closing_state(
  UUID, UUID, DATE
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.close_daily_operations(
  UUID, UUID, DATE, INTEGER, INTEGER
) TO authenticated;

COMMIT;
