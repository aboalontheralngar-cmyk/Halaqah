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
