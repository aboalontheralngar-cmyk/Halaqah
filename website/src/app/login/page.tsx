"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
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
import { supabase } from "@/lib/supabase";

export default function AuthPage() {
  const router = useRouter();
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const { setUser } = useStore();

  const [formData, setFormData] = useState({
    email: "",
    password: "",
    confirmPassword: ""
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!isLogin && formData.password !== formData.confirmPassword) {
      alert("كلمات المرور غير متطابقة!");
      return;
    }

    setLoading(true);
    
    if (!supabase) {
      // Mock for demo
      setTimeout(() => {
        setLoading(false);
        setUser({ id: "mock-user", email: formData.email, name: "مشرف الحلقة" });
        router.push("/onboarding");
      }, 1500);
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
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex flex-col lg:flex-row transition-colors duration-500" dir="rtl">
      {/* Visual Side */}
      <div className="lg:w-1/2 relative overflow-hidden bg-teal-900 hidden lg:flex flex-col justify-center p-20 text-white">
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/islamic-art.png')] opacity-10" />
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
      <div className="flex-1 flex flex-col justify-center p-8 lg:p-24 relative bg-white dark:bg-gray-950">
        <div className="max-w-md w-full mx-auto space-y-10">
          <div className="space-y-4">
            <h2 className="text-4xl font-black text-gray-900 dark:text-white tracking-tight">
              {isLogin ? "مرحباً بعودتك 👋" : "إنشاء حساب جديد ✨"}
            </h2>
            <p className="text-gray-500 dark:text-gray-400 font-medium text-lg">
              {isLogin ? "سجل دخولك لإدارة حلقاتك القرآنية." : "انضم لمئات المراكز التي تستخدم حلقتي."}
            </p>
          </div>

          <form onSubmit={handleSubmit} className="space-y-6">
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

            <button 
              type="submit" 
              disabled={loading}
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
                className="text-sm font-bold text-gray-500 dark:text-gray-400 hover:text-teal-600 transition-colors"
              >
                {isLogin ? "ليس لديك حساب؟ إنشاء حساب جديد ✨" : "لديك حساب بالفعل؟ سجل دخولك 👋"}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  );
}
