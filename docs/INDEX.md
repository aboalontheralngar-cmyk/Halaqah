# فهرس توثيق حلقتي

هذا هو المدخل الأساسي للتوثيق الحالي. الملفات التاريخية تبقى محفوظة للتتبع، لكن لا ينبغي استخدامها لتحديد حالة الإصدار الحالي دون الرجوع إلى هذا الفهرس.

## الإصدار الحالي

- [Build 84 Hotfix 9](P1.27_BUILD84_HOTFIX9_PERFORMANCE_FEATURES.md) — محرك delta للمزامنة، OAuth، المراجعة المتصلة ونقاط الزيادة.
- [Build 85 Hotfix 10](P1.27_BUILD85_HOTFIX10_SYNC_ONBOARDING.md) — تحصين حفظ/مراجعة السحابة واستكمال onboarding.
- [Build 86 Hotfix 11](P1.27_BUILD86_HOTFIX11_UI_WORKFLOWS.md) — تحديد/طباعة الخطط، واجهة التسميع الموحدة وإصلاحات الاستجابة.
- [Build 87 Hotfix 12](P1.27_BUILD87_HOTFIX12_PORTAL_RECITATION.md) — بوابة same-origin، دعوات الإشراف، سحب مقصود للتسميع، الوضع الداكن وتقريب النقاط.
- [Build 78](P1.27_BUILD78_COMPLETION.md) — تنفيذ ميزات الدفعة الأساسية.
- [Build 78 Hotfix 1](P1.27_BUILD78_HOTFIX1.md) — إصلاحات التجميع والشبكة.
- [Build 78 Hotfix 2](P1.27_BUILD78_HOTFIX2.md) — طباعة الخطط وتقليل إعادة RPC للإجازات العارضة.
- [Build 78 Hotfix 3](P1.27_BUILD78_HOTFIX3.md) — إصلاح مخطط المزامنة، تشخيص مرحلي، وتقليل استهلاك المزامنة التلقائية.
- [Build 78 Hotfix 4](P1.27_BUILD78_HOTFIX4.md) — إصلاح اعتماد الاختبارات على القوالب ومنع فشل المزامنة التلقائية عند غياب عبارة حماية النسخ.
- [Build 80 Hotfix 5](P1.27_BUILD80_HOTFIX5_RECOVERY.md) — استعادة ما بعد حذف التطبيق، حماية versionCode، وتحصين مزامنة الحفظ.
- [Build 81 Hotfix 6](P1.27_BUILD81_HOTFIX6_DELETE_SYNC.md) — تسريع outbox الحذف ومنع تضخم حذف الطالب.
- [Build 82 Hotfix 7](P1.27_BUILD82_HOTFIX7_PORTAL_AUTH_SYNC.md) — إصلاح الحضور 23505، تفعيل/تشخيص البوابة، Google OAuth، ورسائل الإشراف.
- [Build 83 Hotfix 8](P1.27_BUILD83_HOTFIX8_AUTH_SYNC.md) — إصلاح Google OAuth production callback/PKCE، توسيع أنواع الإشعارات، ومزامنة upload-only خفيفة حسب المجالات المتغيرة.
- تقرير التحقق الحالي: `BUILD87_HOTFIX12_VALIDATION_REPORT.md` في جذر المشروع.
- تقرير الاستعادة السابق: `BUILD80_HOTFIX5_VALIDATION_REPORT.md` في جذر المشروع.
- [تدقيق الميزات](P1.27_FEATURE_AUDIT.md) — ما هو منفذ وما يحتاج قبولًا حيًا.
- [خطة المتبقي](P1.27_REMAINING_PLAN.md) — بوابات القبول قبل RC.

## التثبيت وقاعدة البيانات

- ملاحظة التثبيت الحالية: `P1.27_BUILD87_HOTFIX12_INSTALL_NOTE.md` في جذر المشروع.
- عقد البوابة والإشراف اجتاز Build 82 VERIFY؛ لا تعاود P7.3 القديمة.
- للحالة الحالية شغّل `P1.27_BUILD87_HOTFIX12_APPLY.sql` ثم `P1.27_BUILD87_HOTFIX12_VERIFY.sql` لإصلاح portal runtime ومسارات دعوات الإشراف، ثم أعد نشر `student-portal`.
- SQL إصلاح المزامنة الأساسي: `website/supabase/P1.27_BUILD78_HOTFIX3_APPLY.sql`.
- فحص SQL القرائي: `website/supabase/P1.27_BUILD78_HOTFIX3_VERIFY.sql`.
- [دليل تشغيل SQL](how_to_run_supabase_sql_ar.md).
- [سياسة المزامنة السحابية](cloud_sync_policy.md).
- [معمارية مزامنة P1.27](P1.27_SYNC_ARCHITECTURE.md).

## المعمارية والصيانة

- [هيكل المشروع الحالي](architecture/project_structure.md) — حدود الطبقات وقواعد التنظيم الجديدة.
- [التوافق والحجم](compatibility_and_size.md).
- `AGENTS.md` في جذر المشروع — قواعد العمل والصيانة الملزمة.
- `docs/release_notes.md` و`CHANGELOG.md` — ذاكرة التطوير التفصيلية.

## وثائق تاريخية

ملفات `phase1_*`, وملفات إصدارات P1.24–P1.26، وقوائم العمل القديمة هي سجل تاريخي. قد تحتوي بنودًا كانت «متبقية» وقت كتابتها ثم أغلقت لاحقًا. المرجع الحالي للحالة الوظيفية هو `P1.27_FEATURE_AUDIT.md` و`P1.27_REMAINING_PLAN.md`.

## Google Drive

الربط المباشر بـGoogle Drive ما زال **توسعة اختيارية** وليس نقصًا في النسخ الاحتياطي: التطبيق يدعم النسخ المحلية وSupabase Storage المشفر ومشاركة الملف عبر نظام التشغيل. إضافة Drive مباشرة تعني OAuth scopes واعتمادية ومراجعة خصوصية إضافية، ولذلك لا تدخل في Hotfix 4 المخصص لاستقرار المزامنة واعتمادات البيانات.
