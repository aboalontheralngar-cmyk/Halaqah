# حلقتي — نظام إدارة الحلقات القرآنية

تطبيق Android وويب لإدارة الطلاب والحضور والحفظ والمراجعة والخطط والاختبارات
والانضباط والتقارير وأولياء الأمور، مع SQLite للعمل المحلي وSupabase للمصادقة
والمزامنة والنسخ السحابي المشفر.

## الحالة الحالية

- الوظائف الرئيسية منفذة برمجيًا في Flutter وNext.js.
- واجهة الويب تحتوي بوابات إصدار تغطي المسارات التشغيلية، وفحوص الجودة الآلية الحالية تحتوي 69 فحصًا/بوابة تحقق.
- مركز إغلاق اليوم يراجع الحضور الناقص والغياب وعدم التسميع ثم يعتمد النتائج ذريًا بعد الدوام دون تكرار.
- هوية Android والويب تستخدم خط Tajawal الثابت للواجهة، مع نظام بصري مسطح ومضغوط بألوان حلقتي الخضراء/الذهبية الدافئة وSafe Area شاملة؛ ويستخدم PDF الخط نفسه لتوحيد العربية وتجنب اختلاف التشكيل بين الواجهة والتصدير.
- النسخ الجديدة مشفرة بـAES-256-GCM ويمكن حفظها محليًا أو في Supabase Storage.
- سجل التدقيق وسياسة الخصوصية متاحان في Android والويب.
- المشروع في مرحلة ما قبل الإطلاق؛ يلزم تطبيق migrations واختبار جهازين
  وحسابين والطباعة والمشاركة قبل اعتباره إصدارًا مستقرًا.
- تميز أداة بناء Android بين APK مرحلي داخلي وAPK إنتاج موقّع، وتتحقق من
  التوقيع والبصمة وتمنع استعمال هوية `com.example` في الإنتاج.

ابدأ من [فهرس التوثيق الحالي](docs/INDEX.md) و[تدقيق ميزات P1.27](docs/P1.27_FEATURE_AUDIT.md) بدل الاعتماد على قوائم المراحل التاريخية أو وجود الكود وحده كدليل اكتمال.

أحدث دفعة إصلاح موثقة هي **P1.27 Build 85 Hotfix 10** فوق `4.3.0-alpha.28+85` وSQLite 28. تعالج توقف مزامنة الحفظ عند صف سحابي تاريخي غير صالح، وتفصل بين profile المصادقة الأولي وإكمال onboarding، وتعيد الحساب الجديد إلى إعداد الاسم والدور والمركز/الجهة، وتضيف بطاقة هوية للحساب في الموقع. راجع `docs/P1.27_BUILD85_HOTFIX10_SYNC_ONBOARDING.md` و`P1.27_BUILD85_HOTFIX10_INSTALL_NOTE.md`.

## البنية

```text
Halaqah/
├── lib/                         تطبيق Flutter وSQLite والمزامنة
├── test/                        اختبارات منطق الحفظ والتقارير والأمان
├── website/                     Next.js وSupabase
│   ├── src/app/                 صفحات الويب
│   ├── src/store/               حالة التطبيق وعقد البيانات
│   ├── scripts/                 فحوص الإصدار
│   └── supabase/migrations/     ترحيلات آمنة لقواعد قائمة
├── docs/                        التسليمات والسياسات وخطط العمل
├── .github/workflows/           CI وبناء APK
└── CHANGELOG.md                 سجل التطوير التفصيلي
```

## تشغيل Android

المتطلبات: Flutter stable، Java 17، وجهاز Android 6.0 أو أحدث.

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

Android 6.0 هو الحد الأدنى لأن عبارة حماية النسخ تُحفظ في مخزن مفاتيح النظام.

لفحص RC1 وبناء APK مرحلي على Windows بأمر واحد:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1
```

## تشغيل الويب

على Windows، وبعد فك أي حزمة مصدر كاملة أو استبدال ملفات المشروع، نفّذ من
مجلد المشروع الرئيسي:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\setup_web.ps1
```

أو على Windows انقر مرتين على الملف الموجود في جذر المشروع:

```text
SETUP_WEB_WINDOWS.cmd
```

يثبّت هذا الأمر نسخ الحزم المقفلة في `package-lock.json` ويتحقق من TypeScript
والعقود ثم يبني الموقع. عدم وجود `website/node_modules` يجعل VS Code يعرض
أخطاء كاذبة من نوع `Cannot find module 'react'` و`react/jsx-runtime` حتى لو
كان المصدر سليمًا. بعد نجاح الأمر أعد تشغيل خادم TypeScript من لوحة أوامر
VS Code.

وللتشغيل اليدوي على الأنظمة الأخرى:

```bash
cd website
cp .env.example .env.local
npm ci
npm run dev
```

ضع في `.env.local` رابط Supabase والمفتاح العام فقط. لا تضع مفتاح
`service_role` في تطبيق أو متغير يبدأ بـ`NEXT_PUBLIC_`.

## قاعدة Supabase

- لا تنفذ `website/database_schema.sql` على قاعدة تحتوي بيانات؛ هذا الملف مخصص للتثبيت الجديد وقد يكون مدمرًا.
- مخطط المالك الحالي يؤكد وجود نطاق التطبيق وجداول الإشراف، لذلك **لا تعِد** P7.3 ولا guarded bootstrap ولا SQL P1.24 القديم على هذه القاعدة.
- قاعدة المالك اجتازت Build 76 VERIFY سابقًا، لكن مخططها المرسل لاحقًا كشف أن بعض composite UNIQUE اللازمة لـweb upsert غير مثبتة فعليًا.
- بعد Build78 الأساسي نفّذ **Hotfix 3 فقط**: `P1.27_BUILD78_HOTFIX3_APPLY.sql` ثم `P1.27_BUILD78_HOTFIX3_VERIFY.sql`. لا تعاود Build75/76 أو P7.3.
- لا تكتب اسم الملف داخل SQL Editor؛ افتح الملف وانسخ **محتواه** كاملًا.
- مسارات P1.24–P1.26 السابقة تبقى توثيقًا تاريخيًا أو لبيئات أقدم، وليست مسار الإصلاح الحالي. راجع [Build 78](docs/P1.27_BUILD78_COMPLETION.md) و[خطة المتبقي](docs/P1.27_REMAINING_PLAN.md) و[سجل P1.27](docs/P1.27_IMPLEMENTATION_LOG.md).

قبل تفعيل النسخ السحابي نفّذ:

```text
website/supabase/migrations/20260713000300_p6_data_privacy_cloud_backup.sql
```

ثم جرّب إنشاء نسخة مشفرة واستعادتها على مشروع وجهاز تجريبيين.

ولميزات P7.1 نفّذ بالترتيب:

```text
20260714000100_p7_student_identity_foundation.sql
20260714000200_p7_fund_penalty_link.sql
20260714000300_p7_student_review_plan.sql
```

ولبوابة الطالب وولي الأمر نفّذ:

```text
20260714000400_p7_student_portal_security.sql
20260714000600_p7_family_portal.sql
```

ثم انشر Edge Function باسم `student-portal` واضبط السر
`PORTAL_RATE_LIMIT_PEPPER` ونطاق الموقع في `PORTAL_ALLOWED_ORIGINS`.

وللوحة الجهة الإشرافية متعددة المراكز نفّذ:

```text
20260714000500_p7_supervisory_hierarchy.sql
```

بعده اختبر ربط مركز بدعوة مؤقتة، ثم حساب محلل لا يستطيع تعديل بيانات المركز.

ولميزات الخطط والتقارير P1.15 نفّذ محتوى الملفين بالترتيب:

```text
website/supabase/migrations/20260722000300_p1_15_urgent_plans_reports.sql
website/supabase/verification/20260722000300_p1_15_urgent_plans_reports_readiness.sql
```

الملف الثاني للقراءة فقط، والمتوقع أن يعرض أربعة صفوف كلها `passed=true`.

ولتسجيل السرد الرقمي وربطه بإنجاز الخطة P1.16 نفّذ محتوى الملفين بالترتيب:

```text
website/supabase/migrations/20260722000400_p1_16_plan_recitation_tracking.sql
website/supabase/verification/20260722000400_p1_16_plan_recitation_tracking_readiness.sql
```

المتوقع كذلك أربعة صفوف كلها `passed=true`. لا تنسخ اسم الملف إلى محرر SQL؛
افتحه وانسخ محتواه كاملًا.

## ترحيل P1.22 — منفذ ومتحقق

أكد مالك النظام في 2026-08-08 تنفيذ ترحيل P1.22 على Supabase ونجاح فحص التحقق. لقواعد جديدة أو بيئات أخرى يستخدم الملف نفسه بعد أخذ نسخة احتياطية:

```text
website/supabase/migrations/20260808000100_p1_22_activity_talaqqin_admin.sql
```

ثم يشغل الفحص القرائي عند تجهيز أي بيئة جديدة:

```text
website/supabase/verify_p1_22.sql
```

نتيجة التحقق التي أرفقها المالك أكدت `closing_respects_activity_exemption=true` و`closing_respects_full_pause=true`، وأفاد بأن الاستعلام اكتمل دون مشاكل. يبقى مسار التوافق مع P1.21 للحالات التي تُشغل فيها نسخة التطبيق على بيئة سحابية أقدم. تسجيل Google يحتاج تفعيل موفر Google وRedirect URLs ما لم يكن قد فُعل خارجيًا؛ راجع [دليل P1.22](docs/P1.22_SQL_AND_GOOGLE_SETUP.md).

## بوابات الجودة

```bash
cd website
npm run quality:ci
```

يشمل تدقيق الاعتمادات وESLint و69 فحصًا/بوابة تحقق وبناء Next.js. GitHub Actions يشغل
أيضًا `flutter analyze` و`flutter test`، وسير بناء APK لا ينتج الملف إلا بعد
نجاحهما.

## حماية البيانات

- ملف النسخة المشفرة امتداده `.halaqah` ولا يكشف أسماء الطلاب عند فتحه كنص.
- عبارة الحماية لا توجد في قاعدة SQLite أو ملف النسخة أو سجل التدقيق.
- فقد العبارة يعني تعذر استعادة النسخة؛ احفظها خارج الجهاز في مكان موثوق.
- النسخ السحابي خاص بالحساب لكنه يظل مشفرًا قبل الرفع.
- راجع [تسليم P6.2](docs/phase6_2_handoff.md) و[قائمة فحص الإصدار](docs/release_security_checklist.md).

## التوثيق

- [سجل التحسينات](CHANGELOG.md)
- [سجل Build 74](docs/P1.26_BUILD74_HARDENING.md)
- [ملاحظة تثبيت Build 74](P1.26_BUILD74_INSTALL_NOTE.md)
- [سياسة المنصات المدعومة](docs/supported_platforms.md)
- [سجل تنفيذ P1.26](docs/P1.26_IMPLEMENTATION_LOG.md)
- [مسار Supabase الآمن لـP1.26](docs/P1.26_SQL_AND_SETUP.md)
- [مطابقة مخطط Supabase الفعلي بعد bootstrap](docs/P1.26_CLOUD_SCHEMA_RECONCILIATION.md)
- [سجل تنفيذ P1.25](docs/P1.25_IMPLEMENTATION_LOG.md)
- [مسار Supabase الآمن لـP1.25](docs/P1.25_SQL_AND_SETUP.md)
- [تدقيق الميزات المتبقية P1.25](docs/P1.25_REMAINING_FEATURE_AUDIT.md)
- [سجل تنفيذ P1.22](docs/P1.22_IMPLEMENTATION_LOG.md)
- [خطوات SQL وGoogle لـP1.22](docs/P1.22_SQL_AND_GOOGLE_SETUP.md)
- [ملاحظات الإصدار للمستخدم](docs/release_notes.md)
- [الخطة الرئيسية](docs/master_backlog.md)
- [تسليم إغلاق اليوم والتشغيل الآمن P1.13](docs/phase1_13_handoff.md)
- [تسليم الإغلاق السحابي ودوام الحلقة P1.14](docs/phase1_14_handoff.md)
- [تسليم الخطط الذكية والتقرير الإداري P1.15](docs/phase1_15_handoff.md)
- [تسليم السرد الرقمي وإعداد الويب P1.16](docs/phase1_16_handoff.md)
- [تسليم إصلاح الخطط والتقارير P1.16.1](docs/phase1_16_1_handoff.md)
- [تسليم استعادة بيئة الويب P1.16.2](docs/phase1_16_2_handoff.md)
- [الميزات المتبقية بعد P1.16](docs/remaining_feature_work_2026-07-18.md)
- [تسليم الحماية والجودة P6.1](docs/phase6_1_handoff.md)
- [تسليم حماية البيانات P6.2](docs/phase6_2_handoff.md)
- [تسليم الهوية والمساحة الآمنة P6.2.1](docs/phase6_2_1_handoff.md)
- [دليل هوية الواجهات](docs/design_identity_guide.md)


## P1.22 build 66 hotfix (2026-08-08)

- Fixed Flutter compilation in the student period/WhatsApp report by importing `daily_record.dart` for `DailyActivityType`.
- Study-day suspension now preserves all manually entered `daily_records`; suspended dates are excluded by policy instead of deleting history.
- The P1.22 Supabase migration now bootstraps `public.student_holds` when an older deployment is missing the P3 migration, then applies `scope`, trigger, RLS, and the P1.22 closing logic.
- Student-hold cloud sync now tolerates a missing remote table until the owner runs the migration.
- The previous SQL failure `42P01: relation public.student_holds does not exist` is therefore addressed in this build.
