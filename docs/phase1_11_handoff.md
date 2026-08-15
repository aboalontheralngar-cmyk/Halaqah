# تسليم P1.11 — سلامة البيانات وقبول النسخة

التاريخ: 2026-07-21  
الإصدار: `4.2.0-alpha.7+49 (P1.11)`

## ما أُنجز

- فحص محلي للقراءة فقط داخل مركز التشخيص يغطي سبع قواعد للسلامة.
- فصل النتائج إلى حرجة وتحذيرات، مع تقرير دعم لا يتضمن بيانات شخصية.
- دعم اختيار APK بنمط `debug` أو `release` في سكربت القبول.
- فحص توقيع APK تلقائيًا عند توفر Android `apksigner`.
- حفظ APK وبصمة SHA-256 وتقرير قبول يحمل رقم الإصدار.
- قبول CSV فحص Supabase وإيقاف العملية عند أي نتيجة غير ناجحة.
- رفع بوابات المصدر إلى 36.

## قاعدة البيانات

لا يوجد SQL جديد. استخدم **محتوى** الملف التالي في SQL Editor، ولا تلصق اسم الملف:

`website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql`

الاستعلام للقراءة فقط. بعد نجاحه صدّر النتيجة بصيغة CSV.

## اختبار القبول على Windows

للاختبار السريع على جهاز Android:

```powershell
.\tools\staging_preflight.ps1 -Clean -ApkMode debug -SupabaseReadinessCsv "C:\path\readiness.csv"
```

للنسخة المرشحة الموقعة:

```powershell
.\tools\staging_preflight.ps1 -Clean -ApkMode release -SupabaseReadinessCsv "C:\path\readiness.csv"
```

ينشئ السكربت الملفات داخل `build\release-artifacts`. إذا لم يتوفر CSV بعد، احذف معامل `-SupabaseReadinessCsv` وستظهر الحالة `not-provided` في التقرير.

## ما يبقى قبل الإطلاق العام

- تثبيت النسخة على جهازين فعليين واختبار الرفع والتنزيل دون فقد المحفوظ.
- اختبار عزل حسابين ومركزين وبوابتي الطالب وولي الأمر.
- اختبار A4 وA5 والكاشير وQR على الطابعات الفعلية.
- نشر Edge Function واختبار حد محاولات الدخول والجلسات.
