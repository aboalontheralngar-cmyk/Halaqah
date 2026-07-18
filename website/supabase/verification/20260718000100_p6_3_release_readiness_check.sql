-- P6.3 release-readiness check, revision 2.
-- Read-only: this file does not change schema, privileges, policies, or data.
-- Sensitive portal tables intentionally have zero policies: RLS + REVOKE ALL
-- keeps direct client access closed while SECURITY DEFINER RPCs mediate access.

WITH
expected_relations(object_name) AS (
  VALUES
    ('public.students'),
    ('public.families'),
    ('public.family_guardians'),
    ('public.audit_events'),
    ('public.student_portal_credentials'),
    ('public.student_portal_sessions'),
    ('public.student_portal_login_attempts'),
    ('public.family_portal_credentials'),
    ('public.family_portal_sessions'),
    ('public.family_portal_login_attempts'),
    ('public.supervisor_members'),
    ('public.supervisor_audit_events')
),
expected_functions(signature) AS (
  VALUES
    ('public.current_user_can_access_halaqa(uuid,uuid)'),
    ('public.set_student_portal_pin(uuid,text,boolean)'),
    ('public.student_portal_authenticate(text,text,text)'),
    ('public.student_portal_get_dashboard(text,integer)'),
    ('public.get_family_portal_status(uuid)'),
    ('public.family_portal_authenticate(text,text,text)'),
    ('public.family_portal_get_dashboard(text,integer,uuid)'),
    ('public.create_supervisor_organization(text)'),
    ('public.get_supervisor_dashboard(uuid,date,date)')
),
protected_tables(table_name) AS (
  VALUES
    ('students'),
    ('families'),
    ('family_guardians'),
    ('audit_events'),
    ('student_portal_credentials'),
    ('student_portal_sessions'),
    ('student_portal_login_attempts'),
    ('family_portal_credentials'),
    ('family_portal_sessions'),
    ('family_portal_login_attempts'),
    ('supervisor_members'),
    ('supervisor_audit_events')
),
policy_tables(table_name) AS (
  VALUES
    ('students'),
    ('families'),
    ('family_guardians'),
    ('audit_events'),
    ('supervisor_members'),
    ('supervisor_audit_events')
),
sensitive_tables(table_name) AS (
  VALUES
    ('student_portal_credentials'),
    ('student_portal_sessions'),
    ('student_portal_login_attempts'),
    ('family_portal_credentials'),
    ('family_portal_sessions'),
    ('family_portal_login_attempts')
),
extension_checks AS (
  SELECT
    'extension'::text AS check_group,
    'pgcrypto'::text AS check_name,
    EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgcrypto') AS passed,
    COALESCE(
      (
        SELECT extnamespace::regnamespace::text
        FROM pg_extension
        WHERE extname = 'pgcrypto'
      ),
      'missing'
    ) AS details
),
relation_checks AS (
  SELECT
    'relation'::text AS check_group,
    object_name::text AS check_name,
    to_regclass(object_name) IS NOT NULL AS passed,
    COALESCE(to_regclass(object_name)::text, 'missing') AS details
  FROM expected_relations
),
function_checks AS (
  SELECT
    'function'::text AS check_group,
    signature::text AS check_name,
    to_regprocedure(signature) IS NOT NULL AS passed,
    COALESCE(to_regprocedure(signature)::text, 'missing') AS details
  FROM expected_functions
),
rls_checks AS (
  SELECT
    'rls'::text AS check_group,
    format('public.%s', protected_tables.table_name) AS check_name,
    COALESCE(pg_class.relrowsecurity, false) AS passed,
    CASE
      WHEN pg_class.oid IS NULL THEN 'missing'
      WHEN pg_class.relrowsecurity THEN 'enabled'
      ELSE 'disabled'
    END AS details
  FROM protected_tables
  LEFT JOIN pg_namespace
    ON pg_namespace.nspname = 'public'
  LEFT JOIN pg_class
    ON pg_class.relnamespace = pg_namespace.oid
   AND pg_class.relname = protected_tables.table_name
),
policy_checks AS (
  SELECT
    'policy'::text AS check_group,
    format('public.%s', policy_tables.table_name) AS check_name,
    COUNT(pg_policies.policyname) > 0 AS passed,
    format('%s policies', COUNT(pg_policies.policyname)) AS details
  FROM policy_tables
  LEFT JOIN pg_policies
    ON pg_policies.schemaname = 'public'
   AND pg_policies.tablename = policy_tables.table_name
  GROUP BY policy_tables.table_name
),
sensitive_state AS (
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
sensitive_access AS (
  SELECT
    sensitive_state.*,
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
  FROM sensitive_state
),
sensitive_checks AS (
  SELECT
    'deny-all'::text AS check_group,
    format('public.%s', table_name) AS check_name,
    table_oid IS NOT NULL
      AND rls_enabled
      AND policy_count = 0
      AND NOT anon_direct
      AND NOT authenticated_direct AS passed,
    format(
      'rls=%s policies=%s anon_direct=%s authenticated_direct=%s',
      rls_enabled,
      policy_count,
      anon_direct,
      authenticated_direct
    ) AS details
  FROM sensitive_access
)
SELECT * FROM extension_checks
UNION ALL SELECT * FROM relation_checks
UNION ALL SELECT * FROM function_checks
UNION ALL SELECT * FROM rls_checks
UNION ALL SELECT * FROM policy_checks
UNION ALL SELECT * FROM sensitive_checks
ORDER BY check_group, check_name;
