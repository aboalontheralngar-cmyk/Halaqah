# Halaqah Features Implementation Walkthrough

This walkthrough details the design, technical details, and implementation of all advanced features built into the **Halaqah** Flutter application and the **Next.js** web application.

---

## 1. Configurable Center Fund Currency Symbol
*   **Web App**: Added the `currencySymbol` field to global settings in [useStore.ts](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/store/useStore.ts). A drop-down selection (e.g., ر.س, $, €, £, د.إ) has been integrated into the Settings page [settings/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/settings/page.tsx). The chosen symbol dynamically formats transaction cards and balances in the Center Fund view [fund/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/fund/page.tsx).
*   **Mobile App (Flutter)**: Added `currencySymbol` to the `Settings` model in [lib/models/settings.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/settings.dart), migrating database preferences. Updated the Settings screen [lib/screens/settings/settings_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/settings/settings_screen.dart) with a drop-down menu to pick the currency symbol globally. Applied this symbol dynamically across the Fund screen [lib/screens/fund/fund_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/fund/fund_screen.dart).

---

## 2. Memorization Direction
*   **Web App**: Added `memorizationDirection` (either `baqarah_to_nas` or `nas_to_baqarah`) to the `Student` interface. Implemented a drop-down selector in the Student addition/edit modal in [website/src/app/students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) to determine the memorization progress flow.
*   **Mobile App (Flutter)**: Upgraded SQLite Database to version 4 to include a `memorization_direction` column in the `students` table in [lib/services/database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart). Added the dropdown selection in [lib/screens/students/student_form_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_form_screen.dart).

---

## 3. Real-Time Memorization Statistics (Verses & Pages)
*   **Web App**: Formulated a `getStudentStats` utility in [website/src/app/students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) that retrieves a student's grades and maps the memorized verses/surahs against `quranService`. It returns:
    1. **إجمالي الآيات المسموعة**: The number of unique verses memorized.
    2. **الصفحات الفريدة**: The number of unique pages of the Quran that have been memorized (based on standard page boundaries in `quranService`).
*   **Mobile App (Flutter)**: Created helper methods (`getAllHomeworkGrades`, `getAllMushafProgress`, `getAllDailyRecords`) in [lib/services/database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart). Implemented dynamic calculations on the Student detail screen [lib/screens/students/student_detail_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_detail_screen.dart) to show the student's exact memorized verse and unique page statistics.

---

## 4. Beautiful Daily Report Image Card Generation & Sharing
*   **Web App**: Designed a premium card utilizing the HTML5 `<canvas>` API inside [website/src/app/memorization/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/memorization/page.tsx). It draws a beautifully styled card with a dark-teal gradient, gold calligraphy decoration, student information, recitation details, grade badge, mistakes count, and date. Teachers can share it directly or download it as a PNG image.
*   **Mobile App (Flutter)**: Implemented high-performance off-screen drawing using native Flutter `PictureRecorder` and `Canvas` APIs in [lib/screens/memorization/recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart). It compiles student data, draws custom text and gradients, saves the card to a temporary file, and triggers a system share panel to send the image directly to WhatsApp.

---

## 5. Supabase Cloud Sync & Authentication
*   **Supabase Client**: Configured and initialized the Supabase SDK in [lib/main.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/main.dart).
*   **Supabase Service**: Developed `SupabaseService` in [lib/services/supabase_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/supabase_service.dart) to perform two-way synchronization:
    *   Creates deterministic UUIDs for tables using MD5 hashes to prevent duplicate database rows.
    *   Synchronizes `students`, `daily_records`, and `homework_grades` bidirectionally.
    *   Tracks offline states and pushes pending updates to the cloud once connected.
    *   **Login Flow**: Built a premium login screen [lib/screens/auth/login_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/auth/login_screen.dart) for teachers.
    *   **AppBar Status & Sync Dialog**: Modified [lib/screens/home/home_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/home/home_screen.dart) to display dynamic indicators of cloud sync status in the header, letting teachers view authentication states and start manual synchronization sweeps.

---

## 6. Teacher Absence & Substitution Architecture Design
*   Documented a full system architecture proposal in [docs/teacher_absence_handling.md](file:///c:/Users/salman/Documents/flutter_App/Halaqah/docs/teacher_absence_handling.md).
*   It covers:
    1. **Absence Logging**: Teachers log a planned absence.
    2. **Substitution Requests**: The system prompts available substitutes or auto-assigns matching substitute teachers.
    3. **Substitute Temporary Access**: Configures a secure, read/write delegation session in Supabase, keeping student data isolated and audit-logged.
    4. **Smart Classroom Mode**: Fallback automated tasks and tests when no substitute is present.

---

---

## 8. Database Cleanliness & Abuse Prevention Rules (ضوابط حماية ونظافة قاعدة البيانات)
*   **حد المراكز الأقصى (Limit Centers Trigger)**: تم بناء Trigger سحابي آمن يمنع إنشاء أكثر من 4 مراكز كحد أقصى لكل مالك حساب.
*   **وظيفة تنظيف المراكز المهملة (Cleanup Empty Centers)**: تم بناء دالة `cleanup_empty_centers` تبحث عن المراكز التي مر عليها 10 أيام دون ربطها بحلقات وتقوم بحذفها.
*   **الجدولة اليومية للتنظيف**: تم جدولة تشغيل دالة التنظيف يومياً الساعة 12:00 بعد منتصف الليل باستخدام الامتداد القياسي `pg_cron`.

---

## 9. Mobile App Quality-of-Life Upgrades & Optimization (تحسينات واجهات وتجربة التسميع)

تم إنجاز جملة من التعديلات والتحسينات المهمة في هذه المرحلة لضمان مرونة وجودة تجربة الاستخدام واستقرار النظام:

1. **التحضير التلقائي الفوري (Auto-Attendance)**:
   * عند تسجيل التسميع (حفظ جديد، مراجعة، أو تسميع مباشر)، يقوم التطبيق تلقائياً بتحديث سجل حضور اليوم للطالب إلى `حاضر` وتسجيل وقت الوصول، مما يغني المعلم عن التحضير اليدوي المتكرر.
   * تم تفعيل هذا السلوك في جميع واجهات التسميع الثلاث:
     * واجهة التسميع المباشر [recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart)
     * واجهة تسجيل حفظ جديد [add_memorization_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/add_memorization_screen.dart)
     * واجهة تسجيل مراجعة [revision_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/revision_screen.dart)

2. **مؤقت التسميع الذكي والوقت المقترح**:
   * تم دمج مؤقت ذكي (Stopwatch) في واجهة التسميع المباشر يعرض الوقت المنقضي بوضوح مع إمكانية الإيقاف المؤقت والاستئناف.
   * يعرض المؤقت الوقت المقترح للتسميع تلقائياً استناداً إلى حجم المادة المقروءة (مثلاً صفحتين = 3-4 دقائق) ويتم حسابها بدقة باستخدام `QuranService` ثم إيقاف المؤقت تلقائياً عند حفظ التقرير.

3. **فرز الطلاب المرن**:
   * إضافة زر للفرز في شريط العنوان (AppBar) يتيح للمعلم إعادة ترتيب قائمة الطلاب إما **أبجدياً (حسب الاسم)** أو **حسب مقدار المحفوظ الكلي** لتسهيل الوصول والتنظيم في:
     * قائمة الطلاب الرئيسية [students_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/students_screen.dart)
     * قائمة اختيار الطلاب للتسميع [memorization_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/memorization_screen.dart)

4. **تحديد المحفوظ الأولي عند التسجيل**:
   * تم تحديث شاشة إضافة الطلاب [student_form_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_form_screen.dart) بإضافة شريط تمرير (Slider) لتحديد عدد الأجزاء التي يحفظها الطالب قبل دخوله الحلقة (من 0 إلى 30 جزء).
   * يقوم التطبيق تلقائياً بإنشاء وإدخال سجلات تقدم المصحف الأولي وتعليمها كـ "محفوظة مسبقاً" (`is_pre_memorized = 1`) في قاعدة البيانات عبر عملية دفعية واحدة (Batch transaction) سريعة.

5. **الربط العائلي الذكي ومقترحات الإخوة**:
   * عند إدخال اسم طالب جديد، يبحث التطبيق تلقائياً في قاعدة البيانات عن إخوته المشابهين في اللقب العائلي.
   * يقدم التطبيق بطاقة اقتراح تفاعلية، بمجرد الضغط عليها يتم إكمال الاسم الأخير للطالب تلقائياً وربط رقم هاتف ولي الأمر المشترك فوراً.

6. **إصلاح مشكلة الاختيار (Dropdown Bug) وتفعيل القيود**:
   * تم حل مشكلة عدم استجابة قائمة اختيار الطلاب وتكرارها عبر إعادة كتابة دوال المقارنة `operator ==` و `hashCode` لنموذج الطالب [student.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/student.dart).
   * تم تفعيل قيود SQLite الأجنبية `PRAGMA foreign_keys = ON;` لضمان الحذف المتتالي والنزاهة الهيكلية للبيانات.

7. **توحيد حساب الإحصائيات الدقيقة**:
   * تم التخلص من التقدير العشوائي لعدد الأسطر والصفحات في شاشة تسجيل الحفظ الجديد، وتوحيد الحسابات لتعمل على خوارزمية `QuranService` الدقيقة المعتمدة على رسم صفحات المصحف الفعلي.

8. **تبسيط التحضير وديناميكية التأخر**:
   * تم قصر التحضير على خيارين فقط: `حاضر` أو `غائب`؛ ويتم احتساب التأخر ديناميكياً مقارنة بوقت بدء الحلقة المخزن في الإعدادات، وكتابة `(متأخر)` تلقائياً بجانب حضور الطالب.

9. **دعم المساحات الآمنة (SafeArea)**:
   * تم تغليف جميع واجهات التطبيق الرئيسية بـ `SafeArea` لضمان عدم تداخل الأزرار أو النصوص مع الكاميرا الأمامية أو حواف الشاشات الحديثة (Notches).

10. **تحديد دقيق للمحفوظ المسبق بالسور والآيات**:
    * تم استبدال خيار تحديد المحفوظ الأولي بالسور ليشمل الآية من سورة البداية (والتي تبدأ افتراضياً من الآية 1 "أول السورة") والآية من سورة النهاية بشكل تفاعلي مرن.
    * تحديث دالة `initializeMushafProgressForRange` لتوليد نطاق المصحف الفعلي للأثمان والأحزاب المحفوظة مسبقاً بدقة متناهية بناءً على آية البداية والنهاية.

11. **حلول الـ Overflow (تداخل العناصر)**:
    * تم حل مشاكل الـ Overflow وتداخل نصوص القوائم المنسدلة في الشاشات الصغيرة عن طريق إضافة `overflow: TextOverflow.ellipsis` لكافة نصوص الـ `DropdownMenuItem` وتقصير نصوص الخيارات لاتجاه التقدم لتصبح أكثر تناسباً وجمالية.

---

## 12. Verification Results
*   **Web App**: Compiled successfully via `npm run build` with zero errors. All routes pre-rendered smoothly.
*   **Mobile App**: `flutter analyze` completed successfully with **zero errors**.

---

## 13. Mobile App Customization, Onboarding & Range Editing (الإصدار v1.2.0)

يقدم هذا الإصدار ترقيات نوعية متكاملة لزيادة مرونة التطبيق ومواءمته مع احتياجات المستخدم:

1. **تعديل المحفوظ المسبق للطلاب الحاليين (Edit Pre-memorized Range)**:
   * تم ترقية هيكلية قاعدة البيانات المحلية SQLite إلى الإصدار `5` وإضافة أربعة أعمدة جديدة لجدول الطلاب (`students`) لحفظ نطاق السور والآيات الأولي المختار بدقة.
   * إمكانية تعديل نطاق الحفظ المسبق من واجهة تعديل بيانات الطالب، ويقوم التطبيق تلقائياً بمسح تقدم المصحف المسبق القديم (`is_pre_memorized = 1`) وإعادة توليده بناءً على النطاق الجديد وتحديث إجمالي حفظ الطالب (`totalMemorized`) بدقة.

2. **معالج الإعداد الأولي والترحيب (Onboarding Setup Wizard)**:
   * تم إنشاء شاشة ترحيبية تفاعلية جذابة [setup_wizard_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/settings/setup_wizard_screen.dart) تظهر للمعلم عند فتح التطبيق للمرة الأولى لتسجيل اسم الحلقة، اسم المسجد، اسم المعلم، وقت الحلقة المعتاد، جنس الحلقة (بنين/بنات)، وتنسيق الوقت.
   * تم ربط الشاشة في [app.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/app/app.dart) للتحقق من إتمام التهيئة قبل الانتقال للشاشة الرئيسية.

3. **التكيف اللغوي التلقائي مع جنس الحلقة (Gender-Adaptive UI)**:
   * تم دمج الذكاء اللغوي في جميع الواجهات الرئيسية (الطلاب، وتفاصيل الطالب، وشاشة الحضور اليومي، والداشبورد) لتغيير العناوين والمخاطبة وحالات الحضور ديناميكياً لتناسب كون الحلقة مخصصة للبنين أو البنات (طالب/طالبة، حاضر/حاضرة، غائب/غائبة، مستأذن/مستأذنة، متبقي/متبقية، وصل/وصلت، متأخر/متأخرة).

4. **خيارات تنسيق الوقت المتعددة (Time Formatting Options)**:
   * تعميم صيغ الوقت وإتاحة الاختيار بين تنسيق 12 ساعة (ص/م) وتنسيق 24 ساعة والتنسيق التلقائي لنظام التشغيل في جميع شاشات وواجهات تحضير الطلاب.

5. **استيراد جهات الاتصال (Contacts Import)**:
   * دمج حزمة `flutter_contacts` وتعيين صلاحيات القراءة لـ Android و iOS لإظهار أيقونة استيراد بجانب حقول الجوال في نموذج الطالب لتعبئتها تلقائياً دون كتابة يدوية.

---

## 14. Dynamic & Seasonal Timings (Islamic Prayer-Relative Scheduling) (الإصدار v1.3.0)

هذا التحديث يحل مشكلة تغير التوقيت المستمر بين فصول السنة وصعوبة الضبط اليدوي للمعلمين:

1. **الجدولة الديناميكية المرتبطة بالصلوات (Prayer-Relative Scheduling)**:
   * تم دمج حزمة `adhan` للقيام بالحسابات الفلكية لمواقيت الصلاة اليومية بالاعتماد بالكامل على خطوط الطول والعرض والتقاويم المعتمدة، وبشكل مستقل تماماً عن الإنترنت (100% Offline).
   * ربط وقت بداية ونهاية الحلقة بصلوات اليوم الفعلية مع تحديد إزاحة بالدقائق (مثال: البدء بعد صلاة العصر بـ 15 دقيقة، أو بعد الفجر بـ 30 دقيقة).
   * توفير قاعدة بيانات جغرافية مدمجة للمدن العربية الكبرى مع تركيز شامل على مدن اليمن (صنعاء، عدن، تعز، المكلا، الحديدة، إب، سيئون، صعدة، عتق، دوعن، حجة) والمدن السعودية وتحديد تقويم أم القرى كأداة الحساب الرئيسية لجميع الدول لضمان دقة منتهية.
   * إمكانية تعيين خطوط الطول والعرض (Latitude & Longitude) مخصصة يدوياً.

2. **توقيت رمضان المبارك المخصص والتلقائي**:
   * الكشف التلقائي عن دخول شهر رمضان الكريم بناءً على التقويم الهجري (الشهر التاسع) أو التفعيل يدوياً.
   * إتاحة خيارات مخصصة لرمضان إما بعد الصلوات (مثل بعد صلاة الفجر، بعد صلاة العصر، إلخ) أو ساعات مخصصة محددة لرمضان أو استخدام نفس أوقات الأيام العادية.

3. **تتبع التأخير ديناميكياً وعرض وقت بدء اليوم**:
   * يعاد احتساب التأخر ديناميكياً بمقارنة وقت وصول الطالب مع وقت بدء الحلقة الفعلي المحسوب لليوم المحدد.
   * عرض وقت البدء المحسوب ومصدره بشكل تفاعلي وجميل أسفل محدد التاريخ في شاشة التحضير.

4. **تعديل وتحديث إجازات الطلاب**:
   * إضافة ميزة تعديل وتحديث بيانات الإجازات الحالية للطلاب (من تواريخ، أسباب، ملاحظات) عبر دمج زر تعديل تفاعلي في قائمة الإجازات يفتح نافذة التحديث ببياناتها المحملة.
