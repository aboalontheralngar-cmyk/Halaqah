# طريقة تنفيذ SQL في Supabase

## المهم أولًا

لا تكتب اسم الملف داخل SQL Editor. العبارة التالية ليست SQL وستنتج الخطأ `trailing junk after numeric literal`:

```text
20260712000050_scope_helpers_compat.sql
```

## الطريقة الصحيحة

1. افتح ملف `.sql` المطلوب كنص.
2. حدّد محتواه كاملًا من أول `BEGIN;` إلى آخر `COMMIT;`.
3. انسخ المحتوى.
4. افتح Supabase ثم **SQL Editor** ثم **New query**.
5. الصق محتوى SQL نفسه واضغط **Run**.

## معالجة خطأ دالة الصلاحيات

نفّذ محتوى الملف التالي أولًا:

`website/supabase/migrations/20260712000050_scope_helpers_compat.sql`

ثم نفّذ هذا الاستعلام وحده للتحقق:

```sql
SELECT to_regprocedure(
  'public.current_user_can_access_halaqa(uuid,uuid)'
) AS created_function;
```

النتيجة الصحيحة يجب أن تكون:

```text
current_user_can_access_halaqa(uuid,uuid)
```

بعد ذلك نفّذ محتوى ملف الخطط المصحح:

`website/supabase/migrations/20260712000100_p5_smart_plans.sql`

الملف المصحح ينشئ الدالة بنفسه أيضًا، ولذلك يمكن تشغيله مباشرة بدل الخطوتين إذا نسخت **محتواه كاملًا**.

## مرحلة أرشيف الطلاب والنقاط

بعد migration الخطط نفّذ محتوى الملف التالي كاملًا:

`website/supabase/migrations/20260712000200_p5_student_archive_behavior_audit.sql`

هذا الملف يضيف سجل حالات الطلاب وسجل تصحيحات النقاط، ويصلح إشارات النقاط السلبية القديمة. شغّله أولًا على مشروع تجريبي بعد أخذ نسخة احتياطية.

بعد نجاحه نفّذ محتوى ملف متميزي اليوم:

`website/supabase/migrations/20260712000300_p5_daily_excellence.sql`

يضيف هذا الملف سجل التميز والمكافآت ودالة ذرية لاعتماد التكريم ونقاطه.

بعد نجاحه نفّذ محتوى ملف العائلات وأولياء الأمور:

`website/supabase/migrations/20260712000400_p5_families_guardians.sql`

يضيف هذا الملف العائلات وأولياء الأمور وحقل ربط الطالب وسياسات RLS ودالة الربط الجماعي. لا يدمج الطلاب تلقائيًا اعتمادًا على رقم الهاتف أو تشابه الاسم؛ الربط يتم يدويًا لتجنب إسناد خاطئ.

## معالجة خطأ `progress.halaqa_id`

إذا ظهرت الرسالة:

```text
column progress.halaqa_id does not exist
```

فنفّذ محتوى الملفات التالية بالترتيب، كل ملف في **New query** مستقل:

1. `website/supabase/migrations/20260713000090_p5_memorization_halaqa_compat.sql`
2. `website/supabase/migrations/20260713000100_p5_web_recitation_parity.sql`
3. `website/supabase/migrations/20260713000200_p5_advanced_mushaf_exams.sql`

الملف الأول ينشئ `memorization.halaqa_id` ويملؤه من حلقة الطالب قبل أن
تستعمله ترحيلات التسميع. الملفات لا تحتوي `DROP TABLE` أو `TRUNCATE`، لكن
يلزم أخذ نسخة احتياطية وتجربتها على مشروع مرحلي قبل قاعدة الإنتاج.

## مرحلة حماية البيانات والنسخ السحابي المشفر P6.2

بعد نجاح الملفات السابقة، نفّذ **محتوى** الملف التالي كاملًا في استعلام جديد:

`website/supabase/migrations/20260713000300_p6_data_privacy_cloud_backup.sql`

هذا الملف مستقل ويعيد إنشاء دوال الصلاحيات المطلوبة بالتوقيع الصحيح، ولذلك لا
يعتمد على وجود `current_user_can_access_halaqa(uuid, uuid)` مسبقًا. كما أنه لا
يستخدم العمود الخاطئ `progress.halaqa_id`، ولا يحتوي `DROP TABLE` أو `TRUNCATE`.

بعد ظهور `Success` شغّل استعلامي التحقق التاليين كل واحد على حدة:

```sql
SELECT to_regprocedure(
  'public.write_audit_event(text,text,uuid,uuid,uuid,text,jsonb)'
) AS audit_rpc;
```

```sql
SELECT id, public, file_size_limit
FROM storage.buckets
WHERE id = 'halaqah-backups';
```

النتيجة الصحيحة: تظهر الدالة، ويظهر bucket باسم `halaqah-backups` وقيمة
`public = false` وحد أقصى `104857600` بايت. بعد ذلك أنشئ نسخة مشفرة من التطبيق
وارفعها بحساب تجريبي، ثم تأكد أن حسابًا ثانيًا لا يستطيع رؤيتها.

## توافق محفوظ الطالب مع شاشة المراجعة P6.3

نفّذ محتوى الملف التالي كاملًا في استعلام جديد:

`website/supabase/migrations/20260713000400_p6_revision_profile_range_compat.sql`

هذا الملف يضيف فقط أعمدة نطاق المحفوظ المفقودة إلى جدول `students`، ويمكن
تشغيله أكثر من مرة بأمان. لا يحذف بيانات ولا يحتاج دوال الصلاحيات السابقة.
بعد نجاحه افتح ملف طالب متأثر واحفظ نطاقه مرة واحدة ثم نفّذ المزامنة.

للتحقق:

```sql
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'students'
  AND column_name LIKE 'pre_memorized_%'
ORDER BY column_name;
```

يجب أن تظهر أربعة أعمدة للبداية والنهاية والسورة والآية.

## الجهة الإشرافية متعددة المراكز P7.3

بعد نجاح migration بوابة الطالب P7.2، نفّذ **محتوى** الملف التالي كاملًا في
استعلام جديد، ولا تكتب اسم الملف داخل المحرر:

`website/supabase/migrations/20260714000500_p7_supervisory_hierarchy.sql`

ينشئ الملف العضويات والأدوار والدعوات المؤقتة وسجل الربط ودوال التقرير. كما
يرحّل مالك كل جهة موجودة إلى دور `owner` دون فك أي مركز مرتبط حاليًا.

للتحقق بعد ظهور `Success`:

```sql
SELECT to_regprocedure(
  'public.get_supervisor_dashboard(uuid,date,date)'
) AS dashboard_rpc;
```

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'supervisor_members',
    'supervisor_center_invitations',
    'supervisor_member_invitations',
    'supervisor_audit_events'
  )
ORDER BY table_name;
```

يجب أن تظهر الدالة والجداول الأربعة. بعد ذلك نفّذ الاختبار بحسابات منفصلة؛
نجاح SQL وحده لا يثبت عزل RLS.

## حساب ولي الأمر متعدد الأبناء P7.2.1

بعد نجاح P5.4 وP7.2، نفّذ **محتوى** الملف التالي كاملًا في استعلام جديد:

`website/supabase/migrations/20260714000600_p7_family_portal.sql`

لا تكتب اسم الملف وحده داخل SQL Editor. ينشئ الملف كود عائلة عالميًا، واعتماد
PIN مجزأ، وجلسات عائلية، ويعيد استخدام لوحة الطالب بعد التحقق من أن الابن
النشط مرتبط بالعائلة صاحبة الجلسة.

إذا ظهرت الرسالة `function gen_random_bytes(integer) does not exist` فهذا يعني
أنك تستخدم نسخة الملف السابقة التي لم تضف مخطط Supabase `extensions` إلى
`search_path`. حمّل نسخة 2026-07-18 المصححة وأعد تشغيل **الملف كاملًا** في
استعلام جديد؛ لا تنفذ السطر 76 وحده ولا تنشئ دالة بديلة يدويًا.

للتحقق بعد ظهور `Success`:

```sql
SELECT
  to_regprocedure('public.family_portal_authenticate(text,text,text)') AS login_rpc,
  to_regprocedure('public.family_portal_get_dashboard(text,integer,uuid)') AS dashboard_rpc,
  to_regprocedure('public.get_family_portal_status(uuid)') AS status_rpc;
```

```sql
SELECT COUNT(*) AS invalid_family_codes
FROM public.families
WHERE family_code IS NULL OR family_code !~ '^[A-F0-9]{20}$';
```

يجب أن تظهر الدوال الثلاث وأن تكون `invalid_family_codes = 0`. بعدها أعد نشر
Edge Function `student-portal`، واختبر عائلتين منفصلتين؛ لا يكفي نجاح SQL وحده.
