-- P1.5: connected Quran ranges and hizb-based memorization/revision plans.
-- Additive compatibility migration. It preserves all existing data.

BEGIN;

ALTER TABLE public.students
  DROP CONSTRAINT IF EXISTS students_plan_type_check;
ALTER TABLE public.students
  ADD CONSTRAINT students_plan_type_check
  CHECK (plan_type IN ('ayahs', 'pages', 'lines', 'hizbs'));

ALTER TABLE public.plans
  DROP CONSTRAINT IF EXISTS plans_unit_check;
ALTER TABLE public.plans
  DROP CONSTRAINT IF EXISTS plans_valid_unit;
ALTER TABLE public.plans
  ADD CONSTRAINT plans_valid_unit
  CHECK (unit IN ('ayahs', 'pages', 'lines', 'hizbs'));

ALTER TABLE public.daily_achievements
  DROP CONSTRAINT IF EXISTS daily_achievements_unit_check;
ALTER TABLE public.daily_achievements
  ADD CONSTRAINT daily_achievements_unit_check
  CHECK (unit IN ('ayahs', 'pages', 'lines', 'hizbs'));

CREATE OR REPLACE FUNCTION public.award_daily_achievement(
  p_student_id UUID,
  p_date DATE,
  p_source TEXT,
  p_reason TEXT,
  p_actual_amount NUMERIC,
  p_plan_amount NUMERIC,
  p_unit TEXT,
  p_reward_type TEXT,
  p_reward_details TEXT DEFAULT NULL,
  p_reward_points INTEGER DEFAULT 0,
  p_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target public.students%ROWTYPE;
  point_reason TEXT;
BEGIN
  IF p_source NOT IN ('automatic', 'manual')
     OR p_unit NOT IN ('ayahs', 'pages', 'lines', 'hizbs')
     OR p_reward_type NOT IN ('points', 'certificate', 'gift', 'meal', 'other')
     OR NULLIF(BTRIM(p_reason), '') IS NULL
     OR p_actual_amount < 0
     OR p_plan_amount < 0
     OR (p_reward_type = 'points' AND p_reward_points < 1) THEN
    RAISE EXCEPTION 'invalid_daily_achievement';
  END IF;

  SELECT * INTO target FROM public.students WHERE id = p_student_id;
  IF NOT FOUND
     OR target.status NOT IN ('active', 'suspended')
     OR NOT public.current_user_can_access_halaqa(target.center_id, target.halaqa_id) THEN
    RAISE EXCEPTION 'student_not_accessible';
  END IF;

  INSERT INTO public.daily_achievements (
    student_id, center_id, halaqa_id, date, source, reason,
    actual_amount, plan_amount, unit, reward_type, reward_details,
    reward_points, awarded_at, notes, updated_at
  ) VALUES (
    target.id, target.center_id, target.halaqa_id, p_date, p_source,
    BTRIM(p_reason), p_actual_amount, p_plan_amount, p_unit,
    p_reward_type, NULLIF(BTRIM(p_reward_details), ''),
    CASE WHEN p_reward_type = 'points' THEN p_reward_points ELSE 0 END,
    now(), NULLIF(BTRIM(p_notes), ''), now()
  )
  ON CONFLICT (student_id, date) DO UPDATE SET
    source = EXCLUDED.source,
    reason = EXCLUDED.reason,
    actual_amount = EXCLUDED.actual_amount,
    plan_amount = EXCLUDED.plan_amount,
    unit = EXCLUDED.unit,
    reward_type = EXCLUDED.reward_type,
    reward_details = EXCLUDED.reward_details,
    reward_points = EXCLUDED.reward_points,
    awarded_at = EXCLUDED.awarded_at,
    notes = COALESCE(EXCLUDED.notes, public.daily_achievements.notes),
    updated_at = now();

  point_reason := 'تكريم متميز اليوم ' || p_date::TEXT;
  DELETE FROM public.points
  WHERE student_id = target.id
    AND reason = point_reason
    AND date = p_date
    AND (p_reward_type <> 'points' OR amount <> p_reward_points);

  IF p_reward_type = 'points' AND NOT EXISTS (
    SELECT 1 FROM public.points
    WHERE student_id = target.id AND reason = point_reason AND date = p_date
  ) THEN
    INSERT INTO public.points (
      student_id, center_id, halaqa_id, type, amount, reason, date, resolved
    ) VALUES (
      target.id, target.center_id, target.halaqa_id, 'positive',
      p_reward_points, point_reason, p_date, true
    );
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.award_daily_achievement(
  UUID, DATE, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_daily_achievement(
  UUID, DATE, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER, TEXT
) TO authenticated;

COMMENT ON COLUMN public.students.plan_type IS
  'Daily plan unit: ayahs, pages, lines, or hizbs.';

COMMIT;
