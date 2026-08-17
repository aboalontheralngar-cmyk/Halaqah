-- Halaqah P1.27 Build 83 Hotfix 8
-- Expands the cloud notification type contract used by the Flutter app.
-- Safe to run after Build 78 Hotfix 3 / Build 82 verification.

BEGIN;

DO $$
DECLARE
  constraint_row record;
BEGIN
  IF to_regclass('public.notifications') IS NULL THEN
    RAISE EXCEPTION 'public.notifications is missing';
  END IF;

  -- Remove only CHECK constraints that reference notifications.type. This is
  -- robust against databases where PostgreSQL generated a different name.
  FOR constraint_row IN
    SELECT c.conname
    FROM pg_constraint c
    WHERE c.conrelid = 'public.notifications'::regclass
      AND c.contype = 'c'
      AND EXISTS (
        SELECT 1
        FROM unnest(c.conkey) AS key(attnum)
        JOIN pg_attribute a
          ON a.attrelid = c.conrelid
         AND a.attnum = key.attnum
        WHERE a.attname = 'type'
      )
  LOOP
    EXECUTE format(
      'ALTER TABLE public.notifications DROP CONSTRAINT %I',
      constraint_row.conname
    );
  END LOOP;
END
$$;

ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check
  CHECK (
    type = ANY (
      ARRAY[
        'low_performance'::text,
        'repeated_absence'::text,
        'plan_completed'::text,
        'dismissal_warning'::text,
        'general'::text,
        'surah_completed'::text,
        'consecutive_no_recitation'::text,
        'student_expelled'::text
      ]
    )
  ) NOT VALID;

ALTER TABLE public.notifications
  VALIDATE CONSTRAINT notifications_type_check;

COMMENT ON CONSTRAINT notifications_type_check ON public.notifications IS
  'Build 83 notification categories shared by Flutter and cloud sync.';

COMMIT;
