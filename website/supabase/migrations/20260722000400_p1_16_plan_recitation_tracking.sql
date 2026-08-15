-- P1.16: digital sard/tilawah sessions linked to smart-plan completion.
-- Paste this file's CONTENTS into Supabase SQL Editor, not its filename.

begin;

-- Recreate the scoped helper so this migration is safe on databases that
-- missed the earlier compatibility file.
create or replace function public.current_user_is_center_admin(p_center_id uuid)
returns boolean
language plpgsql
security definer
stable
set search_path = public, pg_temp
as $$
declare
  allowed boolean := false;
begin
  if auth.uid() is null then
    return false;
  end if;
  select (
    exists (
      select 1 from public.centers center_row
      where center_row.id = p_center_id
        and center_row.owner_id = auth.uid()
    )
    or exists (
      select 1 from public.center_members member_row
      where member_row.center_id = p_center_id
        and member_row.user_id = auth.uid()
        and member_row.role = 'admin'
    )
  ) into allowed;
  if allowed then return true; end if;

  -- Older databases may not have supervisory hierarchy yet. Dynamic SQL
  -- keeps this compatibility helper runnable in both schemas.
  if to_regclass('public.supervisors') is not null
     and exists (
       select 1 from information_schema.columns
       where table_schema = 'public'
         and table_name = 'centers'
         and column_name = 'supervisor_id'
     ) then
    execute '
      select exists (
        select 1
        from public.centers center_row
        join public.supervisors supervisor_row
          on supervisor_row.id = center_row.supervisor_id
        where center_row.id = $1
          and supervisor_row.owner_id = $2
      )'
      into allowed
      using p_center_id, auth.uid();
  end if;
  return coalesce(allowed, false);
end;
$$;

create or replace function public.current_user_can_access_halaqa(
  p_center_id uuid,
  p_halaqa_id uuid
)
returns boolean
language sql
security definer
stable
set search_path = public, pg_temp
as $$
  select public.current_user_is_center_admin(p_center_id)
    or exists (
      select 1 from public.center_members member_row
      where member_row.center_id = p_center_id
        and member_row.user_id = auth.uid()
        and member_row.role = 'teacher'
        and p_halaqa_id is not null
        and member_row.halaqah_id = p_halaqa_id
    );
$$;

revoke all on function public.current_user_is_center_admin(uuid)
  from public, anon;
revoke all on function public.current_user_can_access_halaqa(uuid, uuid)
  from public, anon;
grant execute on function public.current_user_is_center_admin(uuid)
  to authenticated;
grant execute on function public.current_user_can_access_halaqa(uuid, uuid)
  to authenticated;

create table if not exists public.plan_recitation_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null,
  center_id uuid not null references public.centers(id) on delete cascade,
  halaqa_id uuid not null references public.halaqat(id) on delete cascade,
  plan_id uuid not null references public.plans(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  surah_id smallint not null check (surah_id between 1 and 114),
  from_ayah smallint not null check (from_ayah >= 1),
  to_ayah smallint not null check (to_ayah >= from_ayah),
  segment_order smallint not null default 0 check (segment_order >= 0),
  date date not null,
  quality_rating smallint not null default 3
    check (quality_rating between 1 and 5),
  notes text check (notes is null or char_length(notes) <= 2000),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(session_id, segment_order)
);

create index if not exists idx_plan_recitation_scope_date
  on public.plan_recitation_records(center_id, halaqa_id, date desc);
create index if not exists idx_plan_recitation_plan_date
  on public.plan_recitation_records(plan_id, date desc, segment_order);
create index if not exists idx_plan_recitation_student_date
  on public.plan_recitation_records(student_id, date desc);

create or replace function public.validate_plan_recitation_record()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if not exists (
    select 1
    from public.plans plan_row
    join public.students student_row on student_row.id = new.student_id
    where plan_row.id = new.plan_id
      and plan_row.student_id = new.student_id
      and plan_row.center_id = new.center_id
      and plan_row.halaqa_id = new.halaqa_id
      and student_row.center_id = new.center_id
      and student_row.halaqa_id = new.halaqa_id
      and new.date between plan_row.start_date and plan_row.end_date
  ) then
    raise exception 'plan_recitation_scope_or_date_mismatch';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists validate_plan_recitation_record
  on public.plan_recitation_records;
create trigger validate_plan_recitation_record
  before insert or update on public.plan_recitation_records
  for each row execute function public.validate_plan_recitation_record();

revoke all on function public.validate_plan_recitation_record()
  from public, anon, authenticated;

alter table public.plan_recitation_records enable row level security;

drop policy if exists plan_recitation_records_scoped_all
  on public.plan_recitation_records;
create policy plan_recitation_records_scoped_all
  on public.plan_recitation_records
  for all to authenticated
  using (public.current_user_can_access_halaqa(center_id, halaqa_id))
  with check (public.current_user_can_access_halaqa(center_id, halaqa_id));

revoke all on public.plan_recitation_records from public, anon;
grant select, insert, update, delete
  on public.plan_recitation_records to authenticated;

comment on table public.plan_recitation_records is
  'Digital connected sard/tilawah sessions; separate from memorized content.';
comment on column public.plan_recitation_records.session_id is
  'Groups per-surah segments created by one connected teacher action.';

commit;
