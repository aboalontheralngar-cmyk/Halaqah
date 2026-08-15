# تسليم الإصلاح P1.19.1 — استعادة بناء Flutter

الإصدار: `4.3.0-alpha.12+62 (P1.19.1)`  
التاريخ: 2026-07-27

## سبب فشل التجربة

لم يكن فشل `flutter run` ناتجًا عن Gradle أو عن وجود 57 حزمة أحدث. أوقف مترجم Dart البناء بسبب خطأين في مصدر P1.19:

1. تمرير المعامل `alignment` إلى `Center`، مع أن منشئ `Center` لا يدعمه.
2. استخدام `context` داخل `_buildDetailRow` في شاشة نتيجة الامتحان من دون أن تستقبله الدالة.

## الإصلاح

- استبدال `Center` بـ`Align` في `AppScreenBody` مع الإبقاء على `Alignment.topCenter`.
- إضافة `BuildContext context` إلى `_buildDetailRow` وتمريره في استدعاءات التاريخ ونوع الامتحان والنطاق.
- إضافة بوابة `validate-p1-19-1-flutter-build-hotfix.mjs` لمنع رجوع الخطأين.
- تحديث هوية نسخة التطوير وسجل الميزات.

## نتائج الفحص

- نجحت 47/47 بوابة إصدار.
- نجح ESLint بلا تحذيرات.
- نجح TypeScript.
- نجح بناء 31/31 مسارًا للويب.
- لا يوجد SQL أو migration جديد.
- لا يتوفر Flutter SDK داخل بيئة تجهيز الحزمة؛ لذلك يلزم تشغيل فحص Flutter وبناء Android على جهاز التطوير.

## طريقة التجربة على Windows

بعد استبدال المشروع بالحزمة المصححة، افتح PowerShell من جذر `Halaqah` وشغّل:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

رسالة `packages have newer versions incompatible with dependency constraints` معلوماتية ولا تمنع البناء؛ لا تستخدم `flutter pub upgrade --major-versions` ضمن هذا الإصلاح.

