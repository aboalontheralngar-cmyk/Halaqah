-- P7: هوية طالب عامة قابلة للتوسع، منفصلة عن معرّف الصف ورمز QR.
-- انسخ محتوى هذا الملف كاملًا إلى SQL Editor. لا تنفّذ اسم الملف وحده.

create extension if not exists pgcrypto;

alter table public.students
  add column if not exists student_code text;

with candidates as (
  select
    id,
    upper(substr(replace(coalesce(qr_code::text, id::text), '-', ''), 1, 20)) as code,
    row_number() over (
      partition by upper(substr(replace(coalesce(qr_code::text, id::text), '-', ''), 1, 20))
      order by id
    ) as duplicate_rank
  from public.students
  where student_code is null or btrim(student_code) = ''
)
update public.students as student
set student_code = case
  when candidates.duplicate_rank = 1 then candidates.code
  else upper(substr(md5(student.id::text || clock_timestamp()::text), 1, 20))
end
from candidates
where student.id = candidates.id;

create unique index if not exists uq_students_student_code
  on public.students (student_code);

alter table public.students
  alter column student_code set not null;

create or replace function public.generate_student_code()
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  candidate text;
begin
  loop
    candidate := upper(encode(gen_random_bytes(10), 'hex'));
    exit when not exists (
      select 1 from public.students where student_code = candidate
    );
  end loop;
  return candidate;
end;
$$;

alter table public.students
  alter column student_code set default public.generate_student_code();

comment on column public.students.student_code is
  'Public globally unique reference code. It is not an authentication secret.';

revoke execute on function public.generate_student_code() from public;
grant execute on function public.generate_student_code()
  to authenticated, service_role;
