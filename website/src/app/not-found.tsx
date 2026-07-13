import Link from "next/link";
import { Home, MapPinOff } from "lucide-react";

export default function NotFound() {
  return (
    <main className="flex min-h-[65vh] items-center justify-center px-4" dir="rtl">
      <section className="w-full max-w-xl rounded-3xl border border-gray-200 bg-white p-8 text-center shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <span className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-teal-50 text-teal-700 dark:bg-teal-950/40 dark:text-teal-300">
          <MapPinOff className="h-8 w-8" aria-hidden="true" />
        </span>
        <h1 className="mt-5 text-2xl font-black text-gray-950 dark:text-white">الصفحة غير موجودة</h1>
        <p className="mt-3 text-sm leading-7 text-gray-600 dark:text-gray-300">
          ربما تغيّر الرابط أو لم تعد الصفحة متاحة. يمكنك العودة إلى لوحة الحلقة بأمان.
        </p>
        <Link
          href="/"
          className="mx-auto mt-6 inline-flex items-center gap-2 rounded-2xl bg-teal-700 px-6 py-3 text-sm font-black text-white transition hover:bg-teal-800"
        >
          <Home className="h-4 w-4" aria-hidden="true" />
          العودة للرئيسية
        </Link>
      </section>
    </main>
  );
}
