-- Halaqah P1.27 Build 84 / Hotfix 9 verification (read-only)
WITH checks(area, check_name, passed, details) AS (
  VALUES
    ('sync', 'attendance_updated_at',
      EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='attendance' AND column_name='updated_at'),
      'incremental attendance pull cursor'),
    ('sync', 'mushaf_updated_at',
      EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='mushaf_progress' AND column_name='updated_at'),
      'incremental mushaf pull cursor'),
    ('sync', 'notifications_updated_at',
      EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='notifications' AND column_name='updated_at'),
      'incremental notifications pull cursor'),
    ('sync', 'legacy_mutable_tables_have_updated_at',
      NOT EXISTS (
        SELECT wanted.table_name
        FROM (VALUES
          ('vacations'), ('exams'), ('exam_scores'), ('fund_transactions'),
          ('student_holds'), ('talaqqin_records')
        ) AS wanted(table_name)
        WHERE NOT EXISTS (
          SELECT 1 FROM information_schema.columns AS column_row
          WHERE column_row.table_schema = 'public'
            AND column_row.table_name = wanted.table_name
            AND column_row.column_name = 'updated_at'
        )
      ),
      'all mutable sync domains expose a reliable server watermark'),
    ('sync', 'watermarks_rpc',
      to_regprocedure('public.get_halaqah_sync_watermarks(uuid,uuid)') IS NOT NULL,
      'single preflight RPC replaces empty per-table round trips'),
    ('sync', 'watermarks_execute',
      has_function_privilege('authenticated', 'public.get_halaqah_sync_watermarks(uuid,uuid)', 'EXECUTE'),
      'authenticated halaqah users can read scoped watermarks'),
    ('sync', 'tombstone_scope_index',
      to_regclass('public.idx_sync_tombstones_scope_id') IS NOT NULL
      AND to_regclass('public.idx_sync_tombstones_center_id') IS NOT NULL,
      'accelerates center/halaqa tombstone paging and max-id preflight'),
    ('sync', 'attendance_scope_index',
      to_regclass('public.idx_attendance_sync_scope_updated') IS NOT NULL,
      'center/halaqa/updated_at'),
    ('sync', 'homework_scope_index',
      to_regclass('public.idx_homework_sync_scope_updated') IS NOT NULL,
      'center/halaqa/updated_at'),
    ('sync', 'memorization_scope_index',
      to_regclass('public.idx_memorization_sync_scope_updated') IS NOT NULL,
      'center/halaqa/updated_at'),
    ('sync', 'mushaf_scope_index',
      to_regclass('public.idx_mushaf_sync_student_updated') IS NOT NULL
      AND to_regclass('public.idx_mushaf_sync_center_updated') IS NOT NULL,
      'student delta lookup + center watermark max(updated_at)'),
    ('sync', 'points_scope_index',
      to_regclass('public.idx_points_sync_scope_updated') IS NOT NULL,
      'center/halaqa/updated_at'),
    ('sync', 'exam_template_scope_index',
      to_regclass('public.idx_exam_templates_sync_scope_updated') IS NOT NULL
      AND to_regclass('public.idx_exam_questions_template_order') IS NOT NULL,
      'template watermark plus batched question fetch'),
    ('sync', 'notification_scope_index',
      to_regclass('public.idx_notifications_sync_scope_updated') IS NOT NULL,
      'center/halaqa/updated_at'),
    ('sync', 'extended_watermark_indexes',
      NOT EXISTS (
        SELECT wanted.index_name
        FROM (VALUES
          ('idx_families_sync_scope_updated'),
          ('idx_family_guardians_sync_scope_updated'),
          ('idx_students_sync_scope_updated'),
          ('idx_study_suspensions_sync_scope_updated'),
          ('idx_daily_achievements_sync_scope_updated'),
          ('idx_vacations_sync_scope_updated'),
          ('idx_exams_sync_scope_updated'),
          ('idx_exam_scores_sync_exam_updated'),
          ('idx_fund_transactions_sync_scope_updated'),
          ('idx_student_holds_sync_scope_updated'),
          ('idx_talaqqin_sync_scope_updated'),
          ('idx_admin_actions_sync_scope_updated'),
          ('idx_plans_sync_scope_updated'),
          ('idx_quran_courses_sync_scope_updated'),
          ('idx_course_enrollments_sync_scope_updated'),
          ('idx_plan_recitation_sync_scope_updated')
        ) AS wanted(index_name)
        WHERE to_regclass('public.' || wanted.index_name) IS NULL
      ),
      'remaining watermark probes stay index-backed at large center counts'),
    ('supervision', 'create_supervisor_organization_rpc',
      to_regprocedure('public.create_supervisor_organization(text)') IS NOT NULL,
      'required by new supervisory-account onboarding'),
    ('supervision', 'create_supervisor_execute',
      has_function_privilege('authenticated', 'public.create_supervisor_organization(text)', 'EXECUTE'),
      'authenticated users can create/resume their organization'),
    ('supervision', 'get_my_supervisors_rpc',
      to_regprocedure('public.get_my_supervisors()') IS NOT NULL,
      'required after organization creation'),
    ('supervision', 'owner_membership_identity',
      NOT EXISTS (
        SELECT supervisor_id, user_id
          FROM public.supervisor_members
         GROUP BY supervisor_id, user_id
        HAVING count(*) > 1
      ),
      'one membership per user/organization')
)
SELECT * FROM checks ORDER BY area, check_name;
