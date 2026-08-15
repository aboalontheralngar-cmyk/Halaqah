with checks as (
  select
    'public.plans.recitation_amount'::text as check_name,
    exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'plans'
        and column_name = 'recitation_amount'
    ) as passed,
    'مقرر السرد في الخطط'::text as details
  union all
  select
    'public.fund_transactions.settled_negative_points',
    exists (
      select 1 from information_schema.columns
      where table_schema = 'public'
        and table_name = 'fund_transactions'
        and column_name = 'settled_negative_points'
    ),
    'تسوية النقاط السلبية بالصندوق'
  union all
  select
    'plans_recitation_amount_positive',
    exists (
      select 1 from pg_constraint
      where conname = 'plans_recitation_amount_positive'
        and conrelid = 'public.plans'::regclass
    ),
    'منع مقرر سرد صفري أو سالب'
  union all
  select
    'fund_transactions_settled_points_nonnegative',
    exists (
      select 1 from pg_constraint
      where conname = 'fund_transactions_settled_points_nonnegative'
        and conrelid = 'public.fund_transactions'::regclass
    ),
    'منع تسوية سالبة'
)
select check_name, passed, details
from checks
order by check_name;
