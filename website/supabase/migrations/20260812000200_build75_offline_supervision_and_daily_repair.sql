-- Build 75 / P1.27 / 2026-08-12
-- Supervision direct-center creation, backdated study-suspension rollback,
-- monthly-plan exams, and durable hard-delete tombstones for offline-first sync.
-- Idempotent and data-preserving: no owner/student/center data is recreated.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Supervisory organizations can create centers directly from their portal.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_supervised_center(
  p_supervisor_id UUID,
  p_name TEXT,
  p_type TEXT,
  p_address TEXT DEFAULT NULL,
  p_halaqah_name TEXT DEFAULT NULL,
  p_teacher_name TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  normalized_name TEXT := btrim(coalesce(p_name, ''));
  normalized_address TEXT := nullif(btrim(coalesce(p_address, '')), '');
  normalized_halaqah TEXT := nullif(btrim(coalesce(p_halaqah_name, '')), '');
  normalized_teacher TEXT := nullif(btrim(coalesce(p_teacher_name, '')), '');
  organization_owner UUID;
  created_center public.centers%ROWTYPE;
  created_halaqa public.halaqat%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF NOT public.current_user_can_manage_supervisor(p_supervisor_id) THEN
    RAISE EXCEPTION 'supervisor_manager_required';
  END IF;
  IF char_length(normalized_name) NOT BETWEEN 2 AND 160 THEN
    RAISE EXCEPTION 'invalid_center_name';
  END IF;
  IF p_type NOT IN ('men', 'women', 'mixed') THEN
    RAISE EXCEPTION 'invalid_center_type';
  END IF;
  IF normalized_address IS NOT NULL AND char_length(normalized_address) > 500 THEN
    RAISE EXCEPTION 'invalid_center_address';
  END IF;
  IF normalized_halaqah IS NOT NULL AND char_length(normalized_halaqah) > 160 THEN
    RAISE EXCEPTION 'invalid_halaqah_name';
  END IF;
  IF normalized_teacher IS NOT NULL AND char_length(normalized_teacher) > 160 THEN
    RAISE EXCEPTION 'invalid_teacher_name';
  END IF;

  SELECT owner_id INTO organization_owner
  FROM public.supervisors
  WHERE id = p_supervisor_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'supervisor_not_found';
  END IF;
  organization_owner := coalesce(organization_owner, auth.uid());

  INSERT INTO public.centers (
    name, address, type, supervisor_id, owner_id
  ) VALUES (
    normalized_name,
    normalized_address,
    p_type,
    p_supervisor_id,
    organization_owner
  ) RETURNING * INTO created_center;

  IF normalized_halaqah IS NOT NULL THEN
    INSERT INTO public.halaqat (center_id, name, teacher_name)
    VALUES (created_center.id, normalized_halaqah, normalized_teacher)
    RETURNING * INTO created_halaqa;
  END IF;

  INSERT INTO public.supervisor_audit_events (
    supervisor_id, center_id, actor_id, event_type, metadata
  ) VALUES (
    p_supervisor_id,
    created_center.id,
    auth.uid(),
    'center.created',
    jsonb_build_object(
      'center_name', created_center.name,
      'center_type', created_center.type,
      'halaqa_id', created_halaqa.id,
      'created_directly', true
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'center', jsonb_build_object(
      'id', created_center.id,
      'name', created_center.name,
      'type', created_center.type,
      'address', created_center.address,
      'supervisor_id', created_center.supervisor_id,
      'owner_id', created_center.owner_id
    ),
    'halaqa', CASE WHEN created_halaqa.id IS NULL THEN NULL ELSE jsonb_build_object(
      'id', created_halaqa.id,
      'name', created_halaqa.name,
      'teacher_name', created_halaqa.teacher_name
    ) END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_supervised_center(UUID, TEXT, TEXT, TEXT, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_supervised_center(UUID, TEXT, TEXT, TEXT, TEXT, TEXT)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 2) A backdated study suspension is a safe rollback of automatic day close.
--    Manual attendance and manual points are deliberately preserved.
-- ---------------------------------------------------------------------------
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
  removed_attendance INTEGER := 0;
  removed_points INTEGER := 0;
  removed_closings INTEGER := 0;
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
    hashtextextended(
      p_center_id::TEXT || ':' || p_halaqa_id::TEXT || ':' || p_date::TEXT,
      1414
    )
  );

  IF p_suspended THEN
    target_reason := btrim(coalesce(p_reason, ''));
    IF char_length(target_reason) NOT BETWEEN 3 AND 500 THEN
      RAISE EXCEPTION 'suspension_reason_required';
    END IF;

    -- Only rows that the atomic daily-closing RPC itself creates are removed.
    WITH removed AS (
      DELETE FROM public.attendance AS attendance_row
      WHERE attendance_row.center_id = p_center_id
        AND attendance_row.halaqa_id = p_halaqa_id
        AND attendance_row.date = p_date
        AND attendance_row.notes = 'أُنشئ تلقائيًا عند إغلاق اليوم'
      RETURNING 1
    ) SELECT count(*)::INTEGER INTO removed_attendance FROM removed;

    WITH removed AS (
      DELETE FROM public.points AS point_row
      WHERE point_row.center_id = p_center_id
        AND point_row.halaqa_id = p_halaqa_id
        AND point_row.date = p_date
        AND point_row.reason IN (
          'غياب بدون عذر (تلقائي)',
          'عدم التسميع (تلقائي)'
        )
      RETURNING 1
    ) SELECT count(*)::INTEGER INTO removed_points FROM removed;

    WITH removed AS (
      DELETE FROM public.daily_closings AS closing_row
      WHERE closing_row.center_id = p_center_id
        AND closing_row.halaqa_id = p_halaqa_id
        AND closing_row.closing_date = p_date
      RETURNING 1
    ) SELECT count(*)::INTEGER INTO removed_closings FROM removed;

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
    INSERT INTO public.audit_events (
      center_id, halaqa_id, actor_id, event_type, entity_type,
      entity_id, outcome, metadata
    ) VALUES (
      p_center_id,
      p_halaqa_id,
      auth.uid(),
      CASE WHEN p_suspended
        THEN 'study_suspension_set'
        ELSE 'study_suspension_removed'
      END,
      'study_suspension',
      target_id,
      'success',
      jsonb_build_object(
        'date', p_date,
        'reason', target_reason,
        'automatic_attendance_removed', removed_attendance,
        'automatic_points_removed', removed_points,
        'daily_closings_removed', removed_closings
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'id', target_id,
    'date', p_date,
    'suspended', p_suspended,
    'reason', target_reason,
    'automatic_attendance_removed', removed_attendance,
    'automatic_points_removed', removed_points,
    'daily_closings_removed', removed_closings
  );
END;
$$;

REVOKE ALL ON FUNCTION public.set_study_suspension(UUID, UUID, DATE, BOOLEAN, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_study_suspension(UUID, UUID, DATE, BOOLEAN, TEXT)
  TO authenticated;

-- ---------------------------------------------------------------------------
-- 3) Monthly plan exam is a first-class exam type (100 points: 30+30+20+20).
-- ---------------------------------------------------------------------------
ALTER TABLE public.exams
  DROP CONSTRAINT IF EXISTS exams_type_check;
ALTER TABLE public.exams
  ADD CONSTRAINT exams_type_check
  CHECK (type IN ('oral', 'written', 'monthly_plan')) NOT VALID;
ALTER TABLE public.exams
  VALIDATE CONSTRAINT exams_type_check;

-- ---------------------------------------------------------------------------
-- 4) Durable hard-delete ledger. A device reads deletions BEFORE it uploads,
--    so an offline copy cannot resurrect a row deleted by another device.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.sync_tombstones (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  center_id UUID,
  halaqa_id UUID,
  table_name TEXT NOT NULL,
  record_id TEXT,
  row_data JSONB NOT NULL DEFAULT '{}'::JSONB,
  deleted_by UUID,
  deleted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (char_length(table_name) BETWEEN 2 AND 80)
);

CREATE INDEX IF NOT EXISTS idx_sync_tombstones_scope_id
  ON public.sync_tombstones(center_id, halaqa_id, id);
CREATE INDEX IF NOT EXISTS idx_sync_tombstones_deleted_at
  ON public.sync_tombstones(deleted_at DESC);

ALTER TABLE public.sync_tombstones ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.sync_tombstones FROM PUBLIC, anon, authenticated;

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
  ELSIF scoped_record_id IS NULL AND TG_TABLE_NAME = 'attendance' THEN
    scoped_record_id := coalesce(payload ->> 'student_id', '') || '|' ||
      coalesce(payload ->> 'date', '');
  END IF;

  INSERT INTO public.sync_tombstones (
    center_id,
    halaqa_id,
    table_name,
    record_id,
    row_data,
    deleted_by
  ) VALUES (
    scoped_center,
    scoped_halaqa,
    TG_TABLE_NAME,
    scoped_record_id,
    payload,
    auth.uid()
  );
  RETURN OLD;
END;
$$;

REVOKE ALL ON FUNCTION public.capture_sync_tombstone()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  target_table TEXT;
  tracked_tables TEXT[] := ARRAY[
    'students',
    'families',
    'family_guardians',
    'attendance',
    'homework_grades',
    'memorization',
    'points',
    'daily_achievements',
    'vacations',
    'exams',
    'exam_scores',
    'exam_templates',
    'fund_transactions',
    'notifications',
    'student_holds',
    'talaqqin_records',
    'student_admin_actions',
    'plans',
    'quran_courses',
    'quran_course_enrollments',
    'plan_recitation_records'
  ];
BEGIN
  FOREACH target_table IN ARRAY tracked_tables LOOP
    IF to_regclass('public.' || target_table) IS NOT NULL THEN
      EXECUTE format(
        'DROP TRIGGER IF EXISTS capture_sync_tombstone_after_delete ON public.%I',
        target_table
      );
      EXECUTE format(
        'CREATE TRIGGER capture_sync_tombstone_after_delete '
        'AFTER DELETE ON public.%I FOR EACH ROW '
        'EXECUTE FUNCTION public.capture_sync_tombstone()',
        target_table
      );
    END IF;
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_sync_tombstones(
  p_center_id UUID,
  p_halaqa_id UUID,
  p_after_id BIGINT DEFAULT 0,
  p_limit INTEGER DEFAULT 500
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  safe_limit INTEGER := least(greatest(coalesce(p_limit, 500), 1), 1000);
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF p_center_id IS NULL OR p_halaqa_id IS NULL THEN
    RAISE EXCEPTION 'center_halaqa_required';
  END IF;
  IF NOT public.current_user_can_access_halaqa(p_center_id, p_halaqa_id) THEN
    RAISE EXCEPTION 'scope_not_accessible';
  END IF;

  RETURN coalesce((
    SELECT jsonb_agg(to_jsonb(tombstone) ORDER BY tombstone.id)
    FROM (
      SELECT
        item.id,
        item.table_name,
        item.record_id,
        item.row_data,
        item.deleted_at
      FROM public.sync_tombstones AS item
      WHERE item.id > greatest(coalesce(p_after_id, 0), 0)
        AND item.center_id = p_center_id
        AND (item.halaqa_id IS NULL OR item.halaqa_id = p_halaqa_id)
      ORDER BY item.id
      LIMIT safe_limit
    ) AS tombstone
  ), '[]'::JSONB);
END;
$$;

REVOKE ALL ON FUNCTION public.get_sync_tombstones(UUID, UUID, BIGINT, INTEGER)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_sync_tombstones(UUID, UUID, BIGINT, INTEGER)
  TO authenticated;

-- Build 75 health response makes the exact live contract visible to the UI.
CREATE OR REPLACE FUNCTION public.get_supervision_health()
RETURNS JSONB
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT jsonb_build_object(
    'contract_version', 'build75-2026-08-12',
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
      SELECT 1
      FROM public.supervisors AS supervisor
      WHERE public.current_user_can_manage_supervisor(supervisor.id)
    ),
    'direct_center_creation', to_regprocedure(
      'public.create_supervised_center(uuid,text,text,text,text,text)'
    ) IS NOT NULL,
    'sync_tombstones', to_regprocedure(
      'public.get_sync_tombstones(uuid,uuid,bigint,integer)'
    ) IS NOT NULL,
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
