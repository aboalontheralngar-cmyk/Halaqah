BEGIN;

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS onboarding_completed boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.profiles.onboarding_completed IS
  'True only after the account finished role and organization/center onboarding.';

UPDATE public.profiles AS p
SET onboarding_completed = true
WHERE p.onboarding_completed = false
  AND (
    EXISTS (
      SELECT 1
      FROM public.centers AS c
      WHERE c.owner_id = p.id
    )
    OR EXISTS (
      SELECT 1
      FROM public.center_members AS cm
      WHERE cm.user_id = p.id
    )
    OR EXISTS (
      SELECT 1
      FROM public.supervisors AS s
      WHERE s.owner_id = p.id
    )
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
  );

UPDATE public.profiles AS p
SET full_name = COALESCE(
  NULLIF(btrim(p.full_name), ''),
  NULLIF(btrim(au.raw_user_meta_data ->> 'full_name'), ''),
  NULLIF(btrim(au.raw_user_meta_data ->> 'name'), ''),
  NULLIF(split_part(au.email, '@', 1), '')
)
FROM auth.users AS au
WHERE au.id = p.id
  AND p.onboarding_completed = true
  AND NULLIF(btrim(p.full_name), '') IS NULL;

NOTIFY pgrst, 'reload schema';

COMMIT;
