"use client";

import { useState, useEffect } from "react";
import { 
  Users, 
  UserPlus, 
  Mail, 
  Trash2, 
  ShieldCheck, 
  BookOpen, 
  ArrowRight,
  Search,
  Plus,
  Loader2,
  MoreVertical,
  X,
  UserCheck
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function TeachersPage() {
  const { 
    teachers, fetchTeachers, addTeacher, removeTeacher, 
    halaqat, fetchHalaqat, currentCenter, profile 
  } = useStore();
  
  const [loading, setLoading] = useState(true);
  const [showAddModal, setShowAddModal] = useState(false);
  const [searchQuery, setSearchQuery] = useState("");
  const [newTeacher, setNewTeacher] = useState({
    email: "",
    halaqahId: ""
  });

  useEffect(() => {
    const loadData = async () => {
      setLoading(true);
      await Promise.all([fetchTeachers(), fetchHalaqat()]);
      setLoading(false);
    };
    loadData();
  }, []);

  const handleAddTeacher = async (e: React.FormEvent) => {
    e.preventDefault();
    await addTeacher(newTeacher.email, newTeacher.halaqahId || undefined);
    setNewTeacher({ email: "", halaqahId: "" });
    setShowAddModal(false);
  };

  const filteredTeachers = teachers.filter(t => 
    t.email.toLowerCase().includes(searchQuery.toLowerCase()) ||
    t.halaqahName?.toLowerCase().includes(searchQuery.toLowerCase())
  );

  return (
    <div className="max-w-7xl mx-auto space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center">
              <Users className="w-6 h-6 text-teal-600 dark:text-teal-400" />
            </div>
            <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">إدارة المعلمين 👨‍🏫</h1>
          </div>
          <p className="text-gray-500 dark:text-gray-400 font-medium">قم بإضافة معلمي الحلقات وتعيينهم للحلقات المناسبة.</p>
        </div>

        <button 
          onClick={() => setShowAddModal(true)}
          className="bg-teal-600 text-white px-8 py-4 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-2xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-3 group"
        >
          <UserPlus className="w-5 h-5" />
          إضافة معلم جديد
        </button>
      </div>

      {/* Stats Bar */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <div className="bg-white dark:bg-gray-900 p-8 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-sm flex items-center gap-6">
          <div className="w-16 h-16 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center text-teal-600">
            <UserCheck className="w-8 h-8" />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-black uppercase tracking-widest mb-1">إجمالي المعلمين</p>
            <p className="text-3xl font-black text-gray-900 dark:text-white">{teachers.length}</p>
          </div>
        </div>
        <div className="bg-white dark:bg-gray-900 p-8 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-sm flex items-center gap-6">
          <div className="w-16 h-16 bg-amber-50 dark:bg-amber-900/20 rounded-2xl flex items-center justify-center text-amber-600">
            <BookOpen className="w-8 h-8" />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-black uppercase tracking-widest mb-1">حلقات مفعلة</p>
            <p className="text-3xl font-black text-gray-900 dark:text-white">{halaqat.length}</p>
          </div>
        </div>
        <div className="bg-white dark:bg-gray-900 p-8 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-sm flex items-center gap-6">
          <div className="w-16 h-16 bg-rose-50 dark:bg-rose-900/20 rounded-2xl flex items-center justify-center text-rose-600">
            <ShieldCheck className="w-8 h-8" />
          </div>
          <div>
            <p className="text-gray-400 text-xs font-black uppercase tracking-widest mb-1">بدون حلقة</p>
            <p className="text-3xl font-black text-gray-900 dark:text-white">{teachers.filter(t => !t.halaqahId).length}</p>
          </div>
        </div>
      </div>

      {/* Search and Filters */}
      <div className="relative group">
        <Search className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
        <input 
          type="text" 
          placeholder="ابحث عن معلم بالبريد الإلكتروني أو اسم الحلقة..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className="w-full pr-16 pl-6 py-6 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-[2.5rem] text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 shadow-sm transition-all dark:text-white"
        />
      </div>

      {/* Teachers List */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <Loader2 className="w-10 h-10 text-teal-600 animate-spin" />
          <p className="text-gray-500 font-bold">جاري تحميل بيانات المعلمين...</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {filteredTeachers.map((teacher) => (
            <div key={teacher.id} className="bg-white dark:bg-gray-900 p-8 rounded-[3rem] border border-gray-100 dark:border-gray-800 shadow-sm hover:shadow-xl hover:-translate-y-1 transition-all group relative overflow-hidden">
              <div className="absolute top-0 left-0 w-2 h-full bg-teal-600 opacity-0 group-hover:opacity-100 transition-all" />
              
              <div className="flex justify-between items-start mb-6">
                <div className="w-16 h-16 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center text-gray-400">
                  <Mail className="w-8 h-8" />
                </div>
                <button 
                  onClick={() => {
                    if (confirm("هل أنت متأكد من حذف هذا المعلم؟")) removeTeacher(teacher.id);
                  }}
                  className="p-3 text-rose-500 hover:bg-rose-50 dark:hover:bg-rose-900/20 rounded-xl transition-all opacity-0 group-hover:opacity-100"
                >
                  <Trash2 className="w-5 h-5" />
                </button>
              </div>

              <div className="space-y-4">
                <div>
                  <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest mb-1">البريد الإلكتروني</p>
                  <p className="text-sm font-black text-gray-900 dark:text-white break-all">{teacher.email}</p>
                </div>

                <div className="pt-4 border-t border-gray-50 dark:border-gray-800">
                  <div className="flex items-center gap-3">
                    <div className={`w-8 h-8 rounded-lg flex items-center justify-center ${teacher.halaqahId ? "bg-teal-50 dark:bg-teal-900/20 text-teal-600" : "bg-gray-50 dark:bg-gray-800 text-gray-400"}`}>
                      <BookOpen className="w-4 h-4" />
                    </div>
                    <div>
                      <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest">الحلقة المسندة</p>
                      <p className={`text-xs font-black ${teacher.halaqahId ? "text-gray-900 dark:text-white" : "text-gray-400 italic"}`}>
                        {teacher.halaqahName || "غير محدد"}
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          ))}

          {filteredTeachers.length === 0 && (
            <div className="col-span-full py-20 text-center bg-gray-50 dark:bg-gray-900/50 rounded-[3rem] border-2 border-dashed border-gray-200 dark:border-gray-800">
              <div className="w-20 h-20 bg-gray-100 dark:bg-gray-800 rounded-[2.5rem] flex items-center justify-center mx-auto mb-6">
                <Users className="w-10 h-10 text-gray-300" />
              </div>
              <h3 className="text-xl font-black text-gray-900 dark:text-white mb-2">لا يوجد معلمون حالياً</h3>
              <p className="text-gray-500 font-medium">ابدأ بإضافة المعلمين لمركزك وتوزيعهم على الحلقات.</p>
            </div>
          )}
        </div>
      )}

      {/* Add Teacher Modal */}
      {showAddModal && (
        <div className="fixed inset-0 bg-black/60 backdrop-blur-sm z-50 flex items-center justify-center p-6 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-950 w-full max-w-lg rounded-[3.5rem] p-10 shadow-2xl relative animate-in zoom-in-95 duration-300 overflow-hidden">
            <div className="absolute top-0 right-0 w-32 h-32 bg-teal-500/10 rounded-full blur-3xl -mr-16 -mt-16" />
            
            <div className="flex justify-between items-center mb-10 relative">
              <h2 className="text-2xl font-black text-gray-900 dark:text-white flex items-center gap-4">
                <UserPlus className="w-8 h-8 text-teal-600" /> إضافة معلم جديد
              </h2>
              <button onClick={() => setShowAddModal(false)} className="p-3 bg-gray-100 dark:bg-gray-800 rounded-2xl hover:bg-gray-200 transition-colors">
                <X className="w-5 h-5 text-gray-500" />
              </button>
            </div>

            <form onSubmit={handleAddTeacher} className="space-y-8 relative">
              <div className="space-y-6">
                <div>
                  <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3 mr-2">البريد الإلكتروني للمعلم</label>
                  <div className="relative group">
                    <Mail className="absolute right-6 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400 group-focus-within:text-teal-600 transition-colors" />
                    <input 
                      type="email" 
                      required
                      placeholder="teacher@example.com"
                      value={newTeacher.email}
                      onChange={(e) => setNewTeacher({...newTeacher, email: e.target.value})}
                      className="w-full pr-14 pl-6 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3 mr-2">تحديد الحلقة (اختياري)</label>
                  <select 
                    value={newTeacher.halaqahId}
                    onChange={(e) => setNewTeacher({...newTeacher, halaqahId: e.target.value})}
                    className="w-full px-8 py-5 bg-gray-50 dark:bg-gray-900 border-none rounded-[2rem] text-sm font-bold outline-none focus:ring-4 ring-teal-500/10 dark:text-white transition-all appearance-none"
                  >
                    <option value="">-- اختر حلقة مسندة --</option>
                    {halaqat.map(h => (
                      <option key={h.id} value={h.id}>{h.name}</option>
                    ))}
                  </select>
                </div>
              </div>

              <div className="flex gap-4 pt-4">
                <button 
                  type="submit"
                  className="flex-1 bg-teal-600 text-white py-6 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-500/20 transition-all flex items-center justify-center gap-3 group"
                >
                  إرسال الدعوة
                  <ArrowRight className="w-5 h-5 group-hover:-translate-x-2 transition-transform" />
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
