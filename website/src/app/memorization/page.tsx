"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  BookOpen, 
  Plus, 
  Save, 
  X, 
  Search, 
  Star, 
  History, 
  Sparkles, 
  Filter,
  ArrowUpRight,
  Target,
  Lightbulb
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { quranService, Surah } from "@/services/quranService";

export default function MemorizationPage() {
  const { students, memorization, addMemorization, loading } = useStore();
  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [studentFilter, setStudentFilter] = useState("");

  const [formData, setFormData] = useState({
    studentId: "",
    surahNum: "" as number | "",
    fromAyah: 1,
    toAyah: 1,
    degree: 5,
    notes: ""
  });

  useEffect(() => {
    quranService.initialize().then(() => {
      setSurahs(quranService.getSurahs());
    });
  }, []);

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.studentId || !formData.surahNum) return;
    
    const surah = surahs.find(s => s.number === formData.surahNum);
    await addMemorization({
      studentId: formData.studentId,
      surah: surah?.name || "",
      fromAyah: formData.fromAyah,
      toAyah: formData.toAyah,
      date: new Date().toISOString().split("T")[0],
      degree: formData.degree,
      notes: formData.notes,
    });
    
    setShowForm(false);
    setFormData({ studentId: "", surahNum: "", fromAyah: 1, toAyah: 1, degree: 5, notes: "" });
  };

  const filteredMemorization = useMemo(() => {
    return memorization
      .filter(m => !studentFilter || m.studentId === studentFilter)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [memorization, studentFilter]);

  const stats = useMemo(() => {
    const count = filteredMemorization.length;
    const avg = count > 0 
      ? (filteredMemorization.reduce((sum, m) => sum + m.degree, 0) / count).toFixed(1)
      : "0.0";
    return { count, avg };
  }, [filteredMemorization]);

  const getStudentName = (id: string) => students.find(s => s.id === id)?.name || "طالب محذوف";

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">سجل الحفظ والمراجعة 📖</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">تابع تقدم طلابك في حفظ كتاب الله بدقة وعناية.</p>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-10">
        {/* Sidebar Info */}
        <div className="space-y-8 flex flex-col items-start order-2 lg:order-1">
          <button 
            onClick={() => setShowForm(true)}
            className="w-full bg-teal-600 text-white px-8 py-5 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2 group"
          >
            <Plus className="w-5 h-5 group-hover:rotate-90 transition-transform" />
            تسجيل جلسة جديدة
          </button>

          <div className="w-full bg-gradient-to-br from-orange-600 to-orange-400 rounded-[3rem] p-10 text-white shadow-xl relative overflow-hidden group">
            <h3 className="text-xl font-black mb-8 relative z-10 flex items-center gap-2">
              إحصائيات الحفظ 📊
            </h3>
            <div className="grid grid-cols-2 gap-4 relative z-10">
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.avg}</p>
                <p className="text-[10px] font-bold text-orange-100 uppercase mt-1">متوسط التقييم</p>
              </div>
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.count}</p>
                <p className="text-[10px] font-bold text-orange-100 uppercase mt-1">جلسة مسجلة</p>
              </div>
            </div>
            <Sparkles className="absolute -bottom-10 -right-10 w-40 h-40 text-white/10" />
          </div>

          <div className="w-full bg-cyan-50/50 dark:bg-cyan-900/10 border border-cyan-100 dark:border-cyan-800 rounded-[3rem] p-8 flex flex-col gap-4">
            <div className="w-12 h-12 bg-white dark:bg-gray-800 rounded-2xl flex items-center justify-center shadow-sm">
              <Lightbulb className="w-6 h-6 text-cyan-600" />
            </div>
            <div>
              <h4 className="text-sm font-black text-gray-900 dark:text-white mb-2">نصيحة للمشرف 💡</h4>
              <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed font-medium">
                عند تسجيل الحفظ، تأكد من كتابة ملاحظات دقيقة حول جودة الأداء (مثل التجويد أو مخارج الحروف) لمساعدتك في التقارير الشهرية.
              </p>
            </div>
          </div>
        </div>

        {/* Main Records List */}
        <div className="lg:col-span-2 space-y-6 order-1 lg:order-2">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-black text-gray-900 dark:text-white">آخر التسجيلات</h2>
            <div className="flex items-center gap-3 bg-white dark:bg-gray-900 px-4 py-2 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm">
              <Filter className="w-4 h-4 text-gray-400" />
              <select 
                value={studentFilter} 
                onChange={(e) => setStudentFilter(e.target.value)}
                className="text-xs font-bold text-gray-600 outline-none bg-transparent"
              >
                <option value="">كل الطلاب</option>
                {students.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
          </div>

          <div className="bg-white/40 dark:bg-gray-900/40 backdrop-blur-md rounded-[3.5rem] border-2 border-dashed border-gray-200 dark:border-gray-800 p-24 text-center flex flex-col items-center justify-center space-y-4">
            <div className="w-20 h-20 bg-gray-50 dark:bg-gray-800 rounded-full flex items-center justify-center">
              <BookOpen className="w-10 h-10 text-gray-200" />
            </div>
            <p className="text-sm font-bold text-gray-400">لا يوجد سجلات حفظ حالياً</p>
          </div>
        </div>
      </div>

      {/* Entry Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-xl shadow-2xl relative overflow-y-auto max-h-[90vh]">
            <button onClick={() => setShowForm(false)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><X className="w-6 h-6 text-gray-400" /></button>
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8 text-center">تسجيل جلسة حفظ جديدة</h3>
            <form onSubmit={handleSave} className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="md:col-span-2">
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">الطالب</label>
                <select value={formData.studentId} onChange={e => setFormData({...formData, studentId: e.target.value})} required className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none">
                  <option value="">اختر الطالب</option>
                  {students.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">السورة</label>
                <select 
                  value={formData.surahNum} 
                  onChange={e => {
                    const num = parseInt(e.target.value);
                    const s = surahs.find(x => x.number === num);
                    setFormData({...formData, surahNum: num, toAyah: s?.totalAyahs || 1});
                  }} 
                  required 
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                >
                  <option value="">اختر السورة</option>
                  {surahs.map(s => <option key={s.number} value={s.number}>{s.name}</option>)}
                </select>
              </div>
              <div className="flex gap-4">
                <div className="flex-1">
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">من آية</label>
                  <select 
                    value={formData.fromAyah} 
                    onChange={e => {
                      const val = parseInt(e.target.value);
                      setFormData({...formData, fromAyah: val, toAyah: Math.max(val, formData.toAyah)});
                    }} 
                    required 
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 text-sm font-bold outline-none"
                  >
                    {Array.from({ length: surahs.find(s => s.number === formData.surahNum)?.totalAyahs || 0 }, (_, i) => i + 1).map(n => (
                      <option key={n} value={n}>{n}</option>
                    ))}
                  </select>
                </div>
                <div className="flex-1">
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">إلى آية</label>
                  <select 
                    value={formData.toAyah} 
                    onChange={e => setFormData({...formData, toAyah: parseInt(e.target.value)})} 
                    required 
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 text-sm font-bold outline-none"
                  >
                    {Array.from({ length: surahs.find(s => s.number === formData.surahNum)?.totalAyahs || 0 }, (_, i) => i + 1)
                      .filter(n => n >= formData.fromAyah)
                      .map(n => (
                      <option key={n} value={n}>{n}</option>
                    ))}
                  </select>
                </div>
              </div>
              <div className="md:col-span-2">
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">التقييم ({formData.degree}/5)</label>
                <input type="range" min={1} max={5} value={formData.degree} onChange={e => setFormData({...formData, degree: parseInt(e.target.value)})} className="w-full accent-teal-600" />
              </div>
              <div className="md:col-span-2">
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">ملاحظات</label>
                <textarea value={formData.notes} onChange={e => setFormData({...formData, notes: e.target.value})} rows={2} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" />
              </div>
              <button type="submit" className="md:col-span-2 bg-teal-600 text-white py-5 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl transition-all">حفظ الجلسة</button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}