"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import { 
  Building2, 
  ShieldCheck, 
  ArrowRight, 
  Users, 
  VenetianMask,
  Loader2,
  CheckCircle2,
  User,
  MapPin,
  Sparkles,
  Key
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";

export default function OnboardingPage() {
  const router = useRouter();
  const { user, profile, fetchProfile, joinWithCode } = useStore();
  const [step, setStep] = useState(1);
  const [loading, setLoading] = useState(false);
  const [joinCode, setJoinCode] = useState("");
  
  const [data, setData] = useState({
    fullName: "",
    role: "center_admin" as "center_admin" | "supervisor" | "teacher",
    centerName: "",
    centerType: "men" as "men" | "women",
    centerAddress: "",
    supervisorName: ""
  });

  useEffect(() => {
    const checkStatus = async () => {
      if (!user) {
        router.push("/login");
        return;
      }

      await fetchProfile();
      const currentProfile = useStore.getState().profile;
      
      if (currentProfile) {
        router.push("/select-center");
      }
    };
    checkStatus();
  }, [user, router, fetchProfile]);

  const handleTeacherJoin = async () => {
    setLoading(true);
    const success = await joinWithCode(joinCode);
    if (success) {
      router.push("/select-center");
    }
    setLoading(false);
  };

  const handleComplete = async () => {
    if (!supabase || !user) return;
    setLoading(true);

    try {
      // 1. Create Profile
      const { error: profileError } = await supabase.from('profiles').upsert([{ 
        id: user.id, 
        full_name: data.fullName, 
        role: data.role 
      }]);
      if (profileError) throw profileError;

      if (data.role === 'center_admin') {
        // 2. Create Center
        const { error: centerError } = await supabase
          .from('centers')
          .insert([{ 
            name: data.centerName, 
            address: data.centerAddress,
            type: data.centerType, 
            owner_id: user.id 
          }]);
        if (centerError) throw centerError;
      } else {
        // 2. Create Supervisor
        const code = 'HAL-' + Math.random().toString(36).substring(2, 8).toUpperCase();
        const { error: supError } = await supabase
          .from('supervisors')
          .insert([{ 
            name: data.supervisorName, 
            code, 
            owner_id: user.id 
          }]);
        if (supError) throw supError;
      }

      router.push("/select-center");
    } catch (error: any) {
      alert(error.message || "حدث خطأ أثناء إعداد الحساب");
    } finally {
      setLoading(false);
    }
  };

  if (!user) return null;

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center p-6" dir="rtl">
      <div className="max-w-2xl w-full bg-white dark:bg-gray-900 rounded-3xl border border-gray-100 dark:border-gray-800 shadow-2xl p-10 md:p-16 space-y-12 relative overflow-hidden">
        {/* Background Decor */}
        <div className="absolute top-0 right-0 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl -mr-32 -mt-32" />
        <div className="absolute bottom-0 left-0 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl -ml-32 -mb-32" />

        {/* Progress Dots */}
        <div className="flex justify-center gap-3 relative z-10">
          {[1, 2, 3].map((s) => (
            <div 
              key={s} 
              className={`h-2 rounded-full transition-all duration-500 ${step === s ? "w-12 bg-teal-600" : "w-3 bg-gray-200 dark:bg-gray-800"}`}
            />
          ))}
        </div>

        {step === 1 && (
          <div className="space-y-10 animate-in fade-in slide-in-from-left-4 duration-500 relative z-10 text-center">
            <div className="space-y-4">
              <h1 className="text-4xl font-black text-gray-900 dark:text-white">أهلاً بك في حلقتي 👋</h1>
              <p className="text-gray-500 dark:text-gray-400 font-medium text-lg">قبل أن نبدأ، ما هو اسمك الكامل؟</p>
            </div>
            
            <div className="relative group max-w-md mx-auto">
              <User className="absolute right-6 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
              <input 
                type="text" 
                placeholder="الاسم الثلاثي"
                value={data.fullName}
                onChange={(e) => setData({...data, fullName: e.target.value})}
                className="w-full pr-16 pl-6 py-6 bg-gray-50 dark:bg-gray-800/50 border-none rounded-2xl text-lg font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all text-center"
              />
            </div>

            <button 
              onClick={() => data.fullName && setStep(2)}
              disabled={!data.fullName}
              className="bg-teal-600 text-white px-12 py-6 rounded-2xl font-black text-lg hover:bg-teal-700 shadow-xl shadow-teal-500/20 disabled:opacity-50 disabled:shadow-none transition-all flex items-center justify-center gap-4 mx-auto group"
            >
              استمرار
              <ArrowRight className="w-6 h-6 group-hover:-translate-x-2 transition-transform" />
            </button>
          </div>
        )}

        {step === 2 && (
          <div className="space-y-10 animate-in fade-in slide-in-from-left-4 duration-500 relative z-10">
            <div className="text-center space-y-4">
              <h1 className="text-4xl font-black text-gray-900 dark:text-white">ما هو دورك؟ 🛠️</h1>
              <p className="text-gray-500 dark:text-gray-400 font-medium">اختر نوع الحساب الذي ترغب في إدارته.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <button 
                onClick={() => setData({...data, role: 'center_admin'})}
                className={`p-8 rounded-[2.5rem] border-4 transition-all flex flex-col items-center gap-6 group ${data.role === 'center_admin' ? "border-teal-600 bg-teal-50 dark:bg-teal-900/20" : "border-gray-50 dark:border-gray-800 hover:border-teal-200"}`}
              >
                <div className={`w-16 h-16 rounded-2xl flex items-center justify-center transition-all ${data.role === 'center_admin' ? "bg-teal-600 text-white scale-110" : "bg-gray-100 dark:bg-gray-800 text-gray-400"}`}>
                  <Building2 className="w-8 h-8" />
                </div>
                <div className="text-center">
                  <h3 className={`text-lg font-black mb-1 ${data.role === 'center_admin' ? "text-teal-900 dark:text-white" : "text-gray-600 dark:text-gray-400"}`}>مدير مركز</h3>
                  <p className="text-[10px] text-gray-400 font-bold leading-relaxed line-clamp-2">إدارة الطلاب، الحلقات، والتقارير.</p>
                </div>
              </button>

              <button 
                onClick={() => setData({...data, role: 'supervisor'})}
                className={`p-8 rounded-[2.5rem] border-4 transition-all flex flex-col items-center gap-6 group ${data.role === 'supervisor' ? "border-teal-600 bg-teal-50 dark:bg-teal-900/20" : "border-gray-50 dark:border-gray-800 hover:border-teal-200"}`}
              >
                <div className={`w-16 h-16 rounded-2xl flex items-center justify-center transition-all ${data.role === 'supervisor' ? "bg-teal-600 text-white scale-110" : "bg-gray-100 dark:bg-gray-800 text-gray-400"}`}>
                  <ShieldCheck className="w-8 h-8" />
                </div>
                <div className="text-center">
                  <h3 className={`text-lg font-black mb-1 ${data.role === 'supervisor' ? "text-teal-900 dark:text-white" : "text-gray-600 dark:text-gray-400"}`}>جهة إشرافية</h3>
                  <p className="text-[10px] text-gray-400 font-bold leading-relaxed line-clamp-2">الإشراف على عدة مراكز ومتابعة الأداء.</p>
                </div>
              </button>

              <button 
                onClick={() => setData({...data, role: 'teacher' as any})}
                className={`p-8 rounded-[2.5rem] border-4 transition-all flex flex-col items-center gap-6 group ${data.role === 'teacher' ? "border-amber-500 bg-amber-50 dark:bg-amber-900/20" : "border-gray-50 dark:border-gray-800 hover:border-amber-200"}`}
              >
                <div className={`w-16 h-16 rounded-2xl flex items-center justify-center transition-all ${data.role === 'teacher' ? "bg-amber-500 text-white scale-110" : "bg-gray-100 dark:bg-gray-800 text-gray-400"}`}>
                  <Sparkles className="w-8 h-8" />
                </div>
                <div className="text-center">
                  <h3 className={`text-lg font-black mb-1 ${data.role === 'teacher' ? "text-amber-900 dark:text-white" : "text-gray-600 dark:text-gray-400"}`}>معلم حلقة</h3>
                  <p className="text-[10px] text-gray-400 font-bold leading-relaxed line-clamp-2">الانضمام لمركز موجود عبر كود المشرف.</p>
                </div>
              </button>
            </div>

            <div className="flex gap-4">
              <button onClick={() => setStep(1)} className="flex-1 py-6 rounded-2xl font-black text-gray-400 hover:bg-gray-50 transition-all">رجوع</button>
              <button 
                onClick={() => setStep(data.role === 'teacher' ? 4 : 3)}
                className="flex-[2] bg-teal-600 text-white py-6 rounded-2xl font-black text-lg hover:bg-teal-700 shadow-xl shadow-teal-500/20 transition-all flex items-center justify-center gap-4 group"
              >
                التالي
                <ArrowRight className="w-6 h-6 group-hover:-translate-x-2 transition-transform" />
              </button>
            </div>
          </div>
        )}

        {step === 3 && (
          <div className="space-y-10 animate-in fade-in slide-in-from-left-4 duration-500 relative z-10">
            <div className="text-center space-y-4">
              <h1 className="text-4xl font-black text-gray-900 dark:text-white">آخر خطوة! ✨</h1>
              <p className="text-gray-500 dark:text-gray-400 font-medium">أكمل بيانات {data.role === 'center_admin' ? 'المركز' : 'الجهة'} للبدء.</p>
            </div>

            {data.role === 'center_admin' ? (
              <div className="space-y-6">
                <div className="relative group">
                  <Building2 className="absolute right-6 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400" />
                  <input 
                    type="text" 
                    placeholder="اسم مركز التحفيظ"
                    value={data.centerName}
                    onChange={(e) => setData({...data, centerName: e.target.value})}
                    className="w-full pr-16 pl-6 py-6 bg-gray-50 dark:bg-gray-800/50 border-none rounded-2xl text-lg font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                  />
                </div>
                <div className="relative group">
                  <MapPin className="absolute right-6 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400" />
                  <input 
                    type="text" 
                    placeholder="عنوان المركز (اختياري)"
                    value={data.centerAddress}
                    onChange={(e) => setData({...data, centerAddress: e.target.value})}
                    className="w-full pr-16 pl-6 py-6 bg-gray-50 dark:bg-gray-800/50 border-none rounded-2xl text-lg font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                  />
                </div>
                <div className="grid grid-cols-2 gap-6">
                  <button 
                    onClick={() => setData({...data, centerType: 'men'})}
                    className={`p-6 rounded-2xl border-2 transition-all flex flex-col items-center gap-3 ${data.centerType === 'men' ? "border-teal-600 bg-teal-50 dark:bg-teal-900/20 text-teal-700" : "border-gray-50 dark:border-gray-800 text-gray-400"}`}
                  >
                    <Users className="w-6 h-6" />
                    <span className="text-sm font-black">مركز رجال</span>
                  </button>
                  <button 
                    onClick={() => setData({...data, centerType: 'women'})}
                    className={`p-6 rounded-2xl border-2 transition-all flex flex-col items-center gap-3 ${data.centerType === 'women' ? "border-rose-500 bg-rose-50 dark:bg-rose-900/20 text-rose-500" : "border-gray-50 dark:border-gray-800 text-gray-400"}`}
                  >
                    <VenetianMask className="w-6 h-6" />
                    <span className="text-sm font-black">مركز نساء</span>
                  </button>
                </div>
              </div>
            ) : (
              <div className="relative group">
                <ShieldCheck className="absolute right-6 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400" />
                <input 
                  type="text" 
                  placeholder="اسم الجهة الإشرافية (جمعية، مؤسسة...)"
                  value={data.supervisorName}
                  onChange={(e) => setData({...data, supervisorName: e.target.value})}
                  className="w-full pr-16 pl-6 py-6 bg-gray-50 dark:bg-gray-800/50 border-none rounded-2xl text-lg font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                />
              </div>
            )}

            <div className="flex gap-4">
              <button onClick={() => setStep(2)} className="flex-1 py-6 rounded-2xl font-black text-gray-400 hover:bg-gray-50 transition-all">رجوع</button>
              <button 
                onClick={handleComplete}
                disabled={loading || (data.role === 'center_admin' ? !data.centerName : !data.supervisorName)}
                className="flex-[2] bg-teal-600 text-white py-6 rounded-2xl font-black text-lg hover:bg-teal-700 shadow-xl shadow-teal-500/20 disabled:opacity-50 transition-all flex items-center justify-center gap-4 group"
              >
                {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : (
                  <>
                    إتمام الإعداد
                    <CheckCircle2 className="w-6 h-6 group-hover:scale-110 transition-transform" />
                  </>
                )}
              </button>
            </div>
          </div>
        )}
        {step === 4 && (
          <div className="space-y-10 animate-in fade-in slide-in-from-left-4 duration-500 relative z-10 text-center">
            <div className="space-y-4">
              <h1 className="text-4xl font-black text-gray-900 dark:text-white">كود الانضمام 🔐</h1>
              <p className="text-gray-500 dark:text-gray-400 font-medium text-lg">يرجى إدخال الكود المشفر الذي وصلك من مدير المركز</p>
            </div>

            <div className="max-w-md mx-auto space-y-6">
              <div className="relative group">
                <Key className="absolute right-6 top-1/2 -translate-y-1/2 w-6 h-6 text-gray-400 group-focus-within:text-amber-500 transition-colors" />
                <input 
                  type="text" 
                  placeholder="HAL-XXXXXXX"
                  value={joinCode}
                  onChange={(e) => setJoinCode(e.target.value.toUpperCase())}
                  className="w-full pr-16 pl-6 py-6 bg-gray-50 dark:bg-gray-800/50 border-none rounded-2xl text-xl font-black outline-none focus:ring-4 ring-amber-500/10 dark:text-white transition-all text-center tracking-widest font-mono"
                />
              </div>

              <div className="bg-amber-50 dark:bg-amber-900/10 p-4 rounded-2xl border border-amber-100 dark:border-amber-900/30 flex items-start gap-3 text-right">
                <ShieldCheck className="w-5 h-5 text-amber-600 shrink-0 mt-0.5" />
                <p className="text-[10px] text-amber-800 dark:text-amber-200 font-bold leading-relaxed">
                  ملاحظة أمنية: سيتم التحقق من تطابق بريدك الإلكتروني الحالي مع البريد المرتبط بهذا الكود لضمان صحة البيانات.
                </p>
              </div>

              <div className="flex gap-4">
                <button onClick={() => setStep(2)} className="flex-1 py-6 rounded-2xl font-black text-gray-400 hover:bg-gray-50 transition-all">رجوع</button>
                <button 
                  onClick={handleTeacherJoin}
                  disabled={loading || !joinCode}
                  className="flex-[2] bg-amber-500 text-white py-6 rounded-2xl font-black text-lg hover:bg-amber-600 shadow-xl shadow-amber-500/20 disabled:opacity-50 transition-all flex items-center justify-center gap-4 group"
                >
                  {loading ? <Loader2 className="w-6 h-6 animate-spin" /> : (
                    <>
                      تحقق وانضم الآن
                      <ArrowRight className="w-6 h-6 group-hover:-translate-x-2 transition-transform" />
                    </>
                  )}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
