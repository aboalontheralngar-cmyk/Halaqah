# إصلاح تشغيل Android — 2026-07-18

## المعالج

- منع `RenderFlex overflow` في بطاقات الإشعارات عند طول عنوان الإشعار أو اسم الطالب.
- إضافة إذن `INTERNET` إلى `android/app/src/main/AndroidManifest.xml` لنسخ الإصدار.

## تشخيص `Failed host lookup`

الخطأ يحدث قبل الوصول إلى Supabase، أي أنه ليس خطأ RLS أو migration. يجرب على الهاتف:

1. فتح `https://mcckekgvwtqtpwtslwqf.supabase.co/auth/v1/health` في Chrome.
2. إيقاف VPN أو مانع الإعلانات أو Private DNS مؤقتًا، أو تعيين Private DNS على تلقائي.
3. التبديل بين Wi-Fi وبيانات الهاتف.
4. مقارنة Project URL في Supabase Dashboard مع الرابط المستخدم في `lib/services/supabase_service.dart`.
5. التأكد من أن مشروع Supabase غير متوقف أو معلق.

تبقى بيانات SQLite المحلية سليمة أثناء انقطاع DNS، وتعاد المزامنة بعد عودة الشبكة.
