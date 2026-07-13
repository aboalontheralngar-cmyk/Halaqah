# تدقيق مخطط Supabase المرفق — 2026-07-12

## سبب خطأ الخطط

المخطط يحتوي جداول `centers` و`center_members` و`halaqat`، لكنه لا يحتوي الدالة:

`public.current_user_can_access_halaqa(uuid, uuid)`

لذلك فشلت سياسة RLS في migration الخطط. عُدّل ملف الخطط ليُنشئ دالتي الصلاحيات المتوافقتين مع المخطط أولًا، ويشمل مالك المركز والمدير والمعلم المعيّن والمشرف المالك.

## الفجوات المؤكدة من المخطط المرفق

| المجال | الموجود حاليًا | المطلوب للتطبيق |
|---|---|---|
| تقدم الطالب | لا تظهر أعمدة `total_memorized` و`qr_code` و`updated_at` ونطاق المحفوظ السابق | migration سلامة تقدم الطالب P0-001 |
| نطاق الحلقة | لا تظهر `halaqa_id` في الحضور والحفظ والنقاط والاختبارات | migrations P0-001 وP0-002 |
| الصلاحيات | دوال نطاق المركز/الحلقة غير موجودة | ملف الخطط المصحح ينشئ الأساس؛ وP0-002 يكمل سياسات بقية الجداول |
| نماذج الاختبارات | الجدول قديم ولا يحتوي الطالب والحلقة والمعايير ووقت التحديث | migration P2-003 |
| إيقاف التسميع | جدول `student_holds` غير موجود | migration P3-004 |
| الخطط | لا توجد حالة اختبار التجاوز أو معرف الاختبار أو الحذف اللين أو وقت التحديث | migration الخطط P5-001 المصحح |
| أرشيف الطلاب | حقل الحالة موجود لكن لا يوجد سجل لأسباب التغيير | migration الأرشيف والنقاط P5.2 |
| النقاط | لا يوجد `halaqa_id`، وبعض مزامنة Android كانت تحول السالب إلى موجب | migration الأرشيف والنقاط يصلح النطاق والإشارة ويضيف سجل التصحيح |
| متميزو اليوم | لا يوجد جدول لحفظ أسباب التميز والمكافآت | migration متميزو اليوم P5.3 |
| العائلات وأولياء الأمور | لا يوجد كيان عائلة، وصفحة الويب كانت تجريبية | migration العائلات P5.4 يضيف العائلة والأولياء والربط المحمي |
| درجات الاختبارات | لا يظهر قيد فريد على `(exam_id, student_id)` | يجب فحص التكرارات قبل إضافة القيد لأن الويب يعتمد عليه في `upsert` |
| خريطة المصحف | لا يظهر قيد فريد على `(student_id, hizb_number, thumun_number)` | يجب فحص التكرارات قبل إضافة القيد لأن الويب وAndroid يعتمدان عليه |

## ترتيب آمن مقترح

1. نسخة احتياطية كاملة.
2. `20260711000100_p0_student_progress_integrity.sql`.
3. `20260711000200_p0_security_qr_attendance.sql` على قاعدة تجريبية وحسابات متعددة.
4. `20260711000300_p2_exam_templates.sql`.
5. `20260711000400_p3_student_holds.sql`.
6. `20260712000100_p5_smart_plans.sql` المصحح.
7. `20260712000200_p5_student_archive_behavior_audit.sql`.
8. `20260712000300_p5_daily_excellence.sql`.
9. `20260712000400_p5_families_guardians.sql`.

كل ملف مستقل وتراكمي. لا تستخدم `website/database_schema.sql` على قاعدة قائمة.

## فحص التكرارات قبل القيود الفريدة

```sql
SELECT exam_id, student_id, COUNT(*)
FROM public.exam_scores
GROUP BY exam_id, student_id
HAVING COUNT(*) > 1;

SELECT student_id, hizb_number, thumun_number, COUNT(*)
FROM public.mushaf_progress
GROUP BY student_id, hizb_number, thumun_number
HAVING COUNT(*) > 1;

SELECT student_id, date, COUNT(*)
FROM public.attendance
GROUP BY student_id, date
HAVING COUNT(*) > 1;
```

إذا أعادت الاستعلامات صفوفًا، لا تحذفها عشوائيًا؛ صدّرها أولًا وحدد السجل الصحيح قبل إنشاء القيد الفريد.

## ملاحظة على ملف المخطط

ظهر عمود `memorization_direction` مرتين في نص التصدير. PostgreSQL لا يسمح فعليًا بعمودين بالاسم نفسه، ولذلك يُرجح أن هذا تكرار في النص الملصق لا في الجدول. يمكن التحقق عبر:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'students'
ORDER BY ordinal_position;
```
