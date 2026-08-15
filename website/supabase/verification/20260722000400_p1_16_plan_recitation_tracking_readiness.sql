-- Read-only verification after applying P1.16.
-- Expected: every returned row has passed=true.

with table_state as (
  select
    to_regclass('public.plan_recitation_records') is not null as table_exists,
    coalesce((
      select relrowsecurity
      from pg_class
      where oid = to_regclass('public.plan_recitation_records')
    ), false) as rls_enabled
), column_state as (
  select count(*) = 14 as complete
  from information_schema.columns
  where table_schema = 'public'
    and table_name = 'plan_recitation_records'
    and column_name in (
      'id', 'session_id', 'center_id', 'halaqa_id', 'plan_id', 'student_id',
      'surah_id', 'from_ayah', 'to_ayah', 'segment_order', 'date',
      'quality_rating', 'created_at', 'updated_at'
    )
), policy_state as (
  select count(*) >= 1 as scoped
  from pg_policies
  where schemaname = 'public'
    and tablename = 'plan_recitation_records'
    and roles @> array['authenticated']::name[]
), trigger_state as (
  select count(*) = 1 as guarded
  from pg_trigger
  where tgrelid = to_regclass('public.plan_recitation_records')
    and tgname = 'validate_plan_recitation_record'
    and not tgisinternal
)
select 'plan_recitation_table' as check_name,
       table_exists as passed,
       'جدول جلسات السرد الرقمية' as details
from table_state
union all
select 'plan_recitation_columns', complete,
       'الأعمدة الأساسية وربط الجلسة والخطة'
from column_state
union all
select 'plan_recitation_rls', rls_enabled and scoped,
       'RLS وسياسة الحلقة للمستخدم المسجل'
from table_state cross join policy_state
union all
select 'plan_recitation_scope_trigger', guarded,
       'منع خلط الطالب والخطة والحلقة والتاريخ'
from trigger_state;
