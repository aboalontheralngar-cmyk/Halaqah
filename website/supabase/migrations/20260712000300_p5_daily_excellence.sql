-- P5.3: daily excellence, automatic over-plan snapshots, and rewards.
-- Copy this file's CONTENTS into Supabase SQL Editor after taking a backup.

BEGIN;

CREATE OR REPLACE FUNCTION public.current_user_is_center_admin(p_center_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT auth.uid() IS NOT NULL AND (
    EXISTS (
      SELECT 1 FROM public.centers c
      WHERE c.id = p_center_id AND c.owner_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.center_members cm
      WHERE cm.center_id = p_center_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'admin'
    )
    OR EXISTS (
      SELECT 1
      FROM public.centers c
      JOIN public.supervisors supervisor ON supervisor.id = c.supervisor_id
      WHERE c.id = p_center_id AND supervisor.owner_id = auth.uid()
    )
  );
$$;

CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa(
  p_center_id UUID,
  p_halaqa_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT public.current_user_is_center_admin(p_center_id)
    OR EXISTS (
      SELECT 1 FROM public.center_members cm
      WHERE cm.center_id = p_center_id
        AND cm.user_id = auth.uid()
        AND cm.role = 'teacher'
        AND p_halaqa_id IS NOT NULL
        AND cm.halaqah_id = p_halaqa_id
    );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  TO authenticated;

-- Needed by reward points even if the previous migration was not run yet.
ALTER TABLE public.points
  ADD COLUMN IF NOT EXISTS halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS public.daily_achievements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  date DATE NOT NULL,
  source TEXT NOT NULL DEFAULT 'manual',
  reason TEXT NOT NULL,
  actual_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  plan_amount NUMERIC(10,2) NOT NULL DEFAULT 0,
  unit TEXT NOT NULL DEFAULT 'ayahs',
  reward_type TEXT,
  reward_details TEXT,
  reward_points INTEGER NOT NULL DEFAULT 0,
  awarded_at TIMESTAMPTZ,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(student_id, date),
  CHECK (source IN ('automatic', 'manual')),
  CHECK (unit IN ('ayahs', 'pages', 'lines')),
  CHECK (reward_type IS NULL OR reward_type IN ('points', 'certificate', 'gift', 'meal', 'other')),
  CHECK (actual_amount >= 0 AND plan_amount >= 0 AND reward_points >= 0)
);

CREATE INDEX IF NOT EXISTS idx_daily_achievements_scope_date
  ON public.daily_achievements(center_id, halaqa_id, date DESC);

CREATE OR REPLACE FUNCTION public.scope_daily_achievement()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target public.students%ROWTYPE;
BEGIN
  SELECT * INTO target FROM public.students WHERE id = NEW.student_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'student_not_found'; END IF;
  IF target.status NOT IN ('active', 'suspended') THEN
    RAISE EXCEPTION 'archived_student_cannot_be_recognized';
  END IF;
  IF NULLIF(BTRIM(NEW.reason), '') IS NULL THEN
    RAISE EXCEPTION 'achievement_reason_required';
  END IF;
  NEW.center_id := target.center_id;
  NEW.halaqa_id := target.halaqa_id;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS scope_daily_achievement ON public.daily_achievements;
CREATE TRIGGER scope_daily_achievement
  BEFORE INSERT OR UPDATE ON public.daily_achievements
  FOR EACH ROW EXECUTE FUNCTION public.scope_daily_achievement();

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
     OR p_unit NOT IN ('ayahs', 'pages', 'lines')
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

REVOKE ALL ON FUNCTION public.scope_daily_achievement()
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.award_daily_achievement(
  UUID, DATE, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.award_daily_achievement(
  UUID, DATE, TEXT, TEXT, NUMERIC, NUMERIC, TEXT, TEXT, TEXT, INTEGER, TEXT
) TO authenticated;

ALTER TABLE public.daily_achievements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS daily_achievements_scoped_access
  ON public.daily_achievements;
CREATE POLICY daily_achievements_scoped_access
  ON public.daily_achievements FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

COMMIT;
