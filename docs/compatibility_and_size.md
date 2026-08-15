# توافق الجوالات وحجم Android

## التوافق

الحد الأدنى الحالي Android 6.0 / API 23. السبب هو التخزين الآمن لعبارة تشفير النسخ. لا يعني ذلك ضمان الأداء على كل جهاز؛ يجب اختبار ذاكرة ومعالج وشركة مصنّعة فعلية.

مصفوفة القبول المقترحة:

| الفئة | النظام | الذاكرة | ما يُختبر |
|---|---:|---:|---|
| قديم منخفض | Android 6 أو 7 | 2 GB | بدء التطبيق، 100 طالب، حضور، تسميع، PDF |
| قديم متوسط | Android 8 أو 9 | 3 GB | QR، نسخ مشفر، تبادل ملف |
| متوسط | Android 11 أو 12 | 4 GB | مزامنة وتقارير ومسابقات |
| حديث | Android 14+ | 8 GB+ | صلاحيات، وضع داكن، تكبير النص |

## لماذا ظهرت 93 MB؟

`flutter run` ينشئ Debug يحوي دعم التصحيح وHot Reload، لذلك لا يمثل حجم التنزيل النهائي. تؤكد وثائق Flutter ذلك صراحة في [دليل قياس حجم التطبيق](https://docs.flutter.dev/perf/app-size).

## بناء خفيف

على Windows:

```powershell
.\tools\build_lean_android.ps1
```

ينتج APK منفصلًا لكل ABI، ويفعل:

- Release/AOT.
- R8 وتصغير موارد Android.
- Obfuscation مع `split-debug-info`.
- Tree shaking الافتراضي لأيقونات Flutter في Release.

احتفظ بمجلد `build/symbols` مطابقًا لكل إصدار؛ توضح [وثائق Flutter الرسمية](https://docs.flutter.dev/deployment/obfuscate) أنه ضروري لفك آثار الأعطال بعد التعتيم.

للنشر في Google Play يفضّل:

```powershell
flutter build appbundle --release --obfuscate --split-debug-info=build/symbols
```

المتجر يقسم AAB بحسب معمارية الهاتف وكثافة الشاشة. قِس الحجم من Play Console أو استخدم `flutter build apk --analyze-size` بدل مقارنة ملف Debug.

