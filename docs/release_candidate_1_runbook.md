# دليل قبول Release Candidate 2

هذه أقصر دورة آمنة للوصول إلى نسخة اختبار فعلية دون تجاوز حماية البيانات.

## 1. تحديث المصدر

تحقق أولًا من الحزمة وملف بصمتها كما هو موضح في
`docs/release_checksum_guide_ar.md`، ثم فك حزمة RC2 في جذر المشروع مع المحافظة
على المجلدات وافتح PowerShell من جذر `Halaqah`.

## 2. فحص قاعدة البيانات

نفّذ محتوى الملف التالي كاملًا في استعلام جديد داخل Supabase:

`website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql`

الملف للقراءة فقط. يجب أن يظهر جدول نتائج واحد وكل قيمة `passed` فيه `true`.
مجموعة `deny-all` صحيحة عندما تكون التفاصيل مثل:

`rls=true policies=0 anon_direct=false authenticated_direct=false`

لا تنشئ Policies لجداول PIN والجلسات؛ وصولها المباشر مغلق عمدًا.

## 3. بناء RC2 بأمر واحد

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1
```

إذا كان الوقت ضيقًا جدًا وأُنجز فحص الويب في الحزمة نفسها:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1 -SkipWeb
```

ولإجبار تنظيف Flutter قبل الفحص:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1 -Clean
```

يتوقف السكربت عند أول فشل. عند النجاح يحفظ APK وملف `.sha256` الخاص به في
`build\release-artifacts` ويطبع مساريهما.

## 4. اختبار الجهاز

ثبّت `build/app/outputs/flutter-apk/app-release.apk` على جهاز الاختبار، ثم:

1. افتح الإعدادات > البيانات > فحص اتصال Supabase.
2. أنشئ نسخة احتياطية محلية مشفرة.
3. اختبر الرفع فقط قبل أي تنزيل.
4. سجّل حضورًا وحفظًا ومراجعة لطالب تجريبي.
5. صدّر تقرير A4 وافحص QR واتجاه العربية.
6. دوّن النتيجة في `docs/phase6_3_acceptance_results.md`.

## 5. ما يمنع الإصدار العام فقط

- اختيار `applicationId` دائم غير `com.example`.
- إنشاء keystore إنتاج وحفظه خارج المستودع.
- إضافة أسرار GitHub المذكورة في `docs/phase6_3_handoff.md`.
- نجاح اختبار العزل بحسابين والاستعادة على جهاز ثانٍ والطابعة الفعلية.

هذه الموانع لا تمنع RC2 الداخلي، لكنها تمنع توزيع نسخة production للعامة.
