WITH checks AS (
  SELECT
    'schema'::text AS area,
    'profiles_onboarding_completed_column'::text AS check_name,
    EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'profiles'
        AND column_name = 'onboarding_completed'
        AND is_nullable = 'NO'
        AND column_default ILIKE '%false%'
    ) AS passed,
    'new auth profiles default to incomplete onboarding'::text AS details

  UNION ALL

  SELECT
    'data',
    'established_accounts_marked_complete',
    NOT EXISTS (
      SELECT 1
      FROM public.profiles AS p
      WHERE p.onboarding_completed = false
        AND (
          EXISTS (SELECT 1 FROM public.centers AS c WHERE c.owner_id = p.id)
          OR EXISTS (SELECT 1 FROM public.center_members AS cm WHERE cm.user_id = p.id)
          OR EXISTS (SELECT 1 FROM public.supervisors AS s WHERE s.owner_id = p.id)
          OR EXISTS (
            SELECT 1
            FROM public.supervisor_members AS sm
            WHERE sm.user_id = p.id
              AND sm.status = 'active'
          )
          OR EXISTS (
            SELECT 1
            FROM auth.users AS au
            JOIN public.center_members AS cm
              ON lower(cm.email) = lower(au.email)
            WHERE au.id = p.id
              AND au.email IS NOT NULL
          )
        )
    ),
    'existing center/supervision/member accounts are not forced through onboarding again'

  UNION ALL

  SELECT
    'data',
    'completed_profiles_have_display_name',
    NOT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE onboarding_completed = true
        AND NULLIF(btrim(full_name), '') IS NULL
    ),
    'completed accounts have a name for the profile greeting'
)
SELECT area, check_name, passed, details
FROM checks
ORDER BY area, check_name;
