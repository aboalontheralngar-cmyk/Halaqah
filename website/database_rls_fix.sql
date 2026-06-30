-- =====================================================================
--  إصلاح مشكلة Infinite Recursion في سياسات RLS لجدول centers
--  المشكلة: centers تتحقق من center_members، و center_members تتحقق من centers
--  الحل: استخدام دالة SECURITY DEFINER لكسر حلقة التبعية
--  شغّل هذا الملف في Supabase SQL Editor
-- =====================================================================


-- ---------------------------------------------------------------------
-- (1) دالة مساعدة: تُرجع قائمة center_ids التي يملكها المستخدم
--     تعمل بصلاحية SECURITY DEFINER فتتجاوز RLS تماماً
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_owned_center_ids()
RETURNS UUID[]
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(id), '{}')
  FROM centers
  WHERE owner_id = auth.uid();
$$;


-- ---------------------------------------------------------------------
-- (2) دالة مساعدة: تُرجع قائمة center_ids التي المستخدم عضو فيها
--     تعمل بصلاحية SECURITY DEFINER فتتجاوز RLS تماماً
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_user_member_center_ids()
RETURNS UUID[]
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT COALESCE(array_agg(center_id), '{}')
  FROM center_members
  WHERE user_id = auth.uid();
$$;


-- ---------------------------------------------------------------------
-- (3) إصلاح سياسات centers — بدون أي subquery على center_members
-- ---------------------------------------------------------------------

-- حذف جميع السياسات القديمة على centers
DROP POLICY IF EXISTS "Enable insert for authenticated users only" ON centers;
DROP POLICY IF EXISTS "Enable select for owners" ON centers;
DROP POLICY IF EXISTS "Enable update for owners" ON centers;
DROP POLICY IF EXISTS "Enable delete for owners" ON centers;
DROP POLICY IF EXISTS "Members can view their center" ON centers;

-- INSERT: المستخدم المسجّل يمكنه إنشاء مركز يملكه
CREATE POLICY "centers_insert" ON centers
    FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- SELECT: المالك يرى مراكزه + العضو يرى مركزه (عبر الدالة الآمنة)
CREATE POLICY "centers_select" ON centers
    FOR SELECT USING (
        auth.uid() = owner_id
        OR id = ANY(public.get_user_member_center_ids())
    );

-- UPDATE: المالك فقط
CREATE POLICY "centers_update" ON centers
    FOR UPDATE USING (auth.uid() = owner_id) WITH CHECK (auth.uid() = owner_id);

-- DELETE: المالك فقط
CREATE POLICY "centers_delete" ON centers
    FOR DELETE USING (auth.uid() = owner_id);


-- ---------------------------------------------------------------------
-- (4) إصلاح سياسات center_members — باستخدام الدالة الآمنة بدلاً من subquery
-- ---------------------------------------------------------------------

-- حذف جميع السياسات القديمة
DROP POLICY IF EXISTS "Manage center members" ON center_members;
DROP POLICY IF EXISTS "Owner manages members" ON center_members;
DROP POLICY IF EXISTS "Member views own rows" ON center_members;
DROP POLICY IF EXISTS "Allow select center_members by user or email" ON center_members;

-- المالك يدير أعضاء مراكزه (عبر الدالة الآمنة)
CREATE POLICY "cm_owner_all" ON center_members FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
) WITH CHECK (
    center_id = ANY(public.get_user_owned_center_ids())
);

-- العضو يرى صفوفه فقط (بدون subquery)
CREATE POLICY "cm_member_select" ON center_members FOR SELECT USING (
    user_id = auth.uid()
    OR email = auth.jwt()->>'email'
);


-- ---------------------------------------------------------------------
-- (5) إصلاح سياسات الجداول التابعة — باستخدام الدالة الآمنة
-- ---------------------------------------------------------------------

-- halaqat
DROP POLICY IF EXISTS "Access halaqat by center_id" ON halaqat;
CREATE POLICY "halaqat_access" ON halaqat FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- students
DROP POLICY IF EXISTS "Access students by center_id" ON students;
CREATE POLICY "students_access" ON students FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- attendance
DROP POLICY IF EXISTS "Access attendance by center_id" ON attendance;
CREATE POLICY "attendance_access" ON attendance FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- memorization
DROP POLICY IF EXISTS "Access memorization by center_id" ON memorization;
CREATE POLICY "memorization_access" ON memorization FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- points
DROP POLICY IF EXISTS "Access points by center_id" ON points;
CREATE POLICY "points_access" ON points FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- exams
DROP POLICY IF EXISTS "Access exams by center_id" ON exams;
CREATE POLICY "exams_access" ON exams FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- exam_scores
DROP POLICY IF EXISTS "Access exam_scores by center_id" ON exam_scores;
CREATE POLICY "exam_scores_access" ON exam_scores FOR ALL USING (
    exam_id IN (
        SELECT id FROM exams WHERE
            center_id = ANY(public.get_user_owned_center_ids())
            OR center_id = ANY(public.get_user_member_center_ids())
    )
);

-- vacations
DROP POLICY IF EXISTS "Access vacations by center_id" ON vacations;
CREATE POLICY "vacations_access" ON vacations FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);

-- activities
DROP POLICY IF EXISTS "Access activities by center_id" ON activities;
CREATE POLICY "activities_access" ON activities FOR ALL USING (
    center_id = ANY(public.get_user_owned_center_ids())
    OR center_id = ANY(public.get_user_member_center_ids())
);


-- ---------------------------------------------------------------------
-- (6) إصلاح سياسات الجداول الموسّعة (من database_schema_extensions)
-- ---------------------------------------------------------------------

-- الجداول الموسّعة التي تحتوي على center_id
DO $$
DECLARE
  t TEXT;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'fund_transactions', 'plans', 'recitation_errors', 'prayer_tracking',
    'appearance_checks', 'absence_followups', 'notifications',
    'message_templates', 'exam_templates', 'weekly_competitions', 'center_settings',
    'homework_grades', 'mushaf_progress'
  ]
  LOOP
    -- تحقق من وجود الجدول قبل تعديل السياسة
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = t AND table_schema = 'public') THEN
      EXECUTE format('DROP POLICY IF EXISTS "Access %I by center" ON %I', t, t);
      EXECUTE format($f$
        CREATE POLICY "Access %I by center" ON %I FOR ALL USING (
          center_id = ANY(public.get_user_owned_center_ids())
          OR center_id = ANY(public.get_user_member_center_ids())
        )
      $f$, t, t);
    END IF;
  END LOOP;
END $$;

-- exam_questions (عبر template)
DROP POLICY IF EXISTS "Access exam_questions via template" ON exam_questions;
CREATE POLICY "exam_questions_access" ON exam_questions FOR ALL USING (
    template_id IN (
        SELECT id FROM exam_templates WHERE
            center_id = ANY(public.get_user_owned_center_ids())
            OR center_id = ANY(public.get_user_member_center_ids())
    )
);

-- competition_entries (عبر competition)
DROP POLICY IF EXISTS "Access competition_entries via competition" ON competition_entries;
CREATE POLICY "competition_entries_access" ON competition_entries FOR ALL USING (
    competition_id IN (
        SELECT id FROM weekly_competitions WHERE
            center_id = ANY(public.get_user_owned_center_ids())
            OR center_id = ANY(public.get_user_member_center_ids())
    )
);


-- =====================================================================
--  تم! هذا الملف يحل مشكلة infinite recursion نهائياً عن طريق:
--  1. دالتان SECURITY DEFINER تتجاوزان RLS لجلب center_ids
--  2. جميع السياسات تستخدم هاتين الدالتين بدلاً من subqueries مباشرة
--  3. لا يوجد أي subquery من جدول يتحقق من جدول آخر عبر RLS
-- =====================================================================
