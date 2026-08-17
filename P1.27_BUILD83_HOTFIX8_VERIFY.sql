-- Read-only verification for Halaqah P1.27 Build 83 Hotfix 8.
WITH expected(type) AS (
  VALUES
    ('low_performance'::text),
    ('repeated_absence'::text),
    ('plan_completed'::text),
    ('dismissal_warning'::text),
    ('general'::text),
    ('surah_completed'::text),
    ('consecutive_no_recitation'::text),
    ('student_expelled'::text)
),
constraint_definition AS (
  SELECT pg_get_constraintdef(c.oid) AS definition
  FROM pg_constraint c
  WHERE c.conrelid = 'public.notifications'::regclass
    AND c.contype = 'c'
    AND c.conname = 'notifications_type_check'
),
invalid_rows AS (
  SELECT count(*)::bigint AS count
  FROM public.notifications n
  WHERE n.type NOT IN (SELECT type FROM expected)
)
SELECT 'schema'::text AS area,
       'notifications_type_check'::text AS check_name,
       (
         EXISTS (SELECT 1 FROM constraint_definition)
         AND NOT EXISTS (
           SELECT 1
           FROM expected e
           WHERE NOT EXISTS (
             SELECT 1
             FROM constraint_definition d
             WHERE d.definition LIKE '%' || quote_literal(e.type) || '%'
           )
         )
       ) AS passed,
       COALESCE((SELECT definition FROM constraint_definition LIMIT 1), 'constraint missing') AS details
UNION ALL
SELECT 'data',
       'notifications_have_supported_types',
       (SELECT count = 0 FROM invalid_rows),
       'invalid row count: ' || (SELECT count::text FROM invalid_rows)
UNION ALL
SELECT 'table',
       'notifications_exists',
       to_regclass('public.notifications') IS NOT NULL,
       'required by Flutter notification sync'
ORDER BY area, check_name;
