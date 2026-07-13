"use client";

import { useState, useEffect } from "react";
import { useParams, useRouter } from "next/navigation";
import { 
  Building2, 
  Users, 
  UserPlus, 
  Mail, 
  BookOpen, 
  LayoutGrid, 
  ArrowLeft,
  Copy,
  Check,
  Loader2,
  Trash2,
  ExternalLink,
  Edit2
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";
import type { SVGProps } from "react";

type CenterInfo = {
  id: string;
  name: string;
  address?: string;
  type: "men" | "women" | "mixed";
};

export default function ManageCenterPage() {
  const params = useParams();
  const centerId = params.id as string;
  const router = useRouter();
  const { 
    user, fetchProfile,
    teachers, fetchTeachers, addTeacher, removeTeacher, assignTeacherToHalaqa,
    halaqat, fetchAllHalaqat,
  } = useStore();

  const [loading, setLoading] = useState(true);
  const [copiedId, setCopiedId] = useState<string | null>(null);
  const [showAddTeacherModal, setShowAddTeacherModal] = useState(false);
  const [newTeacherEmail, setNewTeacherEmail] = useState("");
  const [centerInfo, setCenterInfo] = useState<CenterInfo | null>(null);
  const [, setEditingHalaqa] = useState<{id: string, name: string} | null>(null);
  const [, setDeletingHalaqa] = useState<string | null>(null);

  useEffect(() => {
    const init = async () => {
      if (!user) {
        await fetchProfile();
      }
      
      if (supabase) {
        const { data: centerData, error: centerError } = await supabase
          .from('centers')
          .select('*')
          .eq('id', centerId)
          .maybeSingle();
        
        if (centerError || !centerData) {
          console.error("Fetch center error:", centerError);
          alert(centerError?.message || "خطأ: لم يتم العثور على المركز أو ليس لديك صلاحية كافية لإدارته.");
          router.push("/select-center");
          return;
        }
        
        setCenterInfo(centerData);
        // CRITICAL: Update store so addTeacher knows which center we are in
        useStore.getState().setCurrentCenter({
          id: centerData.id,
          name: centerData.name,
          type: centerData.type
        });
      }
      
      await Promise.all([
        fetchTeachers(),
        fetchAllHalaqat(centerId)
      ]);
      setLoading(false);
    };
    init();
  }, [centerId]);

  const handleCopyCode = (code: string, teacherId: string) => {
    if (!code) return;
    navigator.clipboard.writeText(code);
    setCopiedId(teacherId);
    setTimeout(() => setCopiedId(null), 2000);
  };

  const handleAddTeacher = async (e: React.FormEvent) => {
    e.preventDefault();
    await addTeacher(newTeacherEmail);
    setNewTeacherEmail("");
    setShowAddTeacherModal(false);
    fetchTeachers();
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-950 flex items-center justify-center">
        <Loader2 className="w-12 h-12 text-teal-600 animate-spin" />
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-950 p-6 md:p-12 transition-all duration-500" dir="rtl">
      <div className="max-w-7xl mx-auto space-y-12">
        {/* Top Navigation */}
        <div className="flex items-center justify-between">
          <button 
            onClick={() => router.push("/select-center")}
            className="flex items-center gap-2 text-gray-500 hover:text-teal-600 font-black transition-colors"
          >
            <ArrowLeft className="w-5 h-5 rotate-180" />
            العودة لاختيار المركز
          </button>
          <div className="px-6 py-2 bg-teal-50 dark:bg-teal-900/20 rounded-full text-teal-600 font-black text-xs uppercase tracking-widest">
            إدارة المركز الإدارية 🛠️
          </div>
        </div>

        {/* Header Section */}
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-8 bg-white dark:bg-gray-900 p-10 md:p-16 rounded-[4rem] border border-gray-100 dark:border-gray-800 shadow-2xl relative overflow-hidden">
          <div className="absolute top-0 right-0 w-64 h-64 bg-teal-500/5 rounded-full blur-3xl -mr-32 -mt-32" />
          <div className="relative z-10 space-y-4">
            <div className="flex items-center gap-4">
              <div className="w-16 h-16 bg-teal-600 rounded-3xl flex items-center justify-center shadow-xl shadow-teal-500/20">
                <Building2 className="w-8 h-8 text-white" />
              </div>
              <div>
                <h1 className="text-4xl font-black text-gray-900 dark:text-white tracking-tight">{centerInfo?.name}</h1>
                <p className="text-gray-500 dark:text-gray-400 font-medium">{centerInfo?.address || "إدارة المركز والتحكم في الحلقات والمعلمين"}</p>
              </div>
            </div>
          </div>
          <div className="relative z-10 flex gap-4">
            <button 
              onClick={() => setShowAddTeacherModal(true)}
              className="bg-teal-600 text-white px-8 py-5 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-500/20 transition-all flex items-center gap-3"
            >
              <UserPlus className="w-5 h-5" />
              إضافة معلم للمركز
            </button>
          </div>
        </div>

        <div className="grid lg:grid-cols-3 gap-12">
          {/* Teachers Section */}
          <div className="lg:col-span-2 space-y-8">
            <div className="flex items-center justify-between px-4">
              <h2 className="text-2xl font-black text-gray-900 dark:text-white flex items-center gap-3">
                <Users className="w-7 h-7 text-teal-600" /> قائمة المعلمين
              </h2>
              <span className="bg-gray-100 dark:bg-gray-800 px-4 py-1 rounded-full text-xs font-black text-gray-500">{teachers.length} معلم</span>
            </div>

            <div className="grid gap-6">
              {teachers.map((teacher) => (
                <div key={teacher.id} className="bg-white dark:bg-gray-900 p-8 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-8 group hover:shadow-xl transition-all">
                  <div className="flex items-center gap-6">
                    <div className="w-16 h-16 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center text-gray-400">
                      <Mail className="w-7 h-7" />
                    </div>
                    <div className="space-y-1">
                      <p className="text-sm font-black text-gray-900 dark:text-white">{teacher.email}</p>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest flex items-center gap-2">
                        <BookOpen className="w-3 h-3" /> {teacher.halaqahName || "لم يتم الإسناد بعد"}
                      </p>
                    </div>
                  </div>

                  <div className="flex flex-wrap items-center gap-3">
                    <div className="flex items-center gap-2 bg-gray-50 dark:bg-gray-800 px-4 py-3 rounded-2xl border border-dashed border-gray-200 dark:border-gray-700">
                      <span className="text-[10px] font-black text-gray-400 uppercase tracking-tighter">كود الانضمام:</span>
                      <code className="text-xs font-black text-teal-600 dark:text-teal-400 font-mono tracking-wider">{teacher.invitation_code || "---"}</code>
                      <button 
                        onClick={() => handleCopyCode(teacher.invitation_code || "", teacher.id)}
                        className={`p-1.5 rounded-lg transition-all ${copiedId === teacher.id ? "text-green-600 bg-green-50" : "text-gray-400 hover:text-teal-600 hover:bg-teal-50"}`}
                      >
                        {copiedId === teacher.id ? <Check className="w-3.5 h-3.5" /> : <Copy className="w-3.5 h-3.5" />}
                      </button>
                    </div>

                    <select 
                      value={teacher.halaqahId || ""}
                      onChange={(e) => assignTeacherToHalaqa(teacher.id, e.target.value || null)}
                      className="bg-gray-50 dark:bg-gray-800 px-6 py-3 rounded-2xl text-xs font-black outline-none border-none focus:ring-2 ring-teal-500 transition-all appearance-none"
                    >
                      <option value="">إسناد لحلقة...</option>
                      {halaqat.map(h => (
                        <option key={h.id} value={h.id}>{h.name}</option>
                      ))}
                    </select>

                    <button 
                      onClick={() => removeTeacher(teacher.id)}
                      className="p-3 text-rose-500 hover:bg-rose-50 rounded-xl transition-all"
                    >
                      <Trash2 className="w-5 h-5" />
                    </button>
                  </div>
                </div>
              ))}

              {teachers.length === 0 && (
                <div className="py-20 text-center bg-white dark:bg-gray-900 rounded-[3rem] border-2 border-dashed border-gray-100 dark:border-gray-800">
                  <p className="text-gray-400 font-black">لا يوجد معلمون في هذا المركز حالياً</p>
                </div>
              )}
            </div>
          </div>

          {/* Halaqat Quick Access */}
          <div className="space-y-8">
            <h2 className="text-2xl font-black text-gray-900 dark:text-white flex items-center gap-3">
              <LayoutGrid className="w-7 h-7 text-teal-600" /> الحلقات الحالية
            </h2>
            <div className="grid gap-4">
              {halaqat.map((halaqa) => (
                <div key={halaqa.id} className="bg-white dark:bg-gray-900 p-6 rounded-3xl border border-gray-100 dark:border-gray-800 flex items-center justify-between group hover:border-teal-500 transition-all">
                  <div className="space-y-1">
                    <h3 className="font-black text-gray-900 dark:text-white">{halaqa.name}</h3>
                    <p className="text-[10px] text-gray-400 font-bold">المعلم: {teachers.find(t=>t.halaqahId === halaqa.id)?.email || halaqa.teacher_name || "شاغر"}</p>
                  </div>
                  <div className="flex items-center gap-2">
                    <button 
                      onClick={() => setEditingHalaqa(halaqa)}
                      className="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl text-gray-400 hover:text-teal-600 transition-all"
                    >
                      <Edit2 className="w-4 h-4" />
                    </button>
                    <button 
                      onClick={() => setDeletingHalaqa(halaqa.id)}
                      className="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl text-gray-400 hover:text-rose-500 transition-all"
                    >
                      <Trash2 className="w-4 h-4" />
                    </button>
                    <button 
                      onClick={() => {
                        if (!centerInfo) return;
                        useStore.getState().clearHalaqaData();
                        useStore.getState().setCurrentCenter({ ...centerInfo, activeHalaqa: { id: halaqa.id, name: halaqa.name } });
                        router.push("/");
                      }}
                      className="p-3 bg-gray-50 dark:bg-gray-800 rounded-xl text-gray-400 hover:bg-teal-600 hover:text-white transition-all"
                    >
                      <ExternalLink className="w-5 h-5" />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Add Teacher Modal */}
      {showAddTeacherModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-950 w-full max-w-lg rounded-[3.5rem] p-10 shadow-2xl relative animate-in zoom-in-95 duration-300">
            <div className="flex justify-between items-center mb-10">
              <h2 className="text-2xl font-black text-gray-900 dark:text-white">إضافة معلم جديد</h2>
              <button onClick={() => setShowAddTeacherModal(false)} className="p-3 bg-gray-100 dark:bg-gray-800 rounded-2xl hover:bg-gray-200 transition-colors">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>
            <form onSubmit={handleAddTeacher} className="space-y-8">
              <div className="space-y-4">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mr-2">البريد الإلكتروني</label>
                <div className="relative group">
                  <Mail className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
                  <input 
                    type="email" 
                    required
                    placeholder="teacher@example.com"
                    value={newTeacherEmail}
                    onChange={(e) => setNewTeacherEmail(e.target.value)}
                    className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                  />
                </div>
              </div>
              <button type="submit" className="w-full bg-teal-600 text-white py-6 rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-xl transition-all">إضافة المعلم للمركز</button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function X({ className, ...props }: SVGProps<SVGSVGElement>) {
  return (
    <svg
      {...props}
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </svg>
  );
}
