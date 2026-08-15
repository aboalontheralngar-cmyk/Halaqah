WITH checks AS (
  SELECT
    'guardian_report_subscriptions_table'::TEXT AS check_name,
    to_regclass('public.guardian_report_subscriptions') IS NOT NULL AS passed,
    'جدولة التقارير وموافقة ولي الأمر'::TEXT AS details
  UNION ALL
  SELECT
    'guardian_report_deliveries_table',
    to_regclass('public.guardian_report_deliveries') IS NOT NULL,
    'لقطات التقارير وصف الإرسال الخارجي'
  UNION ALL
  SELECT
    'guardian_report_subscriptions_rls',
    COALESCE((
      SELECT relrowsecurity
      FROM pg_class
      WHERE oid = to_regclass('public.guardian_report_subscriptions')
    ), false),
    'تفعيل RLS على الاشتراكات'
  UNION ALL
  SELECT
    'guardian_report_deliveries_rls',
    COALESCE((
      SELECT relrowsecurity
      FROM pg_class
      WHERE oid = to_regclass('public.guardian_report_deliveries')
    ), false),
    'تفعيل RLS على التقارير المنشورة'
  UNION ALL
  SELECT
    'set_guardian_report_subscription_rpc',
    to_regprocedure(
      'public.set_guardian_report_subscription(uuid,boolean,text,text)'
    ) IS NOT NULL,
    'إدارة الاشتراك من حساب الحلقة'
  UNION ALL
  SELECT
    'publish_due_guardian_reports_rpc',
    to_regprocedure(
      'public.publish_due_guardian_reports(integer)'
    ) IS NOT NULL,
    'نشر التقارير المستحقة'
  UNION ALL
  SELECT
    'family_portal_automatic_reports_rpc',
    to_regprocedure(
      'public.family_portal_get_automatic_reports(text,integer)'
    ) IS NOT NULL,
    'قراءة التقارير من جلسة العائلة'
  UNION ALL
  SELECT
    'guardian_report_public_execute_revoked',
    NOT has_function_privilege(
      'anon',
      'public.publish_due_guardian_reports(integer)',
      'EXECUTE'
    ),
    'منع الزائر من تشغيل ناشر التقارير'
)
SELECT check_name, passed, details
FROM checks
ORDER BY check_name;
