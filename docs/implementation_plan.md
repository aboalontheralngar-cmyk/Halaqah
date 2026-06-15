# تنفيذ ميزات Halaqat في مشروع Halaqah

## الهدف
إضافة 5 ميزات متقدمة مستوحاة من مشروع Halaqat إلى تطبيق Halaqah Flutter، مع الحفاظ على خفة التطبيق والأداء الحالي.

## User Review Required

> [!IMPORTANT]
> الميزات مرتبة بالأولوية. هل تريد تنفيذ الكل أم البدء بميزات محددة؟

> [!WARNING]
> التطبيق سيحتاج ترقية قاعدة البيانات من version 2 → 3. هذا آمن للبيانات الموجودة بفضل نظام `onUpgrade`.

## Open Questions

1. **تقارير Excel**: هل تفضل CSV خفيف (بدون مكتبات إضافية) أم Excel حقيقي (يحتاج مكتبة `excel` ~200KB)؟
2. **قوالب الرسائل**: هل تريد فتح واتساب مباشرة أم مشاركة عبر نظام المشاركة العام؟

---

## الحالة الحالية للمشروع

| الملف | الوظيفة | الحالة |
|---|---|---|
| [memorization.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/memorization.dart) | نموذج الحفظ | ✅ موجود (بسيط - `quality_rating: int`) |
| [recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart) | شاشة التسميع | ✅ موجودة (تحتاج تحسين التقييم) |
| [quran_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/quran_service.dart) | خدمة القرآن | ✅ موجودة (بيانات السور + الأجزاء) |
| [database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart) | قاعدة البيانات | ✅ v2 (تحتاج ترقية لـ v3) |

---

## Proposed Changes

### المرحلة 1: تحسين نظام التسميع + نموذج الواجبات 🔴

الحفظ والتسميع موجودان فعلاً. سنحسّنهما بإضافة نظام تقييم 5 مستويات (مثل Halaqat) + حقل عدد الأخطاء.

---

#### [MODIFY] [database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart)
- ترقية من `version: 2` → `version: 3`
- إضافة جداول جديدة في `_createVersion3Tables`:
  - `homework_grades` — حقل `grade_mark` (Excellent/VeryGood/Good/NeedsWork/Absent) + `mistakes_count`
  - `mushaf_progress` — تتبع تقدم الحفظ بالأثمان (480 صف محتمل)
  - `message_templates` — قوالب الرسائل
- إضافة CRUD methods للجداول الجديدة

#### [NEW] `lib/models/homework_grade.dart`
- نموذج `HomeworkGrade`:
  ```dart
  {id, studentId, date, startSurah, startAyah, endSurah, endAyah, 
   gradeMark: 'excellent'|'very_good'|'good'|'needs_work'|'absent',
   mistakesCount: int, isRevision: bool, remark: String?}
  ```

#### [MODIFY] [recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart)
- إضافة واجهة اختيار تقييم 5 مستويات بدلاً من `quality_rating` الرقمي
- إضافة حقل "عدد الأخطاء" مع عداد +/-
- إضافة حقل "ملاحظات" نصي
- أزرار ملونة لكل مستوى تقييم

---

### المرحلة 2: خريطة المصحف المرئية (Mushaf Visualizer) 🟠

ميزة بصرية مميزة: شبكة 60 حزب × 8 أثمان تعرض تقدم الطالب.

---

#### [NEW] `lib/models/mushaf_progress.dart`
- نموذج `MushafProgress`:
  ```dart
  {id, studentId, hizbNumber: 1-60, thumunNumber: 1-8, 
   averageGrade: double, lastGradedDate: DateTime?,
   isPreMemorized: bool}
  ```
- `DecayStatus` enum: `fresh` (<14 يوم), `aging` (14-30 يوم), `stale` (>30 يوم), `notStarted`

#### [NEW] `lib/services/mushaf_service.dart`
- `MushafService`:
  - بيانات تقسيمات القرآن الـ 480 ثُمن (hardcoded كـ const list)
  - `getHizbProgress(studentId)` → `List<HizbProgressVM>`
  - `updateProgressAfterGrading(homeworkGradeId)`
  - حساب `DecayStatus` من `lastGradedDate`

#### [NEW] `lib/screens/memorization/mushaf_visualizer_screen.dart`
- شاشة خريطة المصحف:
  - `GridView` 60 صف × 8 أعمدة (خلايا صغيرة ملونة)
  - ألوان: أخضر (fresh) / أصفر (aging) / أحمر (stale) / رمادي (notStarted)
  - BottomSheet عند الضغط على خلية يعرض تفاصيل الحزب/الثُمن
  - Header يعرض إحصائيات (% محفوظ، عدد الأحزاب، حالة المراجعة)

#### [MODIFY] [student_memorization_view.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/student_memorization_view.dart)
- إضافة زر "خريطة المصحف" في شاشة عرض محفوظات الطالب

---

### المرحلة 3: تقارير مشاركة (CSV/Share) 🟠

تقارير خفيفة بصيغة CSV (بدون مكتبات ثقيلة) قابلة للمشاركة.

---

#### [NEW] `lib/services/report_export_service.dart`
- `ReportExportService`:
  - `exportStudentReport(studentId)` → ملف CSV بسجل كامل
  - `exportCircleReport()` → ملف CSV لجميع الطلاب
  - `shareReport(filePath)` → مشاركة عبر `Share` API
  - دعم RTL: UTF-8 BOM + ترتيب الأعمدة من اليمين

#### [MODIFY] [reports_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/reports/reports_screen.dart)
- إضافة زر "تصدير تقرير Excel" في صفحة التقارير
- إضافة خيار مشاركة التقرير عبر واتساب

---

### المرحلة 4: قوالب رسائل واتساب 🟡

---

#### [NEW] `lib/models/message_template.dart`
- `MessageTemplate`:
  ```dart
  {type: 'assignment'|'grading', content: String}
  ```
- متغيرات ديناميكية: `{اسم_الطالب}`, `{السورة}`, `{التقييم}`, `{التاريخ}`

#### [NEW] `lib/screens/settings/message_templates_screen.dart`
- شاشة تحرير قوالب الرسائل (جزء من الإعدادات)
- قالب افتراضي للواجب: "السلام عليكم، واجب {اسم_الطالب} اليوم: حفظ من سورة {السورة} آية {من} إلى {إلى}"
- قالب افتراضي للتقييم: "السلام عليكم، تقييم {اسم_الطالب}: {التقييم}، الأخطاء: {عدد_الأخطاء}"

#### [MODIFY] [recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart)
- إضافة زر "إرسال لولي الأمر" بعد حفظ التقييم → يفتح واتساب/مشاركة

---

### المرحلة 5: تصدير/استيراد بيانات الحلقة JSON 🟡

---

#### [NEW] `lib/services/data_exchange_service.dart`
- `DataExchangeService`:
  - `exportCircle()` → JSON كامل (طلاب + واجبات + تقييمات)
  - `importCircle(jsonPath)` → استيراد من ملف JSON
  - تحقق من صحة البيانات المستوردة

#### [MODIFY] [settings_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/settings/settings_screen.dart)
- إضافة قسم "تصدير واستيراد":
  - زر "تصدير بيانات الحلقة" (JSON)
  - زر "استيراد حلقة" (اختيار ملف JSON)

---

## ملخص الملفات

| الملف | العملية | المرحلة |
|---|---|---|
| `lib/models/homework_grade.dart` | [NEW] | 1 |
| `lib/models/mushaf_progress.dart` | [NEW] | 2 |
| `lib/models/message_template.dart` | [NEW] | 4 |
| `lib/services/database_service.dart` | [MODIFY] | 1 |
| `lib/services/mushaf_service.dart` | [NEW] | 2 |
| `lib/services/report_export_service.dart` | [NEW] | 3 |
| `lib/services/data_exchange_service.dart` | [NEW] | 5 |
| `lib/screens/memorization/recitation_screen.dart` | [MODIFY] | 1, 4 |
| `lib/screens/memorization/mushaf_visualizer_screen.dart` | [NEW] | 2 |
| `lib/screens/memorization/student_memorization_view.dart` | [MODIFY] | 2 |
| `lib/screens/reports/reports_screen.dart` | [MODIFY] | 3 |
| `lib/screens/settings/settings_screen.dart` | [MODIFY] | 5 |
| `lib/screens/settings/message_templates_screen.dart` | [NEW] | 4 |
| `lib/screens/home/home_screen.dart` | [MODIFY] | 4 |

---

## Verification Plan

### Automated Tests
```bash
cd c:\Users\salman\Documents\flutter_App\Halaqah
flutter build apk --debug
```

### Manual Verification
- تشغيل على الجهاز والتحقق من:
  1. التسميع: تقييم طالب بكل مستوى والتأكد من حفظه
  2. خريطة المصحف: ظهور الخلايا الملونة بعد التقييم
  3. التقارير: تصدير CSV ومشاركته
  4. الرسائل: إرسال قالب لولي الأمر
  5. التصدير/الاستيراد: تصدير واستيراد بيانات
