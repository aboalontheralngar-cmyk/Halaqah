# حلقتي — نظام إدارة الحلقات القرآنية

تطبيق Android وويب لإدارة الطلاب والحضور والحفظ والمراجعة والخطط والاختبارات
والانضباط والتقارير وأولياء الأمور، مع SQLite للعمل المحلي وSupabase للمصادقة
والمزامنة والنسخ السحابي المشفر.

## الحالة الحالية

- الوظائف الرئيسية منفذة برمجيًا في Flutter وNext.js.
- واجهة الويب تبني 30 مسارًا بنجاح، وبوابة الجودة تحتوي 28 فحص عقد.
- هوية Android والويب موحدة بخط Tajawal محلي وألوان قرآنية هادئة وSafe Area شاملة.
- النسخ الجديدة مشفرة بـAES-256-GCM ويمكن حفظها محليًا أو في Supabase Storage.
- سجل التدقيق وسياسة الخصوصية متاحان في Android والويب.
- المشروع في مرحلة ما قبل الإطلاق؛ يلزم تطبيق migrations واختبار جهازين
  وحسابين والطباعة والمشاركة قبل اعتباره إصدارًا مستقرًا.
- تميز أداة بناء Android بين APK مرحلي داخلي وAPK إنتاج موقّع، وتتحقق من
  التوقيع والبصمة وتمنع استعمال هوية `com.example` في الإنتاج.

راجع [خطة المتطلبات](docs/master_backlog.md) و[المراحل المتبقية](docs/remaining_phases_2026-07-12.md)
بدل الاعتماد على وجود الكود وحده كدليل اكتمال.

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

```bash
cd website
cp .env.example .env.local
npm ci
npm run dev
```

ضع في `.env.local` رابط Supabase والمفتاح العام فقط. لا تضع مفتاح
`service_role` في تطبيق أو متغير يبدأ بـ`NEXT_PUBLIC_`.

## قاعدة Supabase

- لا تنفذ `website/database_schema.sql` على قاعدة تحتوي بيانات؛ هذا الملف
  مخصص للتثبيت الجديد وقد يكون مدمرًا.
- لقواعد البيانات القائمة نفّذ محتويات الملفات في
  `website/supabase/migrations/` بالترتيب بعد أخذ نسخة احتياطية.
- لا تكتب اسم ملف migration داخل SQL Editor؛ انسخ محتوى الملف كاملًا كما هو.
- يشرح [دليل SQL العربي](docs/how_to_run_supabase_sql_ar.md) الأخطاء المعروفة
  وترتيب التنفيذ والتحقق.

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

## بوابات الجودة

```bash
cd website
npm run quality:ci
```

يشمل تدقيق الاعتمادات وESLint و25 فحص عقد وبناء Next.js. GitHub Actions يشغل
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
- [ملاحظات الإصدار للمستخدم](docs/release_notes.md)
- [الخطة الرئيسية](docs/master_backlog.md)
- [تسليم الحماية والجودة P6.1](docs/phase6_1_handoff.md)
- [تسليم حماية البيانات P6.2](docs/phase6_2_handoff.md)
- [تسليم الهوية والمساحة الآمنة P6.2.1](docs/phase6_2_1_handoff.md)
- [دليل هوية الواجهات](docs/design_identity_guide.md)
