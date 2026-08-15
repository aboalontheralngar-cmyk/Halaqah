# تسليم الإصلاح P1.16.2 — استعادة بيئة الويب على Windows

الإصدار: `4.3.0-alpha.6+56 (P1.16.2)`  
التاريخ: 2026-07-22

## نتيجة Supabase

الصورة المرفقة تؤكد أن فحوص P1.16 الأربعة نجحت:

- `plan_recitation_table = true`
- `plan_recitation_columns = true`
- `plan_recitation_rls = true`
- `plan_recitation_scope_trigger = true`

لا يوجد SQL جديد لهذه الدفعة.

## سبب أخطاء VS Code

رسالة `Cannot find module 'react'` هي الخطأ الأصلي. بقية رسائل JSX و`React namespace`
و`implicit any` تتولد بعدها لأن محرر TypeScript لا يرى `website/node_modules`.
هذه المجلدات لا تدخل حزمة المصدر، بل يعاد إنشاؤها من `package-lock.json`.

## الحل على Windows

1. فك حزمة المصدر كاملة في مجلد جديد.
2. أغلق VS Code.
3. انقر مرتين على:

```text
SETUP_WEB_WINDOWS.cmd
```

4. انتظر رسالة `Web setup completed successfully`.
5. افتح مجلد `Halaqah` مجددًا في VS Code.
6. إذا بقي تشخيص قديم، نفذ من `Ctrl+Shift+P` الأمر:

```text
TypeScript: Restart TS Server
```

7. لتشغيل الويب:

```powershell
cd website
npm run dev
```

ثم افتح `http://localhost:3000`.

## ما تتحقق منه الأداة

- React
- Next.js
- Lucide React
- تعريفات React
- خادم TypeScript الخاص بالمشروع
- ESLint
- فحوص العقود
- البناء الإنتاجي
