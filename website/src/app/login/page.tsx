"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { 
  Mail, 
  Lock, 
  ArrowRight, 
  BookOpen, 
  Sparkles, 
  UserPlus, 
  Building2,
  CheckCircle2,
  Loader2,
  ShieldCheck,
  Users,
  VenetianMask
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";

export default function AuthPage() {
  const router = useRouter();
  const [isLogin, setIsLogin] = useState(true);
  const [loading, setLoading] = useState(false);
  const { setCenterType, setUser } = useStore();

  const [formData, setFormData] = useState({
    email: "",
    password: "",
    fullName: "",
    role: "center_admin" as "center_admin" | "supervisor",
    centerName: "",
    centerAddress: "",
    centerType: "men" as "men" | "women",
    supervisorName: ""
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    
    if (!supabase) {
      // Mock for demo
      setTimeout(() => {
        setLoading(false);
        setCenterType(formData.centerType);
        setUser({ id: "mock-user", email: formData.email, name: "مشرف الحلقة" });
        router.push("/select-center");
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
          // Create Profile
          await supabase.from('profiles').insert([{ 
            id: authData.user.id, 
            full_name: formData.fullName, 
            role: formData.role 
          }]);

          if (formData.role === 'center_admin') {
            // Create Center
            const { error: centerError } = await supabase
              .from('centers')
              .insert([{ 
                name: formData.centerName, 
                address: formData.centerAddress,
                type: formData.centerType, 
                owner_id: authData.user.id 
              }]);
            if (centerError) throw centerError;
          } else {
            // Create Supervisor
            const code = 'HAL-' + Math.random().toString(36).substring(2, 8).toUpperCase();
            const { error: supError } = await supabase
              .from('supervisors')
              .insert([{ 
                name: formData.supervisorName, 
                code, 
                owner_id: authData.user.id 
              }]);
            if (supError) throw supError;
          }
          
          setUser(authData.user);
          router.push("/select-center");
        }
      }
    } catch (error: any) {
      alert(error.message || "حدث خطأ أثناء المصادقة");
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
          <div className="w-20 h-20 bg-white/10 rounded-[2.5rem] flex items-center justify-center backdrop-blur-xl border border-white/20">
            <BookOpen className="w-10 h-10 text-teal-400" />
          </div>
          <h1 className="text-6xl font-black leading-tight">مشروع حلقتي <br /> <span className="text-teal-400">لإدارة الحلقات</span></h1>
          <p className="text-xl text-teal-100/60 font-medium max-w-lg leading-relaxed">
            المنصة المتكاملة التي تجمع بين التميز التقني والروحانية الإيمانية، لخدمة كتاب الله وبناء جيل قرآني فريد.
          </p>
          
          <div className="grid grid-cols-2 gap-6 pt-10">
            <div className="bg-white/5 p-6 rounded-3xl border border-white/10 backdrop-blur-sm">
              <CheckCircle2 className="w-6 h-6 text-teal-400 mb-4" />
              <p className="font-bold text-sm">عزلة تامة للبيانات</p>
              <p className="text-[10px] text-teal-100/40 mt-1">كل مركز له عالمه المستقل الخاص</p>
            </div>
            <div className="bg-white/5 p-6 rounded-3xl border border-white/10 backdrop-blur-sm">
              <ShieldCheck className="w-6 h-6 text-teal-400 mb-4" />
              <p className="font-bold text-sm">أمان عالي المستوى</p>
              <p className="text-[10px] text-teal-100/40 mt-1">حماية فائقة لخصوصية الطلاب</p>
            </div>
          </div>
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
            {!isLogin && (
              <div className="grid grid-cols-2 gap-4 mb-8">
                <button 
                  type="button"
                  onClick={() => setFormData({...formData, role: 'center_admin'})}
                  className={`p-4 rounded-[2rem] border-2 transition-all flex flex-col items-center gap-3 ${formData.role === 'center_admin' ? 'border-teal-600 bg-teal-50 dark:bg-teal-900/20 text-teal-700 dark:text-teal-400' : 'border-gray-100 dark:border-gray-800 text-gray-400'}`}
                >
                  <Building2 className="w-6 h-6" />
                  <span className="text-xs font-black">مركز تحفيظ</span>
                </button>
                <button 
                  type="button"
                  onClick={() => setFormData({...formData, role: 'supervisor'})}
                  className={`p-4 rounded-[2rem] border-2 transition-all flex flex-col items-center gap-3 ${formData.role === 'supervisor' ? 'border-teal-600 bg-teal-50 dark:bg-teal-900/20 text-teal-700 dark:text-teal-400' : 'border-gray-100 dark:border-gray-800 text-gray-400'}`}
                >
                  <ShieldCheck className="w-6 h-6" />
                  <span className="text-xs font-black">جهة إشرافية</span>
                </button>
              </div>
            )}

            {!isLogin && (
              <div className="relative group">
                <VenetianMask className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600" />
                <input 
                  type="text" 
                  required 
                  value={formData.fullName}
                  onChange={e => setFormData({...formData, fullName: e.target.value})}
                  placeholder="الاسم الكامل للمشرف"
                  className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
                />
              </div>
            )}

            <div className="relative group">
              <Mail className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600" />
              <input 
                type="email" 
                required 
                value={formData.email}
                onChange={e => setFormData({...formData, email: e.target.value})}
                placeholder="البريد الإلكتروني"
                className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
              />
            </div>

            <div className="relative group">
              <Lock className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600" />
              <input 
                type="password" 
                required 
                value={formData.password}
                onChange={e => setFormData({...formData, password: e.target.value})}
                placeholder="كلمة المرور"
                className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
              />
            </div>

            {!isLogin && formData.role === 'center_admin' && (
              <div className="space-y-6 animate-in fade-in slide-in-from-top-2">
                <div className="relative group">
                  <Building2 className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input 
                    type="text" 
                    required 
                    value={formData.centerName}
                    onChange={e => setFormData({...formData, centerName: e.target.value})}
                    placeholder="اسم مركز التحفيظ"
                    className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
                  />
                </div>
                <div className="grid grid-cols-2 gap-4">
                  <button 
                    type="button"
                    onClick={() => setFormData({...formData, centerType: 'men'})}
                    className={`flex items-center justify-center gap-3 py-4 rounded-2xl border-2 transition-all ${formData.centerType === 'men' ? "border-teal-600 bg-teal-50 dark:bg-teal-900/20 text-teal-700 dark:text-teal-400" : "border-gray-100 dark:border-gray-800 text-gray-400"}`}
                  >
                    <Users className="w-4 h-4" />
                    <span className="text-xs font-black">رجال</span>
                  </button>
                  <button 
                    type="button"
                    onClick={() => setFormData({...formData, centerType: 'women'})}
                    className={`flex items-center justify-center gap-3 py-4 rounded-2xl border-2 transition-all ${formData.centerType === 'women' ? "border-rose-500 bg-rose-50 dark:bg-rose-900/20 text-rose-500 dark:text-rose-400" : "border-gray-100 dark:border-gray-800 text-gray-400"}`}
                  >
                    <VenetianMask className="w-4 h-4" />
                    <span className="text-xs font-black">نساء</span>
                  </button>
                </div>
              </div>
            )}

            {!isLogin && formData.role === 'supervisor' && (
              <div className="animate-in fade-in slide-in-from-top-2">
                <div className="relative group">
                  <ShieldCheck className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
                  <input 
                    type="text" 
                    required 
                    value={formData.supervisorName}
                    onChange={e => setFormData({...formData, supervisorName: e.target.value})}
                    placeholder="اسم الجهة الإشرافية"
                    className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white transition-all"
                  />
                </div>
              </div>
            )}

            <button 
              type="submit" 
              disabled={loading}
              className="w-full py-6 bg-teal-600 text-white rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-2xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-3 group"
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
