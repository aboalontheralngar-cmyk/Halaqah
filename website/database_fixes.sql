-- =====================================================================
--  ملف إصلاحات قاعدة البيانات — حلقتي
--  شغّل هذا الملف كاملاً في Supabase SQL Editor (بعد database_schema.sql)
--  يعالج: 1) فشل إنشاء الحساب (RLS على profiles)
--          2) فشل ربط المعلم (عمود invitation_code + سياسات الانضمام)
--          3) دعم المركز المختلط (رجال + نساء)
-- =====================================================================


-- ---------------------------------------------------------------------
-- (1) إنشاء الملف الشخصي تلقائياً عند التسجيل
--     يحل خطأ: new row violates row-level security policy for "profiles"
--     الدالة تعمل بصلاحية SECURITY DEFINER فتتجاوز RLS وتنشئ الصف فور التسجيل
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, role)
  VALUES (NEW.id, 'center_admin')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ---------------------------------------------------------------------
-- (2-أ) إضافة عمود كود الدعوة للمعلمين (كان مفقوداً من المخطط الأساسي)
--       يحل: فشل إضافة المعلم وفشل البحث عن الكود
-- ---------------------------------------------------------------------
ALTER TABLE center_members ADD COLUMN IF NOT EXISTS invitation_code TEXT;
CREATE INDEX IF NOT EXISTS idx_center_members_invitation_code
  ON center_members(invitation_code);


-- ---------------------------------------------------------------------
-- (2-ب) سياسات RLS لتمكين المعلم من رؤية عضويته
--       (المالك يدير الكل، والمعلم يرى صفوفه فقط)
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Manage center members" ON center_members;

-- المالك يدير أعضاء مركزه بالكامل (إضافة/تعديل/حذف) - بدون recursion
CREATE POLICY "Owner manages members" ON center_members FOR ALL USING (
  center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
) WITH CHECK (
  center_id = ANY(ARRAY(SELECT id FROM centers WHERE owner_id = auth.uid()))
);

-- المعلم يرى صفوف عضويته فقط
DROP POLICY IF EXISTS "Member views own rows" ON center_members;
CREATE POLICY "Member views own rows" ON center_members FOR SELECT USING (
  user_id = auth.uid()
);


-- ---------------------------------------------------------------------
-- (2-ج) دالة الانضمام بالكود (آمنة، تتجاوز RLS عبر SECURITY DEFINER)
--       تتحقق من الكود ومن تطابق البريد ثم تربط المعلم بالمركز
--       يستدعيها التطبيق عبر: supabase.rpc('join_center_with_code', { p_code })
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.join_center_with_code(p_code TEXT)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_member   center_members%ROWTYPE;
  v_email    TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN json_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT email INTO v_email FROM auth.users WHERE id = auth.uid();

  SELECT * INTO v_member
  FROM center_members
  WHERE invitation_code = p_code
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN json_build_object('success', false, 'error', 'invalid_code');
  END IF;

  -- البريد المسجّل يجب أن يطابق البريد المدعو
  IF lower(v_member.email) <> lower(v_email) THEN
    RETURN json_build_object('success', false, 'error', 'email_mismatch',
                             'email', v_member.email);
  END IF;

  -- منع إعادة استخدام الكود من حساب آخر
  IF v_member.user_id IS NOT NULL AND v_member.user_id <> auth.uid() THEN
    RETURN json_build_object('success', false, 'error', 'already_used');
  END IF;

  UPDATE center_members SET user_id = auth.uid() WHERE id = v_member.id;
  UPDATE profiles SET role = 'teacher' WHERE id = auth.uid();

  RETURN json_build_object('success', true, 'center_id', v_member.center_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.join_center_with_code(TEXT) TO authenticated;


-- ---------------------------------------------------------------------
-- (2-د) تمكين المعلم من قراءة بيانات المركز والحلقة بعد انضمامه - بدون recursion
-- ---------------------------------------------------------------------
DROP POLICY IF EXISTS "Members can view their center" ON centers;
CREATE POLICY "Members can view their center" ON centers FOR SELECT USING (
  auth.uid() = owner_id
  OR id = ANY(ARRAY(SELECT center_id FROM center_members WHERE user_id = auth.uid()))
);


-- ---------------------------------------------------------------------
-- (3) دعم المركز المختلط (رجال + نساء) بدل الإجبار على نوع واحد
-- ---------------------------------------------------------------------
ALTER TABLE centers DROP CONSTRAINT IF EXISTS centers_type_check;
ALTER TABLE centers ADD CONSTRAINT centers_type_check
  CHECK (type IN ('men', 'women', 'mixed'));


-- =====================================================================
--  تم. بعد تشغيل هذا الملف، اذهب إلى:
--  Supabase Dashboard > Authentication > Sign In / Providers > Email
--  وعطّل خيار "Confirm email" حتى يحصل المستخدم على جلسة فور التسجيل.
-- =====================================================================
