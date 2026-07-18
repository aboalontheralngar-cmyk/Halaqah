# حلقتي — واجهة الويب

لوحة إدارة حلقات القرآن المبنية بـ Next.js وSupabase. المصدر العام للمتصفح
يستخدم مفتاح Supabase العام فقط، وتعتمد حماية البيانات الفعلية على سياسات RLS
الموجودة في `supabase/migrations`.

## التشغيل المحلي

1. انسخ `.env.example` إلى `.env.local`.
2. ضع رابط مشروع Supabase والمفتاح العام `anon` أو `publishable`.
3. لا تضع مفتاح `service_role` في أي متغير يبدأ بـ `NEXT_PUBLIC_`.
4. نفذ:

```bash
npm ci
npm run dev
```

ثم افتح `http://localhost:3000`.

## فحوص الإصدار

```bash
npm run quality:ci
```

ينفذ الأمر تدقيق الثغرات الإنتاجية عالية الخطورة، وحد ESLint المتناقص،
وفحوص العقود الـ25، وفحص TypeScript، وبناء Next.js الإنتاجي.

أوامر مفيدة:

```bash
npm run lint:strict
npm run validate:all
npm run audit:production
npm run build
```

## الأمان والنشر

- لا تنشر إلا عبر HTTPS.
- شغّل migrations بالترتيب واختبر RLS بحسابين من حلقتين مختلفتين.
- نفّذ migration P6.2 قبل فتح `/audit-log` أو تفعيل النسخ السحابي في Android.
- نفّذ migration بوابة الطالب ثم انشر `supabase/functions/student-portal` قبل فتح `/portal` للمستخدمين.
- نفّذ migration P7.2.1 ثم أعد نشر Edge Function قبل تفعيل حساب ولي الأمر متعدد الأبناء.
- نفّذ migration P7.3 قبل فتح `/supervision` أو إصدار دعوات ربط المراكز والفريق.
- عرّف `PORTAL_RATE_LIMIT_PEPPER` بقيمة عشوائية طويلة داخل أسرار Edge Functions، وقيّد `PORTAL_ALLOWED_ORIGINS` بعنوان الموقع المنشور.
- عرّف المتغيرات العامة أثناء البناء؛ قيم `NEXT_PUBLIC_` تثبت داخل الحزمة.
- لا تتجاوز فشل `quality:ci` ولا تستخدم `npm audit fix --force` دون مراجعة.
- راجع `docs/phase6_1_handoff.md` و`docs/phase6_2_handoff.md` و`docs/release_security_checklist.md` قبل الإنتاج.
