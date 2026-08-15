-- P1.15: مقرر السرد في الخطط، وتسوية النقاط السلبية عبر الصندوق.
-- انسخ محتوى الملف فقط إلى Supabase SQL Editor، ولا تنسخ اسم الملف.

begin;

alter table public.plans
  add column if not exists recitation_amount integer not null default 1;

update public.plans
set recitation_amount = 1
where recitation_amount is null or recitation_amount < 1;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'plans_recitation_amount_positive'
      and conrelid = 'public.plans'::regclass
  ) then
    alter table public.plans
      add constraint plans_recitation_amount_positive
      check (recitation_amount > 0);
  end if;
end
$$;

comment on column public.plans.recitation_amount is
  'Daily connected recitation/telawah assignment, separate from memorization and review.';

alter table public.fund_transactions
  add column if not exists settled_negative_points integer not null default 0;

update public.fund_transactions
set settled_negative_points = 0
where settled_negative_points is null or settled_negative_points < 0;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fund_transactions_settled_points_nonnegative'
      and conrelid = 'public.fund_transactions'::regclass
  ) then
    alter table public.fund_transactions
      add constraint fund_transactions_settled_points_nonnegative
      check (settled_negative_points >= 0);
  end if;
end
$$;

create index if not exists idx_fund_transactions_student_penalty_settlement
  on public.fund_transactions (student_id, date desc)
  where type = 'penalty' and settled_negative_points > 0;

comment on column public.fund_transactions.settled_negative_points is
  'Negative points covered by this payment; the original violation remains in the audit history.';

commit;
