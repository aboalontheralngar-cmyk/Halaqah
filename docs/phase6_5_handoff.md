# تسليم المرحلة P6.5 — سلامة الحزم وقبول RC2

## النتيجة

- يمكن التحقق من أي ZIP أو APK وملف `.sha256` بأمر PowerShell واحد.
- يرفض الفاحص ملف بصمة لا يخص اسم الحزمة المحددة.
- يوقف الفاحص العملية عند اختلاف SHA-256 ويحذر من الفك أو التثبيت.
- يحفظ `staging_preflight.ps1` نسخة APK باسم الإصدار داخل
  `build/release-artifacts` وينشئ ملف بصمته بجواره.
- لا تستبدل ملفات `.sha256` أي ملف في المصدر؛ تحفظ مع أرشيف الإصدار فقط.

## الأوامر

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\verify_release_checksum.ps1 `
  -ArchivePath .\release.zip
```

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1 -Clean
```

بعد نجاح الفحص الثاني توجد الحزمة وبصمتها في `build\release-artifacts`.

## SQL

لا يوجد SQL جديد لهذه المرحلة.
