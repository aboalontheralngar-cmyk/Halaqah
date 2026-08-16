# Build 78 Validation Report

**Release:** P1.27 Build 78 — `4.3.0-alpha.24+78`  
**SQLite:** 26  
**Date:** 2026-08-15

## نتائج بيئة التحرير

- Release validators: **66/66 passed** بعد تجميد التوثيق والهوية النهائية.
- JavaScript/MJS/CJS syntax: **69/69 passed** بعد آخر تعديل.
- TypeScript/TSX syntax transpilation: **51/51 passed** بعد آخر تعديل باستخدام TypeScript النظام دون تنزيل اعتماديات جديدة.
- Build78 runtime contract test: passed ضمن سلسلة الـvalidators، ويغطي النقاط الكسرية والاستثناء والمدفوعات وسياسة الجمعة وتعارض الاستئذان.
- Build78 APPLY يطابق migration المصدر byte-for-byte.
- `points.amount` هو العمود الذي يُحوّل إلى `NUMERIC(10,2)`؛ لا يوجد `ALTER COLUMN points` خاطئ.
- كل دوال `SECURITY DEFINER` الجديدة الثلاث في Build78 تثبت `search_path = public, pg_temp`.
- `DatabaseService`: **5197** سطرًا، تحت حاجز التجزئة 5200؛ استعلامات تقارير الفترة الجديدة موجودة في `ReportRangeDataService`.

## ما لم يُشغّل هنا

لا يوجد Flutter/Dart SDK في بيئة التحرير، لذلك **لم** يُشغّل هنا:

- `flutter analyze`
- `flutter test`
- `flutter run`

كما أن `npm ci --offline` لم يكتمل لأن cache المحلي لا يحتوي كل حزم `package-lock.json`، ومحاولة الوصول إلى registry ليست متاحة بصورة موثوقة؛ لذلك لا يُنسب إلى هذه البيئة نجاح Next full build/ESLint/audit.

آخر baseline Flutter مثبت من جهاز المالك قبل Build78 كان Build76 Hotfix1/Build77: `pub get` ناجح، analyzer بلا مشاكل، الاختبارات ناجحة، وAPK بُني. Build78 يحتاج إعادة هذه الاختبارات على جهاز المالك لأنه يغير Dart فعليًا.

## قبول Supabase المطلوب

نفّذ:

1. `website/supabase/P1.27_BUILD78_APPLY.sql`
2. `website/supabase/P1.27_BUILD78_VERIFY.sql`

ولا تعتبر المسابقات الإشرافية أو النقاط الكسرية السحابية مقبولة إنتاجيًا حتى تكون كل قيم `passed = true`.

## قبول وظيفي موصى به

- جهازان: offline → create/update/delete → reconnect.
- تقرير فترة فيه مدفوعات متعددة ومصروف صندوق غير مرتبط بالطالب.
- تصدير جماعي مع استثناء طالب ومستجد.
- طالب مستأذن ثم تسميع.
- عينة من الطلاب القدامى asc/desc بعد مصالحة المحفوظ.
- أوضاع الجمعة الثلاثة.
- جهة إشرافية + مركز مرتبط + analyst في مسابقة حقيقية.
- PDF ملخص الطالب على A4/A5 وطابعة فعلية.

## فحص التغليف التجريبي

قبل إنشاء البصمات النهائية تم إنشاء الحزمتين وفك اختبارهـما:

- full source: **727 ملفًا** بعد استبعاد الاعتماديات ومخرجات البناء والخطوط الثنائية والأسرار المحلية؛
- modified-files-only: **96 ملفًا** مقارنةً بـBuild77؛
- فرق Build78: **13 جديد + 83 معدل + 0 محذوف**؛
- `unzip -t`: ناجح للحزمتين؛
- الملفات الـ96 في الحزمة الجزئية: مطابقة byte-for-byte لنسخة العمل.

بعد تثبيت هذا التقرير أُعيد إنشاء ZIP النهائي واختباره مرة أخيرة قبل التسليم.

## Build 78 Hotfix 1 — 2026-08-16

أظهر اختبار جهاز المالك بعد Build78 ثمانية أخطاء analyzer/compile، رغم نجاح SQL VERIFY بالكامل. تم تصحيحها دون أي تغيير SQL/SQLite/dependency.

كما تم تشديد مسار المزامنة الذي ظهر فيه `ClientException: Software caused connection abort` على RPC `set_study_suspension`: preflight اتصال، timeout 12 ثانية، retry واحد، fingerprint للإجازات العارضة، ورسالة مستخدم منقحة.

بعد التصحيح: **67/67 release validators passed** في بيئة التحرير، بما فيها Build78 completion/runtime وvalidator Hotfix1. يبقى Flutter analyze/test/run مطلوبًا على جهاز المالك لأنه SDK غير موجود هنا.

## Build 78 Hotfix 2 — 2026-08-16

بعد مراجعة اختبار الهاتف وصورة فشل طباعة الخطة، ظهر سببان إضافيان:

- validator الـPDF كان يعامل جمعة `catchup_recitation` كيوم خطة كاملة، فيرفض نصوص «تدارك الفائت» رغم أن السرد نفسه محدد بسورة وآية؛ تم فصل سياسة التحقق لهذا اليوم.
- مزامنة الإجازات العارضة كانت قد تكرر RPC لكل التواريخ عند فقد fingerprint أو تغيره، ويمكن أن تتزامن يدويًا وتلقائيًا؛ أصبحت diff-based وأضيف تسلسل وحيد لعمليات sync.

تمت إضافة اختبارات وحدة لسياسة طباعة الجمعة وحساب فرق الإجازات العارضة، وvalidator مصدر لـHotfix 2. لا يوجد SQL/SQLite/dependency جديد. نجحت اختبارات المصدر المستهدفة: `validate-build78-hotfix1`, و`validate-build78-hotfix2`, و`validate-build78-completion`, و`test-build78-runtime`.

تشغيل السلسلة العامة `run-all-validations.mjs` من هذه الحزمة لا يصل إلى النهاية لأن حزمة full-source المرفوعة لا تحتوي `.vscode/settings.json` الذي يتطلبه validator أقدم (`validate-p1-16-plan-recitation.mjs`). كما أن فحص `tools/verify_source_prerequisites.sh` يوقف البناء كما هو متوقع لأن ملفي Tajawal الثابتين غير موجودين في حزمة `no-font-binaries`. بيئة التسليم الحالية لا تحتوي Flutter SDK، لذلك يبقى `flutter analyze/test/run` مطلوبًا على جهاز المالك بعد استعادة الخطين.

## Build 78 Hotfix 3 — 2026-08-16

بعد نجاح بناء Hotfix 2 على جهاز المالك بقيت المزامنة السحابية تفشل. أظهر تدقيق عقد العميل مع مخطط Supabase المرفق أن Flutter Hotfix 2 يستخدم conflict targets مركبة في `mushaf_progress` و`daily_achievements` بينما المخطط المرسل لا يثبت القيود الفريدة المقابلة. Hotfix 3 يزيل اعتماد الهاتف على هذه القيود حيث يوجد UUID ثابت، ويضيف SQL مستقلًا لإصلاح قيود الويب وسلامة البيانات دون حذف تلقائي لأي صف.

أضيف progress مرحلي ورمز تشخيص آمن، وأزيل probe الشبكة كل 12 ثانية لصالح foreground cadence وadaptive retry. كما أضيف cache لنطاق الطلاب وTTL لهوية الحلقة، ووحد حوار المزامنة بين الرئيسية والإعدادات.

في بيئة المراجعة نجح 66 من 69 validator في قائمة الإصدار. الثلاثة الباقية تتطلب حزمة `typescript` من `website/node_modules` غير الموجودة في المصدر المرفوع. Flutter/Dart SDK غير موجود هنا، لذلك يبقى `flutter analyze/test/run` مطلوبًا على جهاز المالك. التفاصيل في `BUILD78_HOTFIX3_VALIDATION_REPORT.md`.
