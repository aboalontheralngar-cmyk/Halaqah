-- P5.6: one authoritative recitation mutation for Web and Android.
-- Copy this file's CONTENTS into Supabase SQL Editor after taking a backup.

BEGIN;

-- Self-contained scope helpers for databases that did not run earlier files.
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

CREATE OR REPLACE FUNCTION public.current_user_can_access_student(
  p_student_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.students student
    WHERE student.id = p_student_id
      AND public.current_user_can_access_halaqa(
        student.center_id,
        student.halaqa_id
      )
  );
$$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_student(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_student(UUID)
  TO authenticated;

ALTER TABLE public.homework_grades
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

ALTER TABLE public.memorization
  ADD COLUMN IF NOT EXISTS halaqa_id UUID
    REFERENCES public.halaqat(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS session_type TEXT NOT NULL DEFAULT 'new',
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

UPDATE public.homework_grades grade
SET center_id = student.center_id,
    halaqa_id = student.halaqa_id
FROM public.students student
WHERE grade.student_id = student.id
  AND (
    grade.center_id IS NULL
    OR grade.halaqa_id IS NULL
  );

UPDATE public.memorization progress
SET center_id = student.center_id,
    halaqa_id = student.halaqa_id
FROM public.students student
WHERE progress.student_id = student.id
  AND (
    progress.center_id IS NULL
    OR progress.halaqa_id IS NULL
  );

UPDATE public.memorization
SET session_type = 'new'
WHERE session_type IS NULL;
ALTER TABLE public.memorization
  ALTER COLUMN session_type SET DEFAULT 'new',
  ALTER COLUMN session_type SET NOT NULL;

ALTER TABLE public.memorization
  DROP CONSTRAINT IF EXISTS memorization_session_type_check;
ALTER TABLE public.memorization
  ADD CONSTRAINT memorization_session_type_check
  CHECK (session_type IN ('new', 'review'));

CREATE INDEX IF NOT EXISTS idx_homework_grades_active_scope_date
  ON public.homework_grades(center_id, halaqa_id, date DESC)
  WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_memorization_active_scope_date
  ON public.memorization(center_id, halaqa_id, date DESC)
  WHERE deleted_at IS NULL;

-- Backfill old web grades only when no matching memorization row exists.
INSERT INTO public.memorization (
  id,
  student_id,
  center_id,
  halaqa_id,
  surah,
  from_ayah,
  to_ayah,
  degree,
  date,
  notes,
  session_type,
  created_at,
  updated_at
)
SELECT
  grade.id,
  grade.student_id,
  grade.center_id,
  grade.halaqa_id,
  grade.surah,
  grade.from_ayah,
  grade.to_ayah,
  CASE grade.grade_mark
    WHEN 'excellent' THEN 5
    WHEN 'very_good' THEN 4
    WHEN 'good' THEN 3
    WHEN 'needs_work' THEN 2
    ELSE 1
  END,
  grade.date,
  grade.remark,
  CASE WHEN grade.is_revision THEN 'review' ELSE 'new' END,
  grade.created_at,
  grade.updated_at
FROM public.homework_grades grade
WHERE grade.deleted_at IS NULL
  AND grade.grade_mark <> 'absent'
  AND NOT EXISTS (
    SELECT 1
    FROM public.memorization progress
    WHERE progress.student_id = grade.student_id
      AND progress.surah = grade.surah
      AND progress.from_ayah = grade.from_ayah
      AND progress.to_ayah = grade.to_ayah
      AND progress.date = grade.date
      AND progress.session_type = CASE
        WHEN grade.is_revision THEN 'review' ELSE 'new'
      END
      AND progress.deleted_at IS NULL
      AND ABS(EXTRACT(EPOCH FROM (
        progress.created_at - grade.created_at
      ))) <= 15
  )
ON CONFLICT (id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.save_recitation_record(
  p_record_id UUID,
  p_student_id UUID,
  p_surah TEXT,
  p_from_ayah INTEGER,
  p_to_ayah INTEGER,
  p_date DATE,
  p_grade_mark TEXT,
  p_mistakes_count INTEGER,
  p_is_revision BOOLEAN,
  p_remark TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_student public.students%ROWTYPE;
  old_grade public.homework_grades%ROWTYPE;
  companion_id UUID;
  numeric_grade INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO target_student
  FROM public.students WHERE id = p_student_id;
  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_student.center_id,
    target_student.halaqa_id
  ) THEN
    RAISE EXCEPTION 'student_not_accessible';
  END IF;
  IF target_student.status NOT IN ('active', 'graduated') THEN
    RAISE EXCEPTION 'student_not_available_for_recitation';
  END IF;
  IF NULLIF(BTRIM(p_surah), '') IS NULL
     OR p_from_ayah < 1
     OR p_to_ayah < p_from_ayah
     OR p_mistakes_count < 0
     OR p_grade_mark NOT IN (
       'excellent', 'very_good', 'good', 'needs_work', 'absent'
     ) THEN
    RAISE EXCEPTION 'invalid_recitation_payload';
  END IF;

  SELECT * INTO old_grade
  FROM public.homework_grades
  WHERE id = p_record_id;
  IF FOUND AND old_grade.student_id IS DISTINCT FROM p_student_id THEN
    RAISE EXCEPTION 'record_student_cannot_change';
  END IF;

  IF old_grade.id IS NOT NULL THEN
    SELECT progress.id INTO companion_id
    FROM public.memorization progress
    WHERE progress.deleted_at IS NULL
      AND progress.student_id = old_grade.student_id
      AND progress.surah = old_grade.surah
      AND progress.from_ayah = old_grade.from_ayah
      AND progress.to_ayah = old_grade.to_ayah
      AND progress.date = old_grade.date
      AND progress.session_type = CASE
        WHEN old_grade.is_revision THEN 'review' ELSE 'new'
      END
    ORDER BY
      CASE WHEN progress.id = old_grade.id THEN 0 ELSE 1 END,
      ABS(EXTRACT(EPOCH FROM (
        progress.created_at - old_grade.created_at
      )))
    LIMIT 1;
  END IF;

  INSERT INTO public.homework_grades (
    id, student_id, center_id, halaqa_id, surah, from_ayah, to_ayah,
    date, grade_mark, mistakes_count, is_revision, remark,
    created_at, updated_at, deleted_at
  ) VALUES (
    p_record_id, p_student_id, target_student.center_id,
    target_student.halaqa_id, BTRIM(p_surah), p_from_ayah, p_to_ayah,
    p_date, p_grade_mark, p_mistakes_count, p_is_revision,
    NULLIF(BTRIM(p_remark), ''), now(), now(), NULL
  )
  ON CONFLICT (id) DO UPDATE SET
    surah = EXCLUDED.surah,
    from_ayah = EXCLUDED.from_ayah,
    to_ayah = EXCLUDED.to_ayah,
    date = EXCLUDED.date,
    grade_mark = EXCLUDED.grade_mark,
    mistakes_count = EXCLUDED.mistakes_count,
    is_revision = EXCLUDED.is_revision,
    remark = EXCLUDED.remark,
    updated_at = now(),
    deleted_at = NULL;

  numeric_grade := CASE p_grade_mark
    WHEN 'excellent' THEN 5
    WHEN 'very_good' THEN 4
    WHEN 'good' THEN 3
    WHEN 'needs_work' THEN 2
    ELSE 1
  END;

  IF p_grade_mark = 'absent' THEN
    UPDATE public.memorization
    SET deleted_at = now(), updated_at = now()
    WHERE id = COALESCE(companion_id, p_record_id);
  ELSE
    INSERT INTO public.memorization (
      id, student_id, center_id, halaqa_id, surah, from_ayah, to_ayah,
      degree, date, notes, session_type, created_at, updated_at, deleted_at
    ) VALUES (
      COALESCE(companion_id, p_record_id), p_student_id,
      target_student.center_id, target_student.halaqa_id, BTRIM(p_surah),
      p_from_ayah, p_to_ayah, numeric_grade, p_date,
      NULLIF(BTRIM(p_remark), ''),
      CASE WHEN p_is_revision THEN 'review' ELSE 'new' END,
      now(), now(), NULL
    )
    ON CONFLICT (id) DO UPDATE SET
      surah = EXCLUDED.surah,
      from_ayah = EXCLUDED.from_ayah,
      to_ayah = EXCLUDED.to_ayah,
      degree = EXCLUDED.degree,
      date = EXCLUDED.date,
      notes = EXCLUDED.notes,
      session_type = EXCLUDED.session_type,
      updated_at = now(),
      deleted_at = NULL;
  END IF;

  RETURN p_record_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_recitation_record(p_record_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_grade public.homework_grades%ROWTYPE;
  companion_id UUID;
BEGIN
  SELECT * INTO target_grade
  FROM public.homework_grades
  WHERE id = p_record_id AND deleted_at IS NULL;
  IF NOT FOUND THEN RETURN FALSE; END IF;
  IF NOT public.current_user_can_access_halaqa(
    target_grade.center_id,
    target_grade.halaqa_id
  ) THEN
    RAISE EXCEPTION 'record_not_accessible';
  END IF;

  SELECT progress.id INTO companion_id
  FROM public.memorization progress
  WHERE progress.deleted_at IS NULL
    AND progress.student_id = target_grade.student_id
    AND progress.surah = target_grade.surah
    AND progress.from_ayah = target_grade.from_ayah
    AND progress.to_ayah = target_grade.to_ayah
    AND progress.date = target_grade.date
    AND progress.session_type = CASE
      WHEN target_grade.is_revision THEN 'review' ELSE 'new'
    END
  ORDER BY
    CASE WHEN progress.id = target_grade.id THEN 0 ELSE 1 END,
    ABS(EXTRACT(EPOCH FROM (
      progress.created_at - target_grade.created_at
    )))
  LIMIT 1;

  UPDATE public.homework_grades
  SET deleted_at = now(), updated_at = now()
  WHERE id = p_record_id;
  IF companion_id IS NOT NULL THEN
    UPDATE public.memorization
    SET deleted_at = now(), updated_at = now()
    WHERE id = companion_id;
  END IF;
  RETURN TRUE;
END;
$$;

REVOKE ALL ON FUNCTION public.save_recitation_record(
  UUID, UUID, TEXT, INTEGER, INTEGER, DATE, TEXT, INTEGER, BOOLEAN, TEXT
) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_recitation_record(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_recitation_record(
  UUID, UUID, TEXT, INTEGER, INTEGER, DATE, TEXT, INTEGER, BOOLEAN, TEXT
) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_recitation_record(UUID)
  TO authenticated;

ALTER TABLE public.homework_grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memorization ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Access homework_grades by center" ON public.homework_grades;
DROP POLICY IF EXISTS "Access homework_grades by center_id" ON public.homework_grades;
DROP POLICY IF EXISTS homework_grades_access ON public.homework_grades;
DROP POLICY IF EXISTS homework_grades_scoped_access ON public.homework_grades;
CREATE POLICY homework_grades_scoped_access
  ON public.homework_grades FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

DROP POLICY IF EXISTS memorization_access ON public.memorization;
DROP POLICY IF EXISTS memorization_scoped_access ON public.memorization;
DROP POLICY IF EXISTS "Access memorization by center_id" ON public.memorization;
CREATE POLICY memorization_scoped_access
  ON public.memorization FOR ALL
  USING (public.current_user_can_access_halaqa(center_id, halaqa_id))
  WITH CHECK (public.current_user_can_access_halaqa(center_id, halaqa_id));

COMMIT;
