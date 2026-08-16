"use client";

import { useEffect, useState } from "react";
import { useShallow } from "zustand/react/shallow";
import { useRouter } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { 
  Mail, 
  Lock, 
  ArrowRight, 
  BookOpen, 
  Loader2,
  Eye,
  EyeOff
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase, supabaseConfiguration } from "@/lib/supabase";

export default function AuthPage() {
  const router = useRouter();
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const [configurationError, setConfigurationError] = useState("");
  const {
    setUser
  } = useStore(
    useShallow((state) => ({
      setUser: state.setUser,
    })),
  );

  const [formData, setFormData] = useState({
    email: "",
    password: "",
    confirmPassword: ""
  });

  useEffect(() => {
    if (!supabase) return;

    const finishOAuthLogin = (user: User) => {
      setUser(user);
      router.replace("/select-center");
    };

    void supabase.auth.getSession().then(({ data }) => {
      if (data.session?.user) finishOAuthLogin(data.session.user);
    });

    const { data: authListener } = supabase.auth.onAuthStateChange((_event, session) => {
      if (session?.user) finishOAuthLogin(session.user);
    });

    return () => authListener.subscription.unsubscribe();
  }, [router, setUser]);

  const handleGoogleLogin = async () => {
    if (!supabase) {
      setConfigurationError(
        "تسجيل الدخول غير متاح لأن إعدادات Supabase العامة غير مكتملة. راجع مسؤول النشر.",
      );
      return;
    }
    setLoading(true);
    try {
      const { error } = await supabase.auth.signInWithOAuth({
        provider: "google",
        options: {
          redirectTo: `${window.location.origin}/login?oauth=google`,
        },
      });
      if (error) throw error;
    } catch (error: unknown) {
      alert(error instanceof Error ? error.message : "تعذر تسجيل الدخول باستخدام Google");
      setLoading(false);
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isLogin && formData.password !== formData.confirmPassword) {
      alert("كلمات المرور غير متطابقة!");
      return;
    }

    setLoading(true);
    
    if (!supabase) {
      setConfigurationError(
        "تسجيل الدخول غير متاح لأن إعدادات Supabase العامة غير مكتملة. راجع مسؤول النشر.",
      );
      setLoading(false);
      return;
    }

    try {
      if (isLogin) {
        const { data, error } = await supabase.auth.signInWithPassword({
          email: formData.email,
          password: formData.password,
        });
        if (error) throw error;
        setUser(data.user);
        router.push("/select-center");
      } else {
        // Sign Up
        const { data: authData, error: authError } = await supabase.auth.signUp({
          email: formData.email,
          password: formData.password,
        });
        if (authError) throw authError;
        
        if (authData.user) {
          setUser(authData.user);
          router.push("/onboarding");
        }
      }
    } catch (error: unknown) {
      alert(error instanceof Error ? error.message : "حدث خطأ أثناء المصادقة");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-[var(--background)] flex flex-col lg:flex-row transition-colors duration-500" dir="rtl">
      {/* Visual Side */}
      <div className="lg:w-1/2 relative overflow-hidden bg-teal-900 hidden lg:flex flex-col justify-center p-20 text-white">
        <div className="absolute inset-0 bg-[radial-gradient(circle_at_20%_20%,rgba(255,255,255,0.12),transparent_28%),radial-gradient(circle_at_80%_70%,rgba(45,212,191,0.16),transparent_32%)]" />
        <div className="absolute top-0 right-0 w-full h-full bg-gradient-to-br from-teal-500/20 to-transparent" />
        
        <div className="relative z-10 space-y-8">
          <div className="w-20 h-20 bg-white/10 rounded-3xl flex items-center justify-center backdrop-blur-xl border border-white/20">
            <BookOpen className="w-10 h-10 text-teal-400" />
          </div>
          <h1 className="text-6xl font-black leading-tight">مشروع حلقتي <br /> <span className="text-teal-400">لإدارة الحلقات</span></h1>
          <p className="text-xl text-teal-100/60 font-medium max-w-lg leading-relaxed">
            المنصة المتكاملة التي تجمع بين التميز التقني والروحانية الإيمانية، لخدمة كتاب الله وبناء جيل قرآني فريد.
          </p>
        </div>

        {/* Decorative Circles */}
        <div className="absolute -bottom-20 -left-20 w-80 h-80 bg-teal-500/20 rounded-full blur-[100px]" />
        <div className="absolute -top-20 -right-20 w-60 h-60 bg-teal-400/10 rounded-full blur-[80px]" />
      </div>

      {/* Form Side */}
      <div className="flex-1 flex flex-col justify-center p-8 lg:p-24 relative bg-[var(--surface)]">
        <div className="max-w-md w-full mx-auto space-y-10">
          <div className="space-y-4">
            <h2 className="text-4xl font-black text-[var(--foreground)] tracking-tight">
              {isLogin ? "مرحباً بعودتك 👋" : "إنشاء حساب جديد ✨"}
            </h2>
            <p className="text-[var(--muted)] font-medium text-lg">
              {isLogin ? "سجل دخولك لإدارة حلقاتك القرآنية." : "انضم لمئات المراكز التي تستخدم حلقتي."}
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
            {!supabaseConfiguration.isConfigured && (
              <div role="alert" className="rounded-2xl border border-amber-200 bg-amber-50 p-4 text-sm font-bold leading-6 text-amber-900 dark:border-amber-900 dark:bg-amber-950/40 dark:text-amber-100">
                إعداد الاتصال السحابي غير مكتمل. لن ينشئ النظام مستخدمًا تجريبيًا ولن يسمح بالدخول حتى تُضبط متغيرات Supabase العامة.
              </div>
            )}
            {configurationError && (
              <p role="alert" className="rounded-2xl bg-red-50 p-4 text-sm font-bold text-red-700 dark:bg-red-950/40 dark:text-red-300">
                {configurationError}
              </p>
            )}
            <div className="relative group">
              <Mail className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
              <input 
                type="email" 
                required 
                value={formData.email}
                onChange={e => setFormData({...formData, email: e.target.value})}
                placeholder="البريد الإلكتروني"
                className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
              />
            </div>

            <div className="relative group">
              <Lock className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
              <input 
                type={showPassword ? "text" : "password"} 
                required 
                value={formData.password}
                onChange={e => setFormData({...formData, password: e.target.value})}
                placeholder="كلمة المرور"
                className="w-full pr-14 pl-14 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
              />
              <button 
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute left-6 top-1/2 -translate-y-1/2 text-gray-400 hover:text-teal-600 transition-colors"
              >
                {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
              </button>
            </div>

            {!isLogin && (
              <div className="relative group animate-in fade-in slide-in-from-top-2">
                <Lock className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
                <input 
                  type={showPassword ? "text" : "password"} 
                  required 
                  value={formData.confirmPassword}
                  onChange={e => setFormData({...formData, confirmPassword: e.target.value})}
                  placeholder="تأكيد كلمة المرور"
                  className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
                />
              </div>
            )}

            {isLogin && (
              <>
                <button
                  type="button"
                  onClick={handleGoogleLogin}
                  disabled={loading || !supabaseConfiguration.isConfigured}
                  className="w-full py-4 border-2 border-[var(--border)] rounded-2xl font-black hover:border-teal-500 transition-all flex items-center justify-center gap-3"
                >
                  <svg className="w-5 h-5" viewBox="0 0 24 24">
                    <path
                      fill="currentColor"
                      d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
                    />
                    <path
                      fill="currentColor"
                      d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                    />
                    <path
                      fill="currentColor"
                      d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
                    />
                    <path
                      fill="currentColor"
                      d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
                    />
                  </svg>
                  المتابعة باستخدام Google
                </button>
                <div className="flex items-center gap-3 text-xs font-bold text-[var(--muted)]">
                  <span className="h-px flex-1 bg-[var(--border)]" />
                  أو بالبريد وكلمة المرور
                  <span className="h-px flex-1 bg-[var(--border)]" />
                </div>
              </>
            )}

            <button 
              type="submit" 
              disabled={loading || !supabaseConfiguration.isConfigured}
              className="w-full py-5 bg-teal-600 text-white rounded-2xl font-black text-lg hover:bg-teal-700 shadow-xl shadow-teal-500/20 dark:shadow-none transition-all flex items-center justify-center gap-3 group"
            >
              {loading ? (
                <Loader2 className="w-6 h-6 animate-spin" />
              ) : (
                <>
                  {isLogin ? "دخول للوحة التحكم" : "إنشاء الحساب"}
                  <ArrowRight className="w-5 h-5 group-hover:-translate-x-2 transition-transform" />
                </>
              )}
            </button>

            <div className="text-center">
              <button 
                type="button"
                onClick={() => setIsLogin(!isLogin)}
                className="text-sm font-bold text-[var(--muted)] hover:text-teal-600 transition-colors"
              >
                {isLogin ? "ليس لديك حساب؟ إنشاء حساب جديد ✨" : "لديك حساب بالفعل؟ سجل دخولك 👋"}
              </button>
            </div>
            <div className="text-center border-t border-[var(--border)] pt-5">
              <button
                type="button"
                onClick={() => router.push("/portal")}
                className="text-sm font-black text-teal-700 dark:text-teal-300 hover:underline"
              >
                دخول الطالب أو ولي الأمر
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
