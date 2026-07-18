-- P7: مقرر المراجعة الافتراضي لكل طالب، مستقل عن مقرر الحفظ.

alter table public.students
  add column if not exists review_plan_amount integer;

update public.students
set review_plan_amount = 10
where review_plan_amount is null or review_plan_amount < 1;

alter table public.students
  alter column review_plan_amount set default 10,
  alter column review_plan_amount set not null;

alter table public.students
  drop constraint if exists students_review_plan_amount_check;

alter table public.students
  add constraint students_review_plan_amount_check
  check (review_plan_amount between 1 and 999);

comment on column public.students.review_plan_amount is
  'Default daily revision amount used by individual and bulk smart plans.';
