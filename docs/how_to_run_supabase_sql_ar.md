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
