"use client";

import { useEffect } from "react";
import { AlertTriangle, RefreshCw } from "lucide-react";

export default function ErrorPage({
  error,
  unstable_retry,
}: {
  error: Error & { digest?: string };
  unstable_retry: () => void;
}) {
  useEffect(() => {
    console.error("Unhandled application error", error.digest ?? error.name);
  }, [error]);

  return (
    <main className="flex min-h-[60vh] items-center justify-center px-4" dir="rtl">
      <section className="w-full max-w-xl rounded-3xl border border-red-200 bg-white p-8 text-center shadow-sm dark:border-red-950 dark:bg-gray-900">
        <span className="mx-auto flex h-16 w-16 items-center justify-center rounded-3xl bg-red-50 text-red-700 dark:bg-red-950/40 dark:text-red-300">
          <AlertTriangle className="h-8 w-8" aria-hidden="true" />
        </span>
        <h1 className="mt-5 text-2xl font-black text-gray-950 dark:text-white">حدث خطأ غير متوقع</h1>
        <p className="mt-3 text-sm leading-7 text-gray-600 dark:text-gray-300">
          بياناتك المحفوظة لم تُحذف. حاول إعادة تحميل هذا الجزء، وإن تكرر الخطأ فاحتفظ برمز التتبع وأرسله للدعم.
        </p>
        {error.digest && (
          <p className="mt-3 font-mono text-xs text-gray-400">رمز التتبع: {error.digest}</p>
        )}
        <button
          type="button"
          onClick={() => unstable_retry()}
          className="mx-auto mt-6 flex items-center gap-2 rounded-2xl bg-teal-700 px-6 py-3 text-sm font-black text-white transition hover:bg-teal-800"
        >
          <RefreshCw className="h-4 w-4" aria-hidden="true" />
          إعادة المحاولة
        </button>
      </section>
    </main>
  );
}
