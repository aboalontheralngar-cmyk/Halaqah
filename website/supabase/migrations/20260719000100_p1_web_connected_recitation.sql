-- P1.7: atomic multi-surah recitation sessions for the Web application.
-- In Supabase SQL Editor, paste this file's CONTENTS only (not its filename).
-- Prerequisite: 20260713000100_p5_web_recitation_parity.sql

BEGIN;

CREATE OR REPLACE FUNCTION public.save_recitation_session(
  p_student_id UUID,
  p_segments JSONB,
  p_date DATE,
  p_grade_mark TEXT,
  p_mistakes_count INTEGER,
  p_is_revision BOOLEAN,
  p_remark TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  segment JSONB;
  segment_id UUID;
  saved_ids UUID[] := ARRAY[]::UUID[];
  segment_count INTEGER;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;
  IF jsonb_typeof(p_segments) IS DISTINCT FROM 'array' THEN
    RAISE EXCEPTION 'segments_must_be_an_array';
  END IF;

  segment_count := jsonb_array_length(p_segments);
  IF segment_count < 1 OR segment_count > 114 THEN
    RAISE EXCEPTION 'invalid_segment_count';
  END IF;

  FOR segment IN SELECT value FROM jsonb_array_elements(p_segments)
  LOOP
    IF jsonb_typeof(segment) IS DISTINCT FROM 'object'
       OR NULLIF(BTRIM(segment->>'id'), '') IS NULL
       OR NULLIF(BTRIM(segment->>'surah'), '') IS NULL
       OR COALESCE((segment->>'from_ayah')::INTEGER, 0) < 1
       OR COALESCE((segment->>'to_ayah')::INTEGER, 0)
          < COALESCE((segment->>'from_ayah')::INTEGER, 0) THEN
      RAISE EXCEPTION 'invalid_recitation_segment';
    END IF;

    BEGIN
      segment_id := (segment->>'id')::UUID;
    EXCEPTION WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'invalid_segment_id';
    END;

    IF segment_id = ANY(saved_ids) THEN
      RAISE EXCEPTION 'duplicate_segment_id';
    END IF;

    PERFORM public.save_recitation_record(
      segment_id,
      p_student_id,
      BTRIM(segment->>'surah'),
      (segment->>'from_ayah')::INTEGER,
      (segment->>'to_ayah')::INTEGER,
      p_date,
      p_grade_mark,
      CASE WHEN cardinality(saved_ids) = 0 THEN p_mistakes_count ELSE 0 END,
      p_is_revision,
      CASE WHEN cardinality(saved_ids) = 0 THEN p_remark ELSE NULL END
    );
    saved_ids := array_append(saved_ids, segment_id);
  END LOOP;

  RETURN jsonb_build_object(
    'saved_count', cardinality(saved_ids),
    'record_ids', to_jsonb(saved_ids)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.save_recitation_session(
  UUID, JSONB, DATE, TEXT, INTEGER, BOOLEAN, TEXT
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.save_recitation_session(
  UUID, JSONB, DATE, TEXT, INTEGER, BOOLEAN, TEXT
) TO authenticated;

COMMIT;
