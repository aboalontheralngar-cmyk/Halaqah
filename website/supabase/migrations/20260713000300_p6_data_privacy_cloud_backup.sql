-- P6.2: immutable audit trail and private storage for encrypted backups.
-- Copy the CONTENTS of this file into Supabase SQL Editor, not the filename.
-- Safe to run repeatedly. It does not delete application data.

BEGIN;

-- Self-contained compatibility helpers. These exact signatures are included
-- so this migration does not depend on an earlier file being applied first.
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

CREATE OR REPLACE FUNCTION public.safe_uuid(p_value TEXT)
RETURNS UUID
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
BEGIN
  IF p_value IS NULL OR BTRIM(p_value) = '' THEN
    RETURN NULL;
  END IF;
  RETURN p_value::UUID;
EXCEPTION WHEN invalid_text_representation THEN
  RETURN NULL;
END;
$$;

REVOKE ALL ON FUNCTION public.current_user_is_center_admin(UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.safe_uuid(TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_user_is_center_admin(UUID)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_can_access_halaqa(UUID, UUID)
  TO authenticated;

CREATE TABLE IF NOT EXISTS public.audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  center_id UUID REFERENCES public.centers(id) ON DELETE SET NULL,
  halaqa_id UUID REFERENCES public.halaqat(id) ON DELETE SET NULL,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL CHECK (char_length(event_type) BETWEEN 3 AND 120),
  entity_type TEXT NOT NULL CHECK (char_length(entity_type) BETWEEN 2 AND 80),
  entity_id UUID,
  outcome TEXT NOT NULL DEFAULT 'success'
    CHECK (outcome IN ('success', 'failure', 'denied')),
  metadata JSONB NOT NULL DEFAULT '{}'::JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_audit_events_scope_created
  ON public.audit_events(center_id, halaqa_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_entity
  ON public.audit_events(entity_type, entity_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_events_actor
  ON public.audit_events(actor_id, created_at DESC);

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_events_select_scoped ON public.audit_events;
DROP POLICY IF EXISTS audit_events_insert_scoped ON public.audit_events;

CREATE POLICY audit_events_select_scoped
  ON public.audit_events FOR SELECT TO authenticated
  USING (
    actor_id = auth.uid()
    OR (
      center_id IS NOT NULL
      AND public.current_user_can_access_halaqa(center_id, halaqa_id)
    )
  );

CREATE POLICY audit_events_insert_scoped
  ON public.audit_events FOR INSERT TO authenticated
  WITH CHECK (
    actor_id = auth.uid()
    AND (
      center_id IS NULL
      OR public.current_user_can_access_halaqa(center_id, halaqa_id)
    )
  );

-- Audits an explicit application action without accepting actor identity from
-- the client. Metadata must never contain passwords, tokens, phone numbers, or
-- full backup contents.
CREATE OR REPLACE FUNCTION public.write_audit_event(
  p_event_type TEXT,
  p_entity_type TEXT,
  p_entity_id UUID,
  p_center_id UUID,
  p_halaqa_id UUID,
  p_outcome TEXT,
  p_metadata JSONB
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  new_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'authentication_required';
  END IF;
  IF char_length(BTRIM(COALESCE(p_event_type, ''))) NOT BETWEEN 3 AND 120
     OR char_length(BTRIM(COALESCE(p_entity_type, ''))) NOT BETWEEN 2 AND 80 THEN
    RAISE EXCEPTION 'invalid_audit_event';
  END IF;
  IF p_outcome NOT IN ('success', 'failure', 'denied') THEN
    RAISE EXCEPTION 'invalid_audit_outcome';
  END IF;
  IF p_center_id IS NOT NULL
     AND NOT public.current_user_can_access_halaqa(p_center_id, p_halaqa_id) THEN
    RAISE EXCEPTION 'scope_not_accessible';
  END IF;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type,
    entity_id, outcome, metadata, created_at
  ) VALUES (
    p_center_id, p_halaqa_id, auth.uid(), BTRIM(p_event_type),
    BTRIM(p_entity_type), p_entity_id, p_outcome,
    COALESCE(p_metadata, '{}'::JSONB), now()
  )
  RETURNING id INTO new_id;
  RETURN new_id;
END;
$$;

REVOKE ALL ON FUNCTION public.write_audit_event(
  TEXT, TEXT, UUID, UUID, UUID, TEXT, JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.write_audit_event(
  TEXT, TEXT, UUID, UUID, UUID, TEXT, JSONB
) TO authenticated;

-- Generic trigger: records identifiers and changed field names only. It does
-- not copy names, phone numbers, notes, or row contents into the audit table.
CREATE OR REPLACE FUNCTION public.audit_sensitive_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  row_data JSONB;
  previous_data JSONB;
  event_center UUID;
  event_halaqa UUID;
  event_student UUID;
  event_entity UUID;
  changed_fields JSONB := '[]'::JSONB;
BEGIN
  row_data := CASE WHEN TG_OP = 'DELETE' THEN to_jsonb(OLD) ELSE to_jsonb(NEW) END;
  previous_data := CASE WHEN TG_OP = 'UPDATE' THEN to_jsonb(OLD) ELSE '{}'::JSONB END;
  event_center := public.safe_uuid(row_data ->> 'center_id');
  event_halaqa := public.safe_uuid(row_data ->> 'halaqa_id');
  event_student := public.safe_uuid(row_data ->> 'student_id');
  event_entity := public.safe_uuid(row_data ->> 'id');

  IF event_center IS NULL AND event_student IS NOT NULL THEN
    SELECT student.center_id, student.halaqa_id
      INTO event_center, event_halaqa
    FROM public.students student
    WHERE student.id = event_student;
  END IF;

  IF TG_OP = 'UPDATE' THEN
    SELECT COALESCE(jsonb_agg(field_name ORDER BY field_name), '[]'::JSONB)
      INTO changed_fields
    FROM (
      SELECT current_field.key AS field_name
      FROM jsonb_each(row_data) current_field
      WHERE current_field.value IS DISTINCT FROM previous_data -> current_field.key
        AND current_field.key NOT IN ('updated_at')
    ) changed;
  END IF;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type,
    entity_id, outcome, metadata, created_at
  ) VALUES (
    event_center, event_halaqa, auth.uid(),
    lower(TG_TABLE_NAME || '.' || TG_OP), TG_TABLE_NAME,
    event_entity, 'success',
    jsonb_build_object(
      'operation', TG_OP,
      'changed_fields', changed_fields
    ),
    now()
  );

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Auditing must never corrupt or block the original student operation.
  RAISE WARNING 'audit_sensitive_mutation skipped for %.%: %',
    TG_TABLE_NAME, TG_OP, SQLSTATE;
  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.audit_sensitive_mutation()
  FROM PUBLIC, anon, authenticated;

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOREACH table_name IN ARRAY ARRAY[
    'students',
    'attendance',
    'memorization',
    'mushaf_progress',
    'homework_grades',
    'points',
    'vacations',
    'plans',
    'exams',
    'exam_scores',
    'fund_transactions'
  ]
  LOOP
    IF to_regclass('public.' || table_name) IS NOT NULL THEN
      EXECUTE format(
        'DROP TRIGGER IF EXISTS audit_sensitive_mutation ON public.%I',
        table_name
      );
      EXECUTE format(
        'CREATE TRIGGER audit_sensitive_mutation '
        'AFTER INSERT OR UPDATE OR DELETE ON public.%I '
        'FOR EACH ROW EXECUTE FUNCTION public.audit_sensitive_mutation()',
        table_name
      );
    END IF;
  END LOOP;
END;
$$;

-- Only a center administrator may remove audit entries after the configured
-- retention period. Ordinary clients have no UPDATE or DELETE policy.
CREATE OR REPLACE FUNCTION public.prune_center_audit_events(
  p_center_id UUID,
  p_before TIMESTAMPTZ
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  IF NOT public.current_user_is_center_admin(p_center_id) THEN
    RAISE EXCEPTION 'center_admin_required';
  END IF;
  IF p_before > now() - INTERVAL '30 days' THEN
    RAISE EXCEPTION 'minimum_audit_retention_is_30_days';
  END IF;
  DELETE FROM public.audit_events
  WHERE center_id = p_center_id AND created_at < p_before;
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$;

REVOKE ALL ON FUNCTION public.prune_center_audit_events(UUID, TIMESTAMPTZ)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.prune_center_audit_events(UUID, TIMESTAMPTZ)
  TO authenticated;

-- Private Supabase Storage bucket. Every object path starts with auth.uid(),
-- which prevents one account from listing, reading, or deleting another
-- account's encrypted files.
INSERT INTO storage.buckets (
  id, name, public, file_size_limit, allowed_mime_types
) VALUES (
  'halaqah-backups',
  'halaqah-backups',
  false,
  104857600,
  ARRAY['application/octet-stream']::TEXT[]
)
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS halaqah_backups_select_own ON storage.objects;
DROP POLICY IF EXISTS halaqah_backups_insert_own ON storage.objects;
DROP POLICY IF EXISTS halaqah_backups_update_own ON storage.objects;
DROP POLICY IF EXISTS halaqah_backups_delete_own ON storage.objects;

CREATE POLICY halaqah_backups_select_own
  ON storage.objects FOR SELECT TO authenticated
  USING (
    bucket_id = 'halaqah-backups'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY halaqah_backups_insert_own
  ON storage.objects FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'halaqah-backups'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY halaqah_backups_update_own
  ON storage.objects FOR UPDATE TO authenticated
  USING (
    bucket_id = 'halaqah-backups'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  )
  WITH CHECK (
    bucket_id = 'halaqah-backups'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

CREATE POLICY halaqah_backups_delete_own
  ON storage.objects FOR DELETE TO authenticated
  USING (
    bucket_id = 'halaqah-backups'
    AND (storage.foldername(name))[1] = auth.uid()::TEXT
  );

COMMIT;

-- Verification queries (run separately after COMMIT if desired):
-- SELECT id, public, file_size_limit FROM storage.buckets
-- WHERE id = 'halaqah-backups';
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_schema = 'public'
--   AND routine_name IN ('write_audit_event', 'prune_center_audit_events');
