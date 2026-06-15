"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { 
  Building2, 
  Users, 
  VenetianMask, 
  Plus, 
  ArrowRight,
  LogOut,
  Sparkles,
  ChevronLeft,
  LayoutGrid,
  Search,
  Loader2,
  Settings,
  X,
  Key,
  User
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";

export default function SelectCenterPage() {
  const router = useRouter();
  const { user, profile, currentSupervisor, setCurrentCenter, setUser, clearHalaqaData } = useStore();
  const [step, setStep] = useState<"center" | "halaqa">("center");
  const [selectedCenter, setSelectedCenter] = useState<any>(null);
  const [centers, setCenters] = useState<any[]>([]);
  const [halaqat, setHalaqat] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreateCenter, setShowCreateCenter] = useState(false);
  const [showCreateHalaqa, setShowCreateHalaqa] = useState(false);
  
  const [newCenterData, setNewCenterData] = useState({ name: "", address: "", type: "men" as "men" | "women" });
  const [newHalaqaData, setNewHalaqaData] = useState({ name: "", teacher_name: "" });
  
  useEffect(() => {
    const init = async () => {
      if (!user) {
        if (!supabase) {
          setCenters([
            { id: "c1", name: "ملتقى الفرقان للبنين", type: "men" },
            { id: "c2", name: "ملتقى النور للبنات", type: "women" }
          ]);
          setLoading(false);
          return;
        }

        const { data } = await supabase.auth.getSession();
        if (data.session) {
          setUser(data.session.user);
          return;
        } else {
          router.push("/login");
          return;
        }
      }

      if (!profile) {
        setLoading(true);
        const { fetchProfile } = useStore.getState();
        await fetchProfile();
        const updatedProfile = useStore.getState().profile;
        if (!updatedProfile) {
          router.push("/onboarding");
          return;
        }
        setLoading(false);
      }
      
      fetchCenters();
    };
    init();
  }, [user, profile]);

  const fetchCenters = async () => {
    if (!supabase || !user) return;
    setLoading(true);

    const { profile } = useStore.getState();
    let query = supabase.from('centers').select('*');

    if (profile?.role === 'supervisor') {
      const { currentSupervisor } = useStore.getState();
      if (currentSupervisor) {
        query = query.eq('supervisor_id', currentSupervisor.id);
      } else {
        setCenters([]);
        setLoading(false);
        return;
      }
    } else if (profile?.role === 'teacher') {
      const { data: memberData } = await supabase
        .from('center_members')
        .select('center_id, centers (*)')
        .or(`user_id.eq.${user.id},email.eq.${user.email}`);
      
      if (memberData) {
        const centerMap = new Map();
        memberData.forEach((m: any) => {
          if (m.centers) centerMap.set(m.centers.id, m.centers);
        });
        setCenters(Array.from(centerMap.values()));
        setLoading(false);
        return;
      }
    } else {
      query = query.eq('owner_id', user.id);
    }

    const { data, error } = await query;
    if (error) {
      alert(error.message);
    } else if (data) {
      setCenters(data);
    }
    setLoading(false);
  };

  const fetchHalaqat = async (centerId: string) => {
    if (!supabase) {
      setHalaqat([
        { id: "h1", name: "حلقة الإمام عاصم", teacher_name: "أ. محمد علي" },
        { id: "h2", name: "حلقة الإمام نافع", teacher_name: "أ. أحمد خالد" }
      ]);
      setLoading(false);
      return;
    }
    setLoading(true);
    const { data, error } = await supabase
      .from('halaqat')
      .select('*')
      .eq('center_id', centerId);
    
    if (error) {
      alert("فشل جلب الحلقات: " + error.message);
    } else if (data) {
      setHalaqat(data);
    }
    setLoading(false);
  };

  const handleCenterSelect = (center: any) => {
    setSelectedCenter(center);
    fetchHalaqat(center.id);
    setStep("halaqa");
  };

  const handleCreateCenter = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase || !user) return;
    setLoading(true);
    const { error } = await supabase.from('centers').insert([{ 
      name: newCenterData.name, 
      address: newCenterData.address, 
      type: newCenterData.type, 
      owner_id: user.id 
    }]);
    if (!error) {
      setShowCreateCenter(false);
      fetchCenters();
    } else {
      alert(error.message);
    }
    setLoading(false);
  };

  const handleCreateHalaqa = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase || !selectedCenter) return;
    setLoading(true);
    const { error } = await supabase.from('halaqat').insert([{ 
      name: newHalaqaData.name, 
      teacher_name: newHalaqaData.teacher_name, 
      center_id: selectedCenter.id 
    }]);
    if (!error) {
      setShowCreateHalaqa(false);
      fetchHalaqat(selectedCenter.id);
    } else {
      alert(error.message);
    }
    setLoading(false);
  };

  const handleHalaqaSelect = (halaqa: any) => {
    clearHalaqaData();
    setCurrentCenter({ ...selectedCenter, activeHalaqa: halaqa });
    router.push("/");
  };

  if (loading && step === "center" && centers.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
        <Loader2 className="w-12 h-12 text-teal-600 animate-spin" />
      </div>
    );
  }

  return (
    <>
      <div className="min-h-screen bg-gray-50 dark:bg-gray-950 p-8 flex flex-col items-center justify-center transition-all duration-500" dir="rtl">
        <div className="max-w-4xl w-full space-y-12">
          {/* Header */}
          <div className="text-center space-y-4 mb-16">
            <div className="inline-flex items-center justify-center w-20 h-20 bg-teal-600 rounded-[2rem] text-white shadow-2xl shadow-teal-500/20 mb-6">
              {step === "center" ? <Building2 className="w-10 h-10" /> : <LayoutGrid className="w-10 h-10" />}
            </div>
            <h1 className="text-5xl font-black text-gray-900 dark:text-white tracking-tight flex items-center justify-center gap-4">
              {step === "center" ? "اختر المركز 🏛️" : `حلقات ${selectedCenter?.name} 📖`}
            </h1>
            <p className="text-gray-500 dark:text-gray-400 font-medium text-lg max-w-xl mx-auto">
              {step === "center" 
                ? "يرجى تحديد المنظمة أو المسجد المراد إدارته" 
                : "اختر الحلقة لمتابعة المدرس والطلاب"}
            </p>
          </div>

          {step === "center" && (
            <div className="grid md:grid-cols-2 gap-8 animate-in zoom-in-95 duration-700">
              {(profile?.role === 'center_admin' || !profile?.role) && (
                <button 
                  onClick={() => setShowCreateCenter(true)}
                  className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-8 rounded-[2.5rem] text-right shadow-sm hover:shadow-xl hover:scale-[1.02] transition-all flex items-center gap-6 group"
                >
                  <div className="w-16 h-16 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center text-teal-600">
                    <Plus className="w-8 h-8" />
                  </div>
                  <div className="flex-1">
                    <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1">إنشاء مركز جديد 🏛️</h3>
                    <p className="text-xs text-gray-400 font-medium">ابدأ الآن وأنشئ نظامك الخاص لإدارة الحلقات</p>
                  </div>
                  <ChevronLeft className="w-6 h-6 text-gray-300 group-hover:text-teal-600 transition-colors" />
                </button>
              )}
              <div className="bg-teal-600/5 dark:bg-teal-900/10 border border-teal-100 dark:border-teal-900/30 p-8 rounded-[2.5rem] text-right flex items-center gap-6">
                <div className="w-16 h-16 bg-teal-600 text-white rounded-2xl flex items-center justify-center">
                  <Users className="w-8 h-8" />
                </div>
                <div>
                  <h3 className="text-xl font-black text-teal-900 dark:text-white mb-1">قائمة المراكز</h3>
                  <p className="text-xs text-teal-600/60 dark:text-teal-400 font-medium">لديك {centers.length} مراكز مسجلة</p>
                </div>
              </div>
            </div>
          )}

          {step === "halaqa" && (profile?.role === 'center_admin' || selectedCenter?.owner_id === user?.id) && (
            <div className="grid md:grid-cols-2 gap-8 animate-in zoom-in-95 duration-700">
              <button 
                onClick={() => setShowCreateHalaqa(true)}
                className="bg-teal-600 text-white p-8 rounded-[2.5rem] text-right shadow-xl shadow-teal-500/20 hover:scale-[1.02] transition-all flex items-center gap-6 group"
              >
                <div className="w-16 h-16 bg-white/20 rounded-2xl flex items-center justify-center backdrop-blur-md">
                  <Plus className="w-8 h-8" />
                </div>
                <div className="flex-1">
                  <h3 className="text-xl font-black mb-1">إنشاء حلقة جديدة 📖</h3>
                  <p className="text-xs text-white/70 font-medium">أضف حلقة قرآنية جديدة لمركزك الآن</p>
                </div>
                <ChevronLeft className="w-6 h-6 text-white/40 group-hover:text-white transition-colors" />
              </button>

              <button 
                onClick={() => setStep("center")}
                className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-8 rounded-[2.5rem] text-right shadow-sm hover:shadow-xl hover:scale-[1.02] transition-all flex items-center gap-6 group"
              >
                <div className="w-16 h-16 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center text-gray-400">
                  <ArrowRight className="w-8 h-8" />
                </div>
                <div className="flex-1">
                  <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1">تغيير المركز 🏛️</h3>
                  <p className="text-xs text-gray-400 font-medium">العودة لاختيار مركز آخر</p>
                </div>
              </button>
            </div>
          )}

          {step === "halaqa" && !(profile?.role === 'center_admin' || selectedCenter?.owner_id === user?.id) && (
            <div className="flex justify-center animate-in zoom-in-95 duration-700">
              <button 
                onClick={() => setStep("center")}
                className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-8 rounded-[2.5rem] text-right shadow-sm hover:shadow-xl hover:scale-[1.02] transition-all flex items-center gap-6 group max-w-md w-full"
              >
                <div className="w-16 h-16 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center text-teal-600">
                  <ArrowRight className="w-8 h-8" />
                </div>
                <div className="flex-1">
                  <h3 className="text-xl font-black text-gray-900 dark:text-white mb-1">العودة للمراكز 🏛️</h3>
                  <p className="text-xs text-gray-400 font-medium">اختيار مركز آخر للمتابعة</p>
                </div>
              </button>
            </div>
          )}

          <div className="grid md:grid-cols-2 gap-8">
            {step === "center" ? (
              centers.map((center) => (
                <div 
                  key={center.id}
                  className="group bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-8 rounded-[3rem] shadow-sm hover:shadow-2xl hover:scale-[1.01] transition-all relative overflow-hidden"
                >
                  <div className="absolute top-0 right-0 w-32 h-32 bg-teal-500/5 rounded-full blur-2xl -mr-16 -mt-16" />
                  <div className="relative z-10 flex flex-col h-full justify-between gap-8 text-right">
                    <div className="flex items-start justify-between">
                      <div className={`p-4 rounded-2xl ${center.type === 'men' ? 'bg-blue-50 text-blue-600' : 'bg-rose-50 text-rose-500'}`}>
                        {center.type === 'men' ? <Users className="w-6 h-6" /> : <VenetianMask className="w-6 h-6" />}
                      </div>
                      <div className="text-left">
                        <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{center.type === 'men' ? 'للبنين' : 'للبنات'}</span>
                      </div>
                    </div>
                    
                    <div>
                      <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-2">{center.name}</h3>
                      <p className="text-xs text-gray-400 font-medium line-clamp-1">{center.address || "لا يوجد عنوان مسجل"}</p>
                    </div>

                    <div className="flex items-center gap-3 pt-4 border-t border-gray-50 dark:border-gray-800">
                      {(profile?.role === 'center_admin' || center.owner_id === user?.id) && (
                        <Link 
                          href={`/manage-center/${center.id}`}
                          className="flex-1 py-4 bg-gray-50 dark:bg-gray-800 hover:bg-teal-600 hover:text-white rounded-2xl text-xs font-black text-gray-500 transition-all flex items-center justify-center gap-2"
                        >
                          <Settings className="w-4 h-4" /> إدارة المركز
                        </Link>
                      )}
                      <button 
                        onClick={() => handleCenterSelect(center)}
                        className="flex-[1.5] py-4 bg-teal-600 text-white rounded-2xl text-xs font-black hover:bg-teal-700 shadow-lg shadow-teal-500/20 transition-all flex items-center justify-center gap-2"
                      >
                        دخول للحلقات <ChevronLeft className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                </div>
              ))
            ) : (
              halaqat.map((halaqa) => (
                <button
                  key={halaqa.id}
                  onClick={() => handleHalaqaSelect(halaqa)}
                  className="group bg-white dark:bg-gray-900 border border-teal-100 dark:border-teal-900/30 p-10 rounded-[3rem] text-right transition-all hover:shadow-2xl hover:border-teal-500 hover:scale-[1.02] relative overflow-hidden"
                >
                  <div className="absolute top-0 left-0 w-24 h-24 bg-teal-500/5 rounded-full blur-xl -ml-12 -mt-12" />
                  <div className="relative z-10 space-y-4">
                    <div className="w-12 h-12 bg-teal-50 dark:bg-teal-900/20 rounded-xl flex items-center justify-center text-teal-600">
                      <Sparkles className="w-6 h-6" />
                    </div>
                    <div>
                      <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-2">{halaqa.name}</h3>
                      <div className="flex items-center gap-2 text-teal-600 dark:text-teal-400 text-xs font-black">
                        <User className="w-4 h-4" />
                        المعلم: {halaqa.teacher_name || "غير محدد"}
                      </div>
                    </div>
                  </div>
                </button>
              ))
            )}
          </div>
        </div>
      </div>

      {/* Create Center Modal */}
      {showCreateCenter && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-950 w-full max-w-lg rounded-[3.5rem] p-10 shadow-2xl relative animate-in zoom-in-95 duration-300" dir="rtl">
            <div className="flex justify-between items-center mb-10">
              <h2 className="text-2xl font-black text-gray-900 dark:text-white">إنشاء مركز جديد 🏛️</h2>
              <button onClick={() => setShowCreateCenter(false)} className="p-3 bg-gray-100 dark:bg-gray-800 rounded-2xl hover:bg-gray-200 transition-colors">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <form onSubmit={handleCreateCenter} className="space-y-8">
              <div className="space-y-4">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mr-2">اسم المركز</label>
                <input 
                  type="text" 
                  required
                  placeholder="مثلاً: جامع الفرقان"
                  value={newCenterData.name}
                  onChange={(e) => setNewCenterData({...newCenterData, name: e.target.value})}
                  className="w-full px-8 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                />
              </div>
              <div className="space-y-4">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mr-2">العنوان</label>
                <input 
                  type="text" 
                  placeholder="الحي، المدينة (اختياري)"
                  value={newCenterData.address}
                  onChange={(e) => setNewCenterData({...newCenterData, address: e.target.value})}
                  className="w-full px-8 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <button 
                  type="button"
                  onClick={() => setNewCenterData({...newCenterData, type: 'men'})}
                  className={`p-5 rounded-2xl border-2 transition-all flex flex-col items-center gap-2 ${newCenterData.type === 'men' ? "border-teal-600 bg-teal-50 text-teal-600" : "border-gray-50 text-gray-400"}`}
                >
                  <Users className="w-6 h-6" />
                  <span className="text-xs font-black">مركز بنين</span>
                </button>
                <button 
                  type="button"
                  onClick={() => setNewCenterData({...newCenterData, type: 'women'})}
                  className={`p-5 rounded-2xl border-2 transition-all flex flex-col items-center gap-2 ${newCenterData.type === 'women' ? "border-rose-500 bg-rose-50 text-rose-500" : "border-gray-50 text-gray-400"}`}
                >
                  <VenetianMask className="w-6 h-6" />
                  <span className="text-xs font-black">مركز نساء</span>
                </button>
              </div>
              <button type="submit" className="w-full bg-teal-600 text-white py-6 rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-xl transition-all">إتمام الإنشاء</button>
            </form>
          </div>
        </div>
      )}

      {/* Create Halaqa Modal */}
      {showCreateHalaqa && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-950 w-full max-w-lg rounded-[3.5rem] p-10 shadow-2xl relative animate-in zoom-in-95 duration-300" dir="rtl">
            <div className="flex justify-between items-center mb-10">
              <h2 className="text-2xl font-black text-gray-900 dark:text-white">إنشاء حلقة جديدة 📖</h2>
              <button onClick={() => setShowCreateHalaqa(false)} className="p-3 bg-gray-100 dark:bg-gray-800 rounded-2xl hover:bg-gray-200 transition-colors">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <form onSubmit={handleCreateHalaqa} className="space-y-8">
              <div className="space-y-4">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mr-2">اسم الحلقة</label>
                <input 
                  type="text" 
                  required
                  placeholder="مثلاً: حلقة الإمام نافع"
                  value={newHalaqaData.name}
                  onChange={(e) => setNewHalaqaData({...newHalaqaData, name: e.target.value})}
                  className="w-full px-8 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                />
              </div>
              <div className="space-y-4">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mr-2">اسم المعلم</label>
                <input 
                  type="text" 
                  placeholder="اسم المعلم الحالي (اختياري)"
                  value={newHalaqaData.teacher_name}
                  onChange={(e) => setNewHalaqaData({...newHalaqaData, teacher_name: e.target.value})}
                  className="w-full px-8 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-2xl text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                />
              </div>
              <button type="submit" className="w-full bg-teal-600 text-white py-6 rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-xl transition-all">إتمام الإنشاء</button>
            </form>
          </div>
        </div>
      )}
    </>
  );
}
