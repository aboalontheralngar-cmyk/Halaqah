-- Build 74: make web family operations transactional.
-- Replaces multi-request unlink/delete/primary-guardian sequences that could
-- leave partial state when a later request failed.

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_family_atomic(p_family_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  unlinked_students INTEGER := 0;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id, target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  UPDATE public.students
  SET family_id = NULL, updated_at = now()
  WHERE family_id = target_family.id;
  GET DIAGNOSTICS unlinked_students = ROW_COUNT;

  -- The owner schema snapshot does not guarantee ON DELETE CASCADE on these
  -- historical foreign keys, so remove known dependents explicitly.
  IF to_regclass('public.family_portal_sessions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.family_portal_sessions WHERE family_id = $1'
      USING target_family.id;
  END IF;
  IF to_regclass('public.family_portal_credentials') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.family_portal_credentials WHERE family_id = $1'
      USING target_family.id;
  END IF;
  DELETE FROM public.family_guardians
  WHERE family_id = target_family.id;

  -- P1.21 tables use cascade in current migrations, but clean them explicitly
  -- when present so an older non-cascade constraint cannot block deletion.
  IF to_regclass('public.guardian_report_deliveries') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.guardian_report_deliveries WHERE family_id = $1'
      USING target_family.id;
  END IF;
  IF to_regclass('public.guardian_report_subscriptions') IS NOT NULL THEN
    EXECUTE 'DELETE FROM public.guardian_report_subscriptions WHERE family_id = $1'
      USING target_family.id;
  END IF;

  DELETE FROM public.families WHERE id = target_family.id;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type, entity_id, metadata
  ) VALUES (
    target_family.center_id,
    target_family.halaqa_id,
    auth.uid(),
    'family.deleted',
    'family',
    target_family.id,
    jsonb_build_object('students_unlinked', unlinked_students)
  );

  RETURN jsonb_build_object(
    'success', true,
    'students_unlinked', unlinked_students
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.set_family_students_atomic(
  p_family_id UUID,
  p_student_ids UUID[] DEFAULT ARRAY[]::UUID[]
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  normalized_ids UUID[] := coalesce(p_student_ids, ARRAY[]::UUID[]);
  primary_phone TEXT;
  linked_count INTEGER := 0;
  unlinked_count INTEGER := 0;
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id, target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.students AS student
    WHERE student.id = ANY(normalized_ids)
      AND (
        student.center_id IS DISTINCT FROM target_family.center_id
        OR student.halaqa_id IS DISTINCT FROM target_family.halaqa_id
      )
  ) THEN
    RAISE EXCEPTION 'student_outside_family_scope';
  END IF;

  UPDATE public.students
  SET family_id = NULL, updated_at = now()
  WHERE family_id = target_family.id
    AND NOT (id = ANY(normalized_ids));
  GET DIAGNOSTICS unlinked_count = ROW_COUNT;

  SELECT guardian.phone INTO primary_phone
  FROM public.family_guardians AS guardian
  WHERE guardian.family_id = target_family.id
    AND guardian.is_primary
  ORDER BY guardian.created_at, guardian.id
  LIMIT 1;

  UPDATE public.students
  SET family_id = target_family.id,
      parent_phone = coalesce(primary_phone, parent_phone),
      updated_at = now()
  WHERE id = ANY(normalized_ids)
    AND center_id = target_family.center_id
    AND halaqa_id = target_family.halaqa_id;
  GET DIAGNOSTICS linked_count = ROW_COUNT;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type, entity_id, metadata
  ) VALUES (
    target_family.center_id,
    target_family.halaqa_id,
    auth.uid(),
    'family.members.updated',
    'family',
    target_family.id,
    jsonb_build_object('linked_count', linked_count, 'unlinked_count', unlinked_count)
  );

  RETURN jsonb_build_object(
    'success', true,
    'linked_count', linked_count,
    'unlinked_count', unlinked_count
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.save_family_guardian_atomic(
  p_family_id UUID,
  p_guardian_id UUID DEFAULT NULL,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_relationship TEXT DEFAULT 'guardian',
  p_is_primary BOOLEAN DEFAULT FALSE,
  p_notes TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_family public.families%ROWTYPE;
  guardian_id UUID;
  effective_primary BOOLEAN := coalesce(p_is_primary, false);
BEGIN
  SELECT * INTO target_family
  FROM public.families
  WHERE id = p_family_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_family.center_id, target_family.halaqa_id
  ) THEN
    RAISE EXCEPTION 'family_not_accessible';
  END IF;

  IF nullif(btrim(coalesce(p_name, '')), '') IS NULL
     OR nullif(btrim(coalesce(p_phone, '')), '') IS NULL THEN
    RAISE EXCEPTION 'guardian_name_phone_required';
  END IF;

  IF p_relationship NOT IN (
    'father', 'mother', 'brother', 'grandfather', 'uncle', 'guardian', 'other'
  ) THEN
    RAISE EXCEPTION 'invalid_guardian_relationship';
  END IF;

  IF p_guardian_id IS NOT NULL AND NOT EXISTS (
    SELECT 1 FROM public.family_guardians
    WHERE id = p_guardian_id AND family_id = target_family.id
  ) THEN
    RAISE EXCEPTION 'guardian_not_found';
  END IF;

  -- Every non-empty family must have a primary guardian. The caller may also
  -- explicitly choose a new primary guardian.
  IF NOT effective_primary AND NOT EXISTS (
    SELECT 1 FROM public.family_guardians
    WHERE family_id = target_family.id
      AND is_primary
      AND (p_guardian_id IS NULL OR id <> p_guardian_id)
  ) THEN
    effective_primary := TRUE;
  END IF;

  IF effective_primary THEN
    UPDATE public.family_guardians
    SET is_primary = FALSE, updated_at = now()
    WHERE family_id = target_family.id
      AND (p_guardian_id IS NULL OR id <> p_guardian_id)
      AND is_primary;
  END IF;

  IF p_guardian_id IS NULL THEN
    INSERT INTO public.family_guardians (
      family_id, center_id, halaqa_id, name, phone, email, relationship,
      is_primary, notes
    ) VALUES (
      target_family.id,
      target_family.center_id,
      target_family.halaqa_id,
      btrim(p_name),
      btrim(p_phone),
      nullif(btrim(coalesce(p_email, '')), ''),
      p_relationship,
      effective_primary,
      nullif(btrim(coalesce(p_notes, '')), '')
    ) RETURNING id INTO guardian_id;
  ELSE
    UPDATE public.family_guardians
    SET name = btrim(p_name),
        phone = btrim(p_phone),
        email = nullif(btrim(coalesce(p_email, '')), ''),
        relationship = p_relationship,
        is_primary = effective_primary,
        notes = nullif(btrim(coalesce(p_notes, '')), ''),
        updated_at = now()
    WHERE id = p_guardian_id
      AND family_id = target_family.id
    RETURNING id INTO guardian_id;
  END IF;

  IF effective_primary THEN
    UPDATE public.students
    SET parent_phone = btrim(p_phone), updated_at = now()
    WHERE family_id = target_family.id;
  END IF;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type, entity_id, metadata
  ) VALUES (
    target_family.center_id,
    target_family.halaqa_id,
    auth.uid(),
    CASE WHEN p_guardian_id IS NULL THEN 'guardian.created' ELSE 'guardian.updated' END,
    'family_guardian',
    guardian_id,
    jsonb_build_object('primary', effective_primary)
  );

  RETURN jsonb_build_object(
    'success', true,
    'guardian_id', guardian_id,
    'is_primary', effective_primary
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_family_guardian_atomic(p_guardian_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  target_guardian public.family_guardians%ROWTYPE;
  next_guardian_id UUID;
BEGIN
  SELECT * INTO target_guardian
  FROM public.family_guardians
  WHERE id = p_guardian_id
  FOR UPDATE;

  IF NOT FOUND OR NOT public.current_user_can_access_halaqa(
    target_guardian.center_id, target_guardian.halaqa_id
  ) THEN
    RAISE EXCEPTION 'guardian_not_accessible';
  END IF;

  DELETE FROM public.family_guardians WHERE id = target_guardian.id;

  IF target_guardian.is_primary THEN
    SELECT guardian.id INTO next_guardian_id
    FROM public.family_guardians AS guardian
    WHERE guardian.family_id = target_guardian.family_id
    ORDER BY guardian.created_at, guardian.id
    LIMIT 1
    FOR UPDATE;

    IF next_guardian_id IS NOT NULL THEN
      UPDATE public.family_guardians
      SET is_primary = TRUE, updated_at = now()
      WHERE id = next_guardian_id;

      UPDATE public.students AS student
      SET parent_phone = guardian.phone, updated_at = now()
      FROM public.family_guardians AS guardian
      WHERE guardian.id = next_guardian_id
        AND student.family_id = target_guardian.family_id;
    ELSE
      UPDATE public.students
      SET parent_phone = NULL, updated_at = now()
      WHERE family_id = target_guardian.family_id;
    END IF;
  END IF;

  INSERT INTO public.audit_events (
    center_id, halaqa_id, actor_id, event_type, entity_type, entity_id, metadata
  ) VALUES (
    target_guardian.center_id,
    target_guardian.halaqa_id,
    auth.uid(),
    'guardian.deleted',
    'family_guardian',
    target_guardian.id,
    jsonb_build_object('primary_replacement_created', next_guardian_id IS NOT NULL)
  );

  RETURN jsonb_build_object(
    'success', true,
    'next_primary_guardian_id', next_guardian_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.delete_family_atomic(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.set_family_students_atomic(UUID, UUID[]) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.save_family_guardian_atomic(UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.delete_family_guardian_atomic(UUID) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_family_atomic(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_family_students_atomic(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.save_family_guardian_atomic(UUID, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_family_guardian_atomic(UUID) TO authenticated;

COMMIT;
