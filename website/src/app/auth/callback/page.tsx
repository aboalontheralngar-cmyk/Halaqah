"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { Loader2 } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useStore } from "@/store/useStore";

export default function OAuthCallbackPage() {
  const router = useRouter();
  const [message, setMessage] = useState("جارٍ إكمال تسجيل الدخول الآمن...");

  useEffect(() => {
    let cancelled = false;

    const finish = async () => {
      if (!supabase) {
        router.replace("/login?oauth_error=configuration");
        return;
      }

      const url = new URL(window.location.href);
      const providerError = url.searchParams.get("error_description") || url.searchParams.get("error");
      if (providerError) {
        router.replace(`/login?oauth_error=${encodeURIComponent(providerError)}`);
        return;
      }

      const code = url.searchParams.get("code");
      if (!code) {
        router.replace("/login?oauth_error=missing_code");
        return;
      }

      const { data, error } = await supabase.auth.exchangeCodeForSession(code);
      if (cancelled) return;
      if (error || !data.session?.user) {
        setMessage("تعذر إكمال جلسة Google. ستعود إلى صفحة الدخول.");
        window.setTimeout(() => {
          router.replace(
            `/login?oauth_error=${encodeURIComponent(error?.message || "exchange_failed")}`,
          );
        }, 900);
        return;
      }

      // Persist the authenticated user in the app store before navigating.
      // A fresh Google account may not have a profile yet, so route it to
      // onboarding instead of showing the dashboard as an anonymous shell.
      useStore.setState({ user: data.session.user });
      await useStore.getState().fetchProfile();
      if (cancelled) return;
      router.replace(useStore.getState().profile ? "/select-center" : "/onboarding");
    };

    void finish();
    return () => {
      cancelled = true;
    };
  }, [router]);

  return (
    <main className="min-h-screen flex items-center justify-center bg-[var(--background)]" dir="rtl">
      <div className="rounded-3xl border border-black/10 bg-white/80 px-8 py-7 text-center shadow-sm dark:bg-white/5">
        <Loader2 className="mx-auto mb-4 h-9 w-9 animate-spin text-teal-700" />
        <p className="font-semibold text-slate-800 dark:text-slate-100">{message}</p>
      </div>
    </main>
  );
}
