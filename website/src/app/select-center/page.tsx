"use client";

import { useState, useEffect } from "react";
import { useRouter } from "next/navigation";
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
  Loader2
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";

export default function SelectCenterPage() {
  const router = useRouter();
  const { user, profile, currentSupervisor, setCurrentCenter, setUser } = useStore();
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
      // 1. Check Session/User
      if (!user) {
        if (!supabase) {
          // Mock for demo if no supabase
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

      // 2. Check Profile
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
      // Fetch centers where user is a teacher
      const { data: memberData } = await supabase
        .from('center_members')
        .select('center_id, centers (*)')
        .eq('user_id', user.id);
      
      if (memberData) {
        setCenters(memberData.map((m: any) => m.centers).filter(Boolean));
        setLoading(false);
        return;
      }
    } else {
      query = query.eq('owner_id', user.id);
    }

    const { data, error } = await query;
    
    if (error) {
      alert("فشل جلب المراكز: " + error.message);
    } else if (data) {
      setCenters(data);
    }
    setLoading(false);
  };

  const fetchHalaqat = async (centerId: string) => {
    if (!supabase) {
      // Mock halaqat for demo
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

  const handleHalaqaSelect = (halaqa: any) => {
    setCurrentCenter({ ...selectedCenter, activeHalaqa: halaqa });
    router.push("/");
  };

  const handleLogout = async () => {
    if (supabase) await supabase.auth.signOut();
    setUser(null);
    router.push("/login");
  };

  const handleCreateCenter = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase || !user) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('centers')
      .insert([{ ...newCenterData, owner_id: user.id }])
      .select()
      .single();
    
    if (error) {
      alert(error.message);
    } else if (data) {
      setCenters([...centers, data]);
      setShowCreateCenter(false);
      setNewCenterData({ name: "", address: "", type: "men" });
    }
    setLoading(false);
  };

  const handleCreateHalaqa = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!supabase || !selectedCenter) return;
    setLoading(true);
    const { data, error } = await supabase
      .from('halaqat')
      .insert([{ ...newHalaqaData, center_id: selectedCenter.id }])
      .select()
      .single();
    
    if (error) {
      alert(error.message);
    } else if (data) {
      setHalaqat([...halaqat, data]);
      setShowCreateHalaqa(false);
      setNewHalaqaData({ name: "", teacher_name: "" });
    }
    setLoading(false);
  };

  if (loading && step === "center" && centers.length === 0) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
        <Loader2 className="w-12 h-12 text-teal-600 animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 p-8 flex flex-col items-center justify-center transition-all duration-500" dir="rtl">
      <div className="max-w-4xl w-full space-y-12">
        {/* Header */}
        <div className="text-center space-y-4 animate-in fade-in slide-in-from-top-4 duration-700">
          <div className="w-20 h-20 bg-teal-600 rounded-3xl flex items-center justify-center mx-auto shadow-2xl shadow-teal-200 dark:shadow-none mb-6">
            {step === "center" ? <Building2 className="w-10 h-10 text-white" /> : <LayoutGrid className="w-10 h-10 text-white" />}
          </div>
          <h1 className="text-4xl font-black text-gray-900 dark:text-white">
            {step === "center" ? "اختر المركز 🏛️" : `حلقات ${selectedCenter?.name} 📖`}
          </h1>
          <p className="text-gray-500 dark:text-gray-400 font-medium text-lg">
            {step === "center" ? "يرجى تحديد المنظمة أو المسجد المراد إدارته" : "اختر الحلقة لمتابعة المدرس والطلاب"}
          </p>
        </div>

        {/* Selection Area */}
        <div className="grid md:grid-cols-2 gap-8">
          {step === "center" ? (
            <>
              {centers.length === 0 ? (
                <div className="md:col-span-2 text-center py-20 bg-white dark:bg-gray-900 rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-800">
                  <p className="text-gray-400 font-black mb-6">لا يوجد مراكز مسجلة باسمك حالياً</p>
                  <button onClick={() => setShowCreateCenter(true)} className="px-8 py-4 bg-teal-600 text-white rounded-2xl font-black text-sm">إنشاء مركز جديد</button>
                </div>
              ) : (
                <div className="md:col-span-2 grid md:grid-cols-2 gap-8">
                  {centers.map((center) => (
                    <button
                      key={center.id}
                      onClick={() => handleCenterSelect(center)}
                      className="group relative bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-10 rounded-3xl text-right transition-all hover:shadow-2xl hover:scale-[1.02] overflow-hidden"
                    >
                      <div className={`absolute top-0 right-0 w-2 h-full ${center.type === 'men' ? "bg-teal-600" : "bg-rose-500"}`} />
                      <div className="flex items-center gap-6">
                        <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${center.type === 'men' ? "bg-teal-50 text-teal-600" : "bg-rose-50 text-rose-500"}`}>
                          {center.type === 'men' ? <Users className="w-8 h-8" /> : <VenetianMask className="w-8 h-8" />}
                        </div>
                        <div className="flex-1">
                          <h3 className="text-xl font-black text-gray-900 dark:text-white">{center.name}</h3>
                          <p className="text-[10px] font-black text-gray-400 uppercase tracking-[0.2em] mt-1">{center.type === 'men' ? "قطاع البنين" : "قطاع البنات"}</p>
                        </div>
                        <ChevronLeft className="w-6 h-6 text-gray-300 group-hover:text-teal-600 transition-colors" />
                      </div>
                    </button>
                  ))}
                  <button 
                    onClick={() => setShowCreateCenter(true)}
                    className="md:col-span-2 py-6 border-2 border-dashed border-gray-200 dark:border-gray-800 rounded-2xl flex items-center justify-center gap-3 text-gray-400 font-black hover:border-teal-500 hover:text-teal-600 transition-all"
                  >
                    <Plus className="w-6 h-6" /> إضافة مركز آخر
                  </button>
                </div>
              )}
            </>
          ) : (
            <>
              {halaqat.length === 0 ? (
                <div className="md:col-span-2 text-center py-20 bg-white dark:bg-gray-900 rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-800">
                  <p className="text-gray-400 font-black mb-6">لا توجد حلقات مسجلة في هذا المركز</p>
                  <button onClick={() => setShowCreateHalaqa(true)} className="px-8 py-4 bg-teal-600 text-white rounded-2xl font-black text-sm">إضافة حلقة</button>
                </div>
              ) : (
                <div className="md:col-span-2 grid md:grid-cols-2 gap-8">
                  {halaqat.map((halaqa) => (
                    <button
                      key={halaqa.id}
                      onClick={() => handleHalaqaSelect(halaqa)}
                      className="group bg-white dark:bg-gray-900 border border-teal-100 dark:border-teal-900/30 p-8 rounded-3xl text-right transition-all hover:shadow-xl hover:border-teal-500"
                    >
                      <h3 className="text-lg font-black text-gray-900 dark:text-white mb-2">{halaqa.name}</h3>
                      <div className="flex items-center gap-2 text-teal-600 dark:text-teal-400 text-xs font-bold">
                        <Sparkles className="w-4 h-4" />
                        المعلم: {halaqa.teacher_name || "غير محدد"}
                      </div>
                      <div className="mt-6 flex justify-end">
                        <div className="px-4 py-2 bg-gray-50 dark:bg-gray-800 rounded-xl text-[10px] font-black text-gray-400 group-hover:bg-teal-600 group-hover:text-white transition-all">
                          دخول للحلقة
                        </div>
                      </div>
                    </button>
                  ))}
                  <button 
                    onClick={() => setShowCreateHalaqa(true)}
                    className="md:col-span-2 py-6 border-2 border-dashed border-gray-200 dark:border-gray-800 rounded-2xl flex items-center justify-center gap-3 text-gray-400 font-black hover:border-teal-500 hover:text-teal-600 transition-all"
                  >
                    <Plus className="w-6 h-6" /> إضافة حلقة أخرى
                  </button>
                </div>
              )}
              <button 
                onClick={() => setStep("center")}
                className="md:col-span-2 text-center text-xs font-black text-gray-400 hover:text-teal-600 flex items-center justify-center gap-2 mt-4"
              >
                <ArrowRight className="w-4 h-4 rotate-180" /> العودة لاختيار المركز
              </button>
            </>
          )}
        </div>

        {/* Footer */}
        <div className="pt-10 flex flex-col items-center gap-6">
          <button 
            onClick={handleLogout}
            className="flex items-center gap-2 text-gray-400 hover:text-rose-600 font-black text-sm transition-colors"
          >
            <LogOut className="w-4 h-4" /> تسجيل الخروج
          </button>
          <p className="text-[10px] font-black text-gray-300 dark:text-gray-700 uppercase tracking-widest">تطبيق حلقتي - يخدم كتاب الله وأهله</p>
        </div>
      </div>

      {/* Create Center Modal */}
      {showCreateCenter && (
        <div className="fixed inset-0 bg-gray-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-md shadow-2xl animate-in zoom-in-95 duration-300">
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8">إنشاء مركز جديد 🏛️</h3>
            <form onSubmit={handleCreateCenter} className="space-y-6">
              <div>
                <label className="block text-xs font-black text-gray-400 mb-3 uppercase tracking-widest">اسم المركز</label>
                <input 
                  type="text" 
                  required 
                  value={newCenterData.name}
                  onChange={e => setNewCenterData({...newCenterData, name: e.target.value})}
                  className="w-full px-6 py-4 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl text-sm font-bold outline-none ring-teal-500/20 focus:ring-2"
                />
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 mb-3 uppercase tracking-widest">العنوان</label>
                <input 
                  type="text" 
                  value={newCenterData.address}
                  onChange={e => setNewCenterData({...newCenterData, address: e.target.value})}
                  placeholder="مثال: صنعاء - حي الأصبحي"
                  className="w-full px-6 py-4 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl text-sm font-bold outline-none ring-teal-500/20 focus:ring-2"
                />
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 mb-3 uppercase tracking-widest">النوع</label>
                <div className="grid grid-cols-2 gap-4">
                  <button type="button" onClick={() => setNewCenterData({...newCenterData, type: 'men'})} className={`py-4 rounded-xl font-black text-xs ${newCenterData.type === 'men' ? "bg-teal-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400"}`}>رجال</button>
                  <button type="button" onClick={() => setNewCenterData({...newCenterData, type: 'women'})} className={`py-4 rounded-xl font-black text-xs ${newCenterData.type === 'women' ? "bg-rose-500 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400"}`}>نساء</button>
                  <button type="button" onClick={() => setNewCenterData({...newCenterData, type: 'mixed'})} className={`py-4 rounded-xl font-black text-xs ${newCenterData.type === 'mixed' ? "bg-amber-500 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400"}`}>مختلط</button>
                </div>
              </div>
              <div className="flex gap-4 pt-4">
                <button type="submit" className="flex-1 py-4 bg-teal-600 text-white rounded-2xl font-black text-sm shadow-xl">تأكيد الإنشاء</button>
                <button type="button" onClick={() => setShowCreateCenter(false)} className="px-6 py-4 bg-gray-100 dark:bg-gray-800 text-gray-500 rounded-2xl font-black text-sm">إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Create Halaqa Modal */}
      {showCreateHalaqa && (
        <div className="fixed inset-0 bg-gray-900/60 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-md shadow-2xl animate-in zoom-in-95 duration-300">
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8">إضافة حلقة جديدة 📖</h3>
            <form onSubmit={handleCreateHalaqa} className="space-y-6">
              <div>
                <label className="block text-xs font-black text-gray-400 mb-3 uppercase tracking-widest">اسم الحلقة</label>
                <input 
                  type="text" 
                  required 
                  value={newHalaqaData.name}
                  onChange={e => setNewHalaqaData({...newHalaqaData, name: e.target.value})}
                  className="w-full px-6 py-4 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl text-sm font-bold outline-none ring-teal-500/20 focus:ring-2"
                />
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 mb-3 uppercase tracking-widest">اسم المعلم</label>
                <input 
                  type="text" 
                  value={newHalaqaData.teacher_name}
                  onChange={e => setNewHalaqaData({...newHalaqaData, teacher_name: e.target.value})}
                  className="w-full px-6 py-4 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl text-sm font-bold outline-none ring-teal-500/20 focus:ring-2"
                />
              </div>
              <div className="flex gap-4 pt-4">
                <button type="submit" className="flex-1 py-4 bg-teal-600 text-white rounded-2xl font-black text-sm shadow-xl">إضافة الحلقة</button>
                <button type="button" onClick={() => setShowCreateHalaqa(false)} className="px-6 py-4 bg-gray-100 dark:bg-gray-800 text-gray-500 rounded-2xl font-black text-sm">إلغاء</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
