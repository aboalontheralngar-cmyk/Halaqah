-- P1.27 Build 78: Friday plan policy, exact decimal points,
-- and supervisory-organization competition workflow.
BEGIN;

-- ---------------------------------------------------------------------------
-- Plans: Friday is an explicit policy instead of being forced to a holiday.
-- ---------------------------------------------------------------------------
ALTER TABLE public.plans
  ADD COLUMN IF NOT EXISTS friday_mode TEXT NOT NULL DEFAULT 'catchup_recitation';

ALTER TABLE public.plans
  DROP CONSTRAINT IF EXISTS plans_friday_mode_check;
ALTER TABLE public.plans
  ADD CONSTRAINT plans_friday_mode_check
  CHECK (friday_mode IN ('catchup_recitation', 'full_plan', 'holiday'));

-- ---------------------------------------------------------------------------
-- Behavior/recitation points: preserve true fractions such as 2.5.
-- ---------------------------------------------------------------------------
ALTER TABLE public.points
  ALTER COLUMN amount TYPE NUMERIC(10,2)
  USING amount::NUMERIC(10,2);

DO $$
BEGIN
  IF to_regclass('public.behavior_point_corrections') IS NOT NULL THEN
    EXECUTE 'ALTER TABLE public.behavior_point_corrections '
         || 'ALTER COLUMN points_snapshot TYPE NUMERIC(10,2) '
         || 'USING points_snapshot::NUMERIC(10,2)';
  END IF;
END;
$$;

-- ---------------------------------------------------------------------------
-- Supervisory competitions.
-- Supervisory owner/admin creates the season and categories. Linked centers
-- submit their own students. Supervisory members can follow results live.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.supervisor_competitions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  supervisor_id UUID NOT NULL REFERENCES public.supervisors(id) ON DELETE CASCADE,
  title TEXT NOT NULL CHECK (char_length(btrim(title)) BETWEEN 3 AND 180),
  season_year INTEGER NOT NULL CHECK (season_year BETWEEN 1400 AND 2200),
  description TEXT,
  starts_on DATE,
  ends_on DATE,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'open', 'judging', 'published', 'closed')),
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT supervisor_competition_dates_check
    CHECK (starts_on IS NULL OR ends_on IS NULL OR ends_on >= starts_on)
);

CREATE TABLE IF NOT EXISTS public.supervisor_competition_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id UUID NOT NULL REFERENCES public.supervisor_competitions(id) ON DELETE CASCADE,
  name TEXT NOT NULL CHECK (char_length(btrim(name)) BETWEEN 2 AND 140),
  from_surah INTEGER CHECK (from_surah BETWEEN 1 AND 114),
  to_surah INTEGER CHECK (to_surah BETWEEN 1 AND 114),
  maximum_score NUMERIC(8,2) NOT NULL DEFAULT 100 CHECK (maximum_score > 0),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (competition_id, name),
  CONSTRAINT supervisor_category_range_check
    CHECK (from_surah IS NULL OR to_surah IS NULL OR to_surah >= from_surah)
);

CREATE TABLE IF NOT EXISTS public.supervisor_competition_entries (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  competition_id UUID NOT NULL REFERENCES public.supervisor_competitions(id) ON DELETE CASCADE,
  category_id UUID NOT NULL REFERENCES public.supervisor_competition_categories(id) ON DELETE RESTRICT,
  center_id UUID NOT NULL REFERENCES public.centers(id) ON DELETE CASCADE,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  student_name_snapshot TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted', 'accepted', 'rejected', 'withdrawn')),
  submitted_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (competition_id, student_id)
);

CREATE TABLE IF NOT EXISTS public.supervisor_competition_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_id UUID NOT NULL UNIQUE REFERENCES public.supervisor_competition_entries(id) ON DELETE CASCADE,
  judge_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  obvious_errors INTEGER NOT NULL DEFAULT 0 CHECK (obvious_errors >= 0),
  subtle_errors INTEGER NOT NULL DEFAULT 0 CHECK (subtle_errors >= 0),
  prompt_count INTEGER NOT NULL DEFAULT 0 CHECK (prompt_count >= 0),
  stop_count INTEGER NOT NULL DEFAULT 0 CHECK (stop_count >= 0),
  tajweed_errors INTEGER NOT NULL DEFAULT 0 CHECK (tajweed_errors >= 0),
  score NUMERIC(8,2) NOT NULL CHECK (score >= 0),
  notes TEXT,
  assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_supervisor_competitions_org_status
  ON public.supervisor_competitions(supervisor_id, status, season_year DESC);
CREATE INDEX IF NOT EXISTS idx_supervisor_competition_entries_comp_category
  ON public.supervisor_competition_entries(competition_id, category_id, status);
CREATE INDEX IF NOT EXISTS idx_supervisor_competition_entries_center
  ON public.supervisor_competition_entries(center_id, submitted_at DESC);

ALTER TABLE public.supervisor_competitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_competition_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_competition_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.supervisor_competition_scores ENABLE ROW LEVEL SECURITY;

-- Linked-center admins may read only competitions belonging to the authority
-- that currently supervises their center. Supervisory analysts remain read-only.
DROP POLICY IF EXISTS supervisor_competitions_select ON public.supervisor_competitions;
CREATE POLICY supervisor_competitions_select
  ON public.supervisor_competitions FOR SELECT TO authenticated
  USING (
    public.current_user_can_access_supervisor(supervisor_id)
    OR EXISTS (
      SELECT 1 FROM public.centers c
      WHERE c.supervisor_id = supervisor_competitions.supervisor_id
        AND public.current_user_is_center_admin(c.id)
    )
  );

DROP POLICY IF EXISTS supervisor_competitions_manage ON public.supervisor_competitions;
CREATE POLICY supervisor_competitions_manage
  ON public.supervisor_competitions FOR ALL TO authenticated
  USING (public.current_user_can_manage_supervisor(supervisor_id))
  WITH CHECK (public.current_user_can_manage_supervisor(supervisor_id));

DROP POLICY IF EXISTS supervisor_competition_categories_select ON public.supervisor_competition_categories;
CREATE POLICY supervisor_competition_categories_select
  ON public.supervisor_competition_categories FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.supervisor_competitions c
    WHERE c.id = competition_id
      AND (
        public.current_user_can_access_supervisor(c.supervisor_id)
        OR EXISTS (
          SELECT 1 FROM public.centers center_row
          WHERE center_row.supervisor_id = c.supervisor_id
            AND public.current_user_is_center_admin(center_row.id)
        )
      )
  ));

DROP POLICY IF EXISTS supervisor_competition_categories_manage ON public.supervisor_competition_categories;
CREATE POLICY supervisor_competition_categories_manage
  ON public.supervisor_competition_categories FOR ALL TO authenticated
  USING (EXISTS (
    SELECT 1 FROM public.supervisor_competitions c
    WHERE c.id = competition_id
      AND public.current_user_can_manage_supervisor(c.supervisor_id)
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.supervisor_competitions c
    WHERE c.id = competition_id
      AND public.current_user_can_manage_supervisor(c.supervisor_id)
  ));

DROP POLICY IF EXISTS supervisor_competition_entries_select ON public.supervisor_competition_entries;
CREATE POLICY supervisor_competition_entries_select
  ON public.supervisor_competition_entries FOR SELECT TO authenticated
  USING (
    public.current_user_is_center_admin(center_id)
    OR EXISTS (
      SELECT 1 FROM public.supervisor_competitions c
      WHERE c.id = competition_id
        AND public.current_user_can_access_supervisor(c.supervisor_id)
    )
  );

DROP POLICY IF EXISTS supervisor_competition_scores_select ON public.supervisor_competition_scores;
CREATE POLICY supervisor_competition_scores_select
  ON public.supervisor_competition_scores FOR SELECT TO authenticated
  USING (EXISTS (
    SELECT 1
    FROM public.supervisor_competition_entries e
    JOIN public.supervisor_competitions c ON c.id = e.competition_id
    WHERE e.id = entry_id
      AND (
        public.current_user_can_access_supervisor(c.supervisor_id)
        OR public.current_user_is_center_admin(e.center_id)
      )
  ));

-- All writes for entries/scores go through guarded RPCs. This keeps the client
-- light and makes authorization atomic even when the UI is offline/retried.
REVOKE INSERT, UPDATE, DELETE ON public.supervisor_competition_entries FROM PUBLIC, anon, authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.supervisor_competition_scores FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.supervisor_competitions FROM anon;
REVOKE ALL ON public.supervisor_competition_categories FROM anon;
REVOKE ALL ON public.supervisor_competition_entries FROM anon;
REVOKE ALL ON public.supervisor_competition_scores FROM anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.supervisor_competitions TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.supervisor_competition_categories TO authenticated;
GRANT SELECT ON public.supervisor_competition_entries TO authenticated;
GRANT SELECT ON public.supervisor_competition_scores TO authenticated;

CREATE OR REPLACE FUNCTION public.submit_supervisor_competition_entry(
  p_competition_id UUID,
  p_category_id UUID,
  p_student_id UUID
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  competition_row public.supervisor_competitions%ROWTYPE;
  student_row public.students%ROWTYPE;
  entry_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'authentication_required'; END IF;

  SELECT * INTO competition_row
  FROM public.supervisor_competitions
  WHERE id = p_competition_id;
  IF competition_row.id IS NULL THEN RAISE EXCEPTION 'competition_not_found'; END IF;
  IF competition_row.status <> 'open' THEN RAISE EXCEPTION 'competition_not_open'; END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.supervisor_competition_categories
    WHERE id = p_category_id AND competition_id = p_competition_id
  ) THEN RAISE EXCEPTION 'competition_category_mismatch'; END IF;

  SELECT * INTO student_row FROM public.students WHERE id = p_student_id;
  IF student_row.id IS NULL OR student_row.center_id IS NULL THEN
    RAISE EXCEPTION 'competition_student_not_found';
  END IF;
  IF NOT public.current_user_is_center_admin(student_row.center_id) THEN
    RAISE EXCEPTION 'center_manager_required';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.centers c
    WHERE c.id = student_row.center_id
      AND c.supervisor_id = competition_row.supervisor_id
  ) THEN RAISE EXCEPTION 'center_not_linked_to_competition_supervisor'; END IF;

  INSERT INTO public.supervisor_competition_entries (
    competition_id, category_id, center_id, student_id,
    student_name_snapshot, status, submitted_by
  ) VALUES (
    p_competition_id, p_category_id, student_row.center_id, p_student_id,
    student_row.name, 'submitted', auth.uid()
  )
  ON CONFLICT (competition_id, student_id) DO UPDATE SET
    category_id = EXCLUDED.category_id,
    center_id = EXCLUDED.center_id,
    student_name_snapshot = EXCLUDED.student_name_snapshot,
    status = 'submitted',
    submitted_by = auth.uid(),
    submitted_at = now(),
    updated_at = now()
  RETURNING id INTO entry_id;

  INSERT INTO public.supervisor_audit_events(
    supervisor_id, center_id, actor_id, event_type, metadata
  ) VALUES (
    competition_row.supervisor_id, student_row.center_id, auth.uid(),
    'competition.entry_submitted',
    jsonb_build_object('competition_id', p_competition_id, 'entry_id', entry_id, 'student_id', p_student_id)
  );
  RETURN entry_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.withdraw_supervisor_competition_entry(p_entry_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE entry_row public.supervisor_competition_entries%ROWTYPE;
BEGIN
  SELECT * INTO entry_row FROM public.supervisor_competition_entries WHERE id = p_entry_id;
  IF entry_row.id IS NULL THEN RAISE EXCEPTION 'competition_entry_not_found'; END IF;
  IF NOT public.current_user_is_center_admin(entry_row.center_id) THEN
    RAISE EXCEPTION 'center_manager_required';
  END IF;
  UPDATE public.supervisor_competition_entries
  SET status = 'withdrawn', updated_at = now()
  WHERE id = p_entry_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.score_supervisor_competition_entry(
  p_entry_id UUID,
  p_score NUMERIC,
  p_obvious_errors INTEGER DEFAULT 0,
  p_subtle_errors INTEGER DEFAULT 0,
  p_prompt_count INTEGER DEFAULT 0,
  p_stop_count INTEGER DEFAULT 0,
  p_tajweed_errors INTEGER DEFAULT 0,
  p_notes TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  entry_row public.supervisor_competition_entries%ROWTYPE;
  competition_row public.supervisor_competitions%ROWTYPE;
  category_max NUMERIC;
  score_id UUID;
BEGIN
  SELECT * INTO entry_row FROM public.supervisor_competition_entries WHERE id = p_entry_id;
  IF entry_row.id IS NULL THEN RAISE EXCEPTION 'competition_entry_not_found'; END IF;
  SELECT * INTO competition_row FROM public.supervisor_competitions WHERE id = entry_row.competition_id;
  IF NOT public.current_user_can_manage_supervisor(competition_row.supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_manager_required';
  END IF;
  SELECT maximum_score INTO category_max
  FROM public.supervisor_competition_categories WHERE id = entry_row.category_id;
  IF p_score < 0 OR p_score > coalesce(category_max, 100) THEN
    RAISE EXCEPTION 'competition_score_out_of_range';
  END IF;

  INSERT INTO public.supervisor_competition_scores(
    entry_id, judge_user_id, obvious_errors, subtle_errors,
    prompt_count, stop_count, tajweed_errors, score, notes
  ) VALUES (
    p_entry_id, auth.uid(), greatest(p_obvious_errors,0), greatest(p_subtle_errors,0),
    greatest(p_prompt_count,0), greatest(p_stop_count,0), greatest(p_tajweed_errors,0),
    round(p_score, 2), nullif(btrim(coalesce(p_notes,'')), '')
  )
  ON CONFLICT (entry_id) DO UPDATE SET
    judge_user_id = auth.uid(),
    obvious_errors = EXCLUDED.obvious_errors,
    subtle_errors = EXCLUDED.subtle_errors,
    prompt_count = EXCLUDED.prompt_count,
    stop_count = EXCLUDED.stop_count,
    tajweed_errors = EXCLUDED.tajweed_errors,
    score = EXCLUDED.score,
    notes = EXCLUDED.notes,
    assessed_at = now(),
    updated_at = now()
  RETURNING id INTO score_id;

  UPDATE public.supervisor_competition_entries
  SET status = 'accepted', updated_at = now() WHERE id = p_entry_id;
  RETURN score_id;
END;
$$;

REVOKE ALL ON FUNCTION public.submit_supervisor_competition_entry(UUID, UUID, UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.withdraw_supervisor_competition_entry(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.score_supervisor_competition_entry(UUID, NUMERIC, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_supervisor_competition_entry(UUID, UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.withdraw_supervisor_competition_entry(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.score_supervisor_competition_entry(UUID, NUMERIC, INTEGER, INTEGER, INTEGER, INTEGER, INTEGER, TEXT) TO authenticated;

COMMIT;
