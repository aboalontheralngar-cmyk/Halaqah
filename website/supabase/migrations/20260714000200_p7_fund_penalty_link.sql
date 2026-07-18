-- P7: ربط الغرامة المالية بالمخالفة/النقاط السلبية التي سببتها.
-- نفّذ محتوى الملف بعد هجرة هوية الطالب.

alter table public.fund_transactions
  add column if not exists behavior_point_id uuid;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'fund_transactions_behavior_point_id_fkey'
  ) then
    alter table public.fund_transactions
      add constraint fund_transactions_behavior_point_id_fkey
      foreign key (behavior_point_id)
      references public.points(id)
      on delete set null;
  end if;
end
$$;

create index if not exists idx_fund_transactions_behavior_point
  on public.fund_transactions (behavior_point_id)
  where behavior_point_id is not null;

comment on column public.fund_transactions.behavior_point_id is
  'Optional link to the negative points event that caused this financial penalty.';
