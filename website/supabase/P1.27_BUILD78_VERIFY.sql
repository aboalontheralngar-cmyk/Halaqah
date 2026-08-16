WITH checks AS (
  SELECT 'schema'::text AS check_group,
         'friday_plan_policy'::text AS check_name,
         EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema='public' AND table_name='plans' AND column_name='friday_mode'
         ) AS passed,
         'plans.friday_mode supports catch-up, full-plan, or holiday Friday'::text AS details
  UNION ALL
  SELECT 'points','decimal_points_enabled',
         EXISTS (
           SELECT 1 FROM information_schema.columns
           WHERE table_schema='public' AND table_name='points' AND column_name='amount'
             AND data_type='numeric'
         ),
         'behavior/recitation points preserve values such as 2.5'
  UNION ALL
  SELECT 'supervision','supervisor_competition_tables',
         to_regclass('public.supervisor_competitions') IS NOT NULL
         AND to_regclass('public.supervisor_competition_categories') IS NOT NULL
         AND to_regclass('public.supervisor_competition_entries') IS NOT NULL
         AND to_regclass('public.supervisor_competition_scores') IS NOT NULL,
         'annual supervisory competition, categories, nominations, and scores'
  UNION ALL
  SELECT 'supervision','supervisor_competition_rls',
         coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.supervisor_competitions'::regclass),false)
         AND coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.supervisor_competition_entries'::regclass),false)
         AND coalesce((SELECT relrowsecurity FROM pg_class WHERE oid='public.supervisor_competition_scores'::regclass),false),
         'competition data uses row-level security'
  UNION ALL
  SELECT 'rpc','competition_submission_rpc',
         to_regprocedure('public.submit_supervisor_competition_entry(uuid,uuid,uuid)') IS NOT NULL,
         'linked centers can submit their own students through guarded RPC'
  UNION ALL
  SELECT 'rpc','competition_scoring_rpc',
         to_regprocedure('public.score_supervisor_competition_entry(uuid,numeric,integer,integer,integer,integer,integer,text)') IS NOT NULL,
         'supervisory owner/admin can score entries through guarded RPC'
  UNION ALL
  SELECT 'security','competition_functions_search_path',
         NOT EXISTS (
           SELECT 1
           FROM pg_proc p
           JOIN pg_namespace n ON n.oid=p.pronamespace
           WHERE n.nspname='public'
             AND p.proname IN ('submit_supervisor_competition_entry','withdraw_supervisor_competition_entry','score_supervisor_competition_entry')
             AND NOT EXISTS (
               SELECT 1 FROM unnest(coalesce(p.proconfig, ARRAY[]::text[])) cfg
               WHERE cfg LIKE 'search_path=%pg_temp%'
             )
         ),
         'Build 78 SECURITY DEFINER RPCs pin search_path with pg_temp'
)
SELECT * FROM checks ORDER BY check_group, check_name;
