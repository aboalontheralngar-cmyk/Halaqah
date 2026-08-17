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

### أخطاء React وJSX داخل VS Code على Windows

حزم `node_modules` لا تدخل ضمن حزمة المصدر لأنها قابلة لإعادة البناء وكبيرة
الحجم. لذلك يجب بعد فك الحزمة تشغيل هذا الأمر من جذر المشروع:

```powershell
PowerShell -ExecutionPolicy Bypass -File .\tools\setup_web.ps1
```

والطريقة الأسهل هي النقر مرتين على `SETUP_WEB_WINDOWS.cmd` في جذر المشروع.
تفحص الأداة وجود React وNext.js وLucide وتعريفات React وخادم TypeScript بعد
التثبيت، وتدعم فتح مجلد المشروع كاملًا أو فتح `website` وحده في VS Code.

إذا بقيت العلامات الحمراء بعد نجاحه، افتح لوحة أوامر VS Code وشغّل
`TypeScript: Restart TS Server`. لا تعدّل `DashboardLayout.tsx` لإسكات هذه
الأخطاء؛ أخطاء `react` و`next/navigation` و`lucide-react` وJSX في هذه الحالة
تعني أن الاعتمادات لم تُحمّل، وليست أخطاء في المكوّن.

## فحوص الإصدار

```bash
npm run quality:ci
```

ينفذ الأمر تدقيق الثغرات الإنتاجية عالية الخطورة، وحد ESLint بصفر تحذيرات،
وفحوص العقود الـ61، وبناء Next.js الإنتاجي.

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
- قاعدة المالك اجتازت Build 76 APPLY/VERIFY بنجاح. **Build 77 لا يضيف SQL جديدًا**؛ لا تعاود Build 76 APPLY ولا Build75/P7.3 بسبب هذه الدفعة.
- نفّذ migration P1.7 قبل حفظ جلسة تسميع ويب تعبر أكثر من سورة؛ انسخ محتوى الملف لا اسمه.
- Build 74 يعيد مصالحة عقد `supervision_visits` المطلوب للزيارات؛ P1.20 يبقى مطلوبًا فقط لبيئة جديدة لم تمر بالمراحل السابقة.
- نفّذ migration P1.21 ثم أعد نشر `student-portal` قبل تفعيل تقارير ولي الأمر الدورية.
- انشر `guardian-report-worker` واضبط `GUARDIAN_REPORT_WORKER_SECRET` وجدولة محمية كل 15 دقيقة. إعداد `GUARDIAN_REPORT_WEBHOOK_URL` و`GUARDIAN_REPORT_WEBHOOK_SECRET` مطلوب فقط للإرسال الخارجي.
- عرّف `PORTAL_RATE_LIMIT_PEPPER` بقيمة عشوائية طويلة داخل أسرار Edge Functions، وقيّد `PORTAL_ALLOWED_ORIGINS` بعنوان الموقع المنشور.
- عرّف المتغيرات العامة أثناء البناء؛ قيم `NEXT_PUBLIC_` تثبت داخل الحزمة.
- لا تتجاوز فشل `quality:ci` ولا تستخدم `npm audit fix --force` دون مراجعة.
- راجع `docs/phase6_1_handoff.md` و`docs/phase6_2_handoff.md` و`docs/release_security_checklist.md` قبل الإنتاج.

## Google OAuth production callback

Build 83 uses the PKCE flow and a dedicated `/auth/callback` page so access and
refresh tokens are not carried in the URL fragment.

For production:

1. Set `NEXT_PUBLIC_APP_URL=https://YOUR_PUBLIC_APP_DOMAIN` before `npm run build`.
2. In Supabase **Authentication -> URL Configuration**, set **Site URL** to the
   same production origin (never `http://localhost:3000` in production).
3. Add `https://YOUR_PUBLIC_APP_DOMAIN/auth/callback` to **Redirect URLs**.
4. In Google Auth Platform, keep the Supabase Auth callback URL shown by the
   Google provider screen in **Authorized redirect URIs**. This is different
   from the frontend `/auth/callback` URL above.
5. Configure Google Auth Platform **Branding** (app name, logo, support email,
   homepage, privacy policy and terms). A Supabase custom/vanity domain is
   needed if you also want the consent screen to stop showing the random
   `<project-ref>.supabase.co` hostname.

Never commit or send the Google Client Secret JSON. Only the public Web Client
ID may safely be exposed to browser code when needed.
