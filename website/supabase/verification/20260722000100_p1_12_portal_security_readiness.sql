-- P1.12 portal security readiness.
-- READ ONLY: this query does not create, alter, grant, revoke, or change data.
--
-- Expected secure state for credential/session/attempt tables:
--   RLS = true, policies = 0, anon_direct = false, authenticated_direct = false.
-- Zero policies is intentionally secure here because access is only through
-- narrowly granted SECURITY DEFINER functions.

WITH sensitive_tables(table_name) AS (
  VALUES
    ('student_portal_credentials'),
    ('student_portal_sessions'),
    ('student_portal_login_attempts'),
    ('family_portal_credentials'),
    ('family_portal_sessions'),
    ('family_portal_login_attempts')
),
table_state AS (
  SELECT
    sensitive_tables.table_name,
    pg_class.oid AS table_oid,
    COALESCE(pg_class.relrowsecurity, false) AS rls_enabled,
    COUNT(pg_policies.policyname) AS policy_count
  FROM sensitive_tables
  LEFT JOIN pg_namespace
    ON pg_namespace.nspname = 'public'
  LEFT JOIN pg_class
    ON pg_class.relnamespace = pg_namespace.oid
   AND pg_class.relname = sensitive_tables.table_name
  LEFT JOIN pg_policies
    ON pg_policies.schemaname = 'public'
   AND pg_policies.tablename = sensitive_tables.table_name
  GROUP BY sensitive_tables.table_name, pg_class.oid, pg_class.relrowsecurity
),
direct_access AS (
  SELECT
    table_state.*,
    COALESCE(
      has_table_privilege('anon', table_oid, 'SELECT') OR
      has_table_privilege('anon', table_oid, 'INSERT') OR
      has_table_privilege('anon', table_oid, 'UPDATE') OR
      has_table_privilege('anon', table_oid, 'DELETE') OR
      has_table_privilege('anon', table_oid, 'TRUNCATE') OR
      has_table_privilege('anon', table_oid, 'REFERENCES') OR
      has_table_privilege('anon', table_oid, 'TRIGGER'),
      false
    ) AS anon_direct,
    COALESCE(
      has_table_privilege('authenticated', table_oid, 'SELECT') OR
      has_table_privilege('authenticated', table_oid, 'INSERT') OR
      has_table_privilege('authenticated', table_oid, 'UPDATE') OR
      has_table_privilege('authenticated', table_oid, 'DELETE') OR
      has_table_privilege('authenticated', table_oid, 'TRUNCATE') OR
      has_table_privilege('authenticated', table_oid, 'REFERENCES') OR
      has_table_privilege('authenticated', table_oid, 'TRIGGER'),
      false
    ) AS authenticated_direct
  FROM table_state
),
security_checks AS (
  SELECT
    'portal-deny-all'::text AS check_group,
    format('public.%s', table_name) AS check_name,
    table_oid IS NOT NULL
      AND rls_enabled
      AND policy_count = 0
      AND NOT anon_direct
      AND NOT authenticated_direct AS passed,
    format(
      'expected: rls=true policies=0 anon_direct=false authenticated_direct=false | actual: rls=%s policies=%s anon_direct=%s authenticated_direct=%s',
      rls_enabled,
      policy_count,
      anon_direct,
      authenticated_direct
    ) AS details
  FROM direct_access
)
SELECT check_group, check_name, passed, details
FROM security_checks
UNION ALL
SELECT
  'portal-summary'::text,
  'all_sensitive_portal_tables'::text,
  COALESCE(bool_and(passed), false),
  format(
    '%s/%s secured; false means inspect the actual state, not add a public policy',
    COUNT(*) FILTER (WHERE passed),
    COUNT(*)
  )
FROM security_checks
ORDER BY check_group, check_name;
