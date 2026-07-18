# تسليم المرحلة P6.3 — الإطلاق المرحلي

## المنفذ برمجيًا

- فحص اتصال Supabase من داخل الإعدادات دون مصادقة أو رفع أو تنزيل.
- تمييز DNS والمهلة وTLS وفشل الشبكة والخادم برسائل عربية وإرشادات عملية.
- دعم `SUPABASE_URL` و`SUPABASE_PUBLISHABLE_KEY` عبر `dart-define` مع إبقاء
  الإعداد الحالي افتراضيًا للتجربة المحلية.
- إضافة إذن الإنترنت إلى Android manifest الرئيسي، لا إلى debug/profile فقط.
- فصل بناء APK إلى `staging` و`production`.
- السماح بتوقيع debug للنسخة المرحلية الداخلية فقط.
- منع إنتاج APK احترافي دون keystore خاص وهوية تطبيق دائمة خارج `com.example`.
- فحص توقيع APK وإنشاء SHA-256 ورفع رموز فك التتبع للإصدار المموه.
- إضافة بناء APK debug إلى بوابة GitHub Actions العادية.
- رفع رقم النسخة إلى `4.1.0-alpha.1+41` واسم المشغل إلى «حلقتي».

## أسرار GitHub المطلوبة للإنتاج

تضاف من `Settings > Secrets and variables > Actions`:

- `ANDROID_APPLICATION_ID`
- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`
- `SUPABASE_URL`
- `SUPABASE_PUBLISHABLE_KEY`

لا ترفع keystore أو `key.properties` إلى المستودع. ملفا التجاهل يمنعان ذلك،
ويحذف سير البناء الملفات المؤقتة حتى عند الفشل.

## التشغيل

1. شغّل `Quality Gates` وتأكد من نجاح الويب وFlutter وبناء APK debug.
   على Windows يمكن تشغيل الدورة المحلية كاملة بأمر واحد:
   `PowerShell -ExecutionPolicy Bypass -File .\tools\staging_preflight.ps1`.
2. شغّل `Build APK Release` واختر `staging` لاختبارات الجهاز الداخلية.
3. اختبر الحضور والحفظ والمراجعة والرفع والتنزيل والطباعة على بيانات تجريبية.
4. نفّذ ملف التحقق للقراءة فقط
   `website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql`
   وتأكد أن كل صف يحمل `passed = true`.
   الإصدار الثاني يعد `RLS + REVOKE ALL + zero policies` نجاحًا مقصودًا لجداول
   أسرار البوابة، ولا يطالب بإنشاء سياسة وصول مباشر لها.
5. دوّن النتائج في `docs/phase6_3_acceptance_results.md`.
6. بعد اختيار هوية التطبيق الدائمة وإضافة أسرار التوقيع، اختر `production`.
7. احتفظ بملف APK وبصمة SHA-256 ورموز `build/symbols` ونسخة آمنة من keystore.

## اختبارات خارجية لا يمكن حسمها من المصدر وحده

- عزل RLS بين حسابين وحلقتين فعليتين.
- استعادة نسخة مشفرة على جهاز ثانٍ ومقارنة البيانات.
- الطباعة على A4 وA5 وكاشير 80 مم ومسح QR.
- التحقق من DNS وSupabase من شبكتي Wi-Fi وبيانات الهاتف.
- تثبيت APK الإنتاج كتحديث فوق النسخة المنشورة بعد تثبيت `applicationId` نفسه.

## SQL

لا يوجد SQL جديد لهذه المرحلة. تستعمل اختبارات Supabase migrations المراحل
السابقة بعد تنفيذها بالترتيب على مشروع مرحلي.
