# خطة تطوير ميزات الصندوق المالي، تقرير التسميع، واتجاه الحفظ، والربط السحابي

تهدف هذه الخطة إلى تفصيل تصميم وتطبيق التحديثات المطلوبة على الصندوق المالي (العملة المخصصة)، ومشاركة تقارير واتس كبطاقة مرئية، وتصميم منطق غياب المعلم، والتقرير الإحصائي لتقدم الحفظ، والتحكم باتجاه الحفظ (من الناس أو من البقرة)، بالإضافة إلى توضيح المعمارية المقترحة لربط تطبيق الأندرويد بالسحابة.

---

## User Review Required

> [!IMPORTANT]
> **1. ربط تطبيق الأندرويد بالسحابة (Supabase Cloud Link):**
> نقترح تفعيل معمارية سحابية هجينة (Offline-First Hybrid Sync):
> * سنستخدم مكتبة `supabase_flutter` في التطبيق.
> * سنحافظ على سرعة التطبيق ووضعه غير المتصل بالإنترنت باستخدام قاعدة بيانات SQLite المحلية كـ Cache، مع مزامنة دورية (Background Sync) في الخلفية عند توفر الإنترنت.
> * بديل مبسط: إضافة خيار "مزامنة سحابية يدوية" (Manual Backup & Restore) بضغطة زر داخل لوحة التحكم لرفع/تحميل البيانات السحابية لـ Supabase دون تعديل كامل معمارية التطبيق الحالية.
> **يرجى اختيار البديل المفضل للمتابعة.**

> [!TIP]
> **2. ميزة مشاركة صورة للواتس بتصميم جميل (Image Sharing):**
> * **في الويب:** سنقوم برسم بطاقة التقرير ديناميكيًا على عنصر `<canvas>` من HTML5 وتصديرها كصورة PNG قابلة للمشاركة أو التنزيل الفوري، لتفادي مشاكل المكتبات الخارجية الكبيرة.
> * **في الموبايل:** سنستخدم ودجت `RepaintBoundary` المدمجة في Flutter لالتقاط بطاقة التقرير كصورة وحفظها في مجلد مؤقت ثم مشاركتها عبر `share_plus`.

> [!WARNING]
> **3. غياب المعلم دون بديل (Teacher Absence Log):**
> نقترح تصميم الميزة بالشكل التالي:
> * يستطيع **مدير المركز** تحديد "حالة غياب" للحلقة وتعيين معلم بديل (Substitute) مؤقتًا بضغطة زر لرؤية وإدخال تحضير الطلاب.
> * في حال عدم الحضور بعد بدء الحلقة بـ 15 دقيقة، تظهر لوحة إشعار لمدير المركز تخبره بأن "الحلقة X بدون معلم حاليًا" وتتيح له استلام التحضير وتسميع الطلاب بنفسه كبديل تلقائي.

---

## Proposed Changes

### 1. الصندوق المالي بعملة عالمية مخصصة 🪙

#### [MODIFY] [database_schema_extensions.sql](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/database_schema_extensions.sql)
* إضافة عمود `currency_symbol TEXT DEFAULT 'ر.س'` إلى جدول `center_settings`.

#### [MODIFY] [useStore.ts](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/store/useStore.ts)
* تحديث إعدادات المركز لتشمل `currencySymbol` ومزامنتها مع Supabase.

#### [MODIFY] [page.tsx (fund)](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/fund/page.tsx)
* استبدال رمز العملة الثابت `ر.س` بمتغير العملة الديناميكي المأخوذ من إعدادات المركز.

#### [MODIFY] [settings_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/settings/settings_screen.dart) & [settings.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/settings.dart) & [fund_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/fund/fund_screen.dart)
* إضافة خيار "رمز العملة" في الإعدادات الموبيلية وحفظه محليًا، وتحديث شاشة الصندوق المالي لعرض العملة المحددة.

---

### 2. اتجاه الحفظ لكل طالب (من الناس أو من البقرة) 🧭

#### [MODIFY] [students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) & [useStore.ts](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/store/useStore.ts)
* إضافة حقل `memorizationDirection` (desc / asc) في نموذج الطالب وواجهة الإضافة/التعديل لتمكين الاختيار بين "من الناس إلى البقرة" (افتراضي) أو "من البقرة إلى الناس".

#### [MODIFY] [student.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/student.dart) & [student_form_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_form_screen.dart)
* إضافة الحقل لنموذج الطالب في تطبيق الموبايل وترقية قاعدة بيانات SQLite لإضافة العمود `memorization_direction` على جدول `students` عند ترقية الإصدار إلى 4.

---

### 3. إحصائيات التسميع التفصيلية (الصفحات والآيات المحفوظة) 📊

#### [MODIFY] [students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) & [student_detail_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_detail_screen.dart)
* حساب وعرض إجمالي الصفحات الفريدة التي حفظها الطالب ديناميكيًا من خلال مقارنة آيات التسميع المسجلة مع بيانات صفحات المصحف المخزنة in `quran_data.json` وعرضها كبطاقة إحصائية بجانب عدد الآيات.

---

### 4. مشاركة صور التقارير بتصميم جميل (Image Cards) 🎨

#### [NEW] [website/src/components/ReportImageGenerator.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/components/ReportImageGenerator.tsx)
* مكون لرسم بطاقة تقييم ملونة (تقييم ممتاز/جيد، عدد الأخطاء، السورة، الملاحظات) على عنصر `<canvas>` وتنزيلها كملف صورة ومشاركتها عبر الواتس.

#### [MODIFY] [recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart) & [student_detail_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_detail_screen.dart)
* إضافة زر "مشاركة بطاقة التقرير كصورة" ورسمها باستخدام `RepaintBoundary` وحفظها مؤقتاً لمشاركتها مع ولي الأمر.

---

## Verification Plan

### Automated Tests
* لا توجد اختبارات مؤتمتة، التحقق سيكون يدويًا.

### Manual Verification
1. التأكد من إمكانية تغيير العملة في إعدادات الموقع وتطبيق الموبايل، والتحقق من ظهور العملة الجديدة في الصندوق المالي.
2. إضافة طالب واختيار اتجاه حفظه والتحقق من بقائه وتحديثه بشكل سليم.
3. تجربة إنشاء تقرير كصورة ومشاركته عبر الواتس والتأكد من وضوح التصميم وتطابقه مع البيانات المدخلة.
4. تجميع المشروع محلياً والتحقق من خلوه من أي مشاكل برمجية.
