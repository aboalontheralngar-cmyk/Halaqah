"use client";

import { useEffect } from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";
import "./globals.css";

export default function GlobalError({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  useEffect(() => {
    console.error("Unhandled root error", error.digest ?? error.name);
  }, [error]);

  return (
    <html lang="ar" dir="rtl">
      <body>
        <main className="flex min-h-screen items-center justify-center bg-gray-50 px-4 dark:bg-gray-950">
          <section className="w-full max-w-xl rounded-3xl border border-red-200 bg-white p-8 text-center shadow-sm dark:border-red-950 dark:bg-gray-900">
            <AlertTriangle className="mx-auto h-12 w-12 text-red-700 dark:text-red-300" aria-hidden="true" />
            <title>تعذر تشغيل حلقتي</title>
            <h1 className="mt-5 text-2xl font-black text-gray-950 dark:text-white">تعذر تشغيل الواجهة</h1>
            <p className="mt-3 text-sm leading-7 text-gray-600 dark:text-gray-300">
              حاول إعادة التشغيل. لن تؤدي إعادة المحاولة إلى حذف بيانات الحلقة.
            </p>
            <button
              type="button"
              onClick={() => unstable_retry()}
              className="mx-auto mt-6 flex items-center gap-2 rounded-2xl bg-teal-700 px-6 py-3 text-sm font-black text-white"
            >
              <RefreshCw className="h-4 w-4" aria-hidden="true" />
              إعادة التشغيل
            </button>
          </section>
        </main>
      </body>
    </html>
  );
}
