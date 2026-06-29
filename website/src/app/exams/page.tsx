"use client";

import { useState, useMemo, useEffect } from "react";
import { 
  FileText, 
  Plus, 
  Save, 
  X, 
  Search, 
  CheckCircle, 
  Clock, 
  Edit2, 
  Trophy,
  GraduationCap,
  CalendarDays,
  Target
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function ExamsPage() {
  const { students, exams, addExam, updateExamScore, fetchCenterData } = useStore();
  const [showForm, setShowForm] = useState(false);
  const [showScores, setShowScores] = useState<string | null>(null);
  const [formData, setFormData] = useState({ title: "", type: "oral" as "oral" | "written", maxDegree: 100, date: "" });
  const [scoreData, setScoreData] = useState<{ studentId: string; degree: number; notes: string }[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchCenterData();
  }, [fetchCenterData]);

  const handleCreateExam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (saving) return;
    const title = formData.title.trim();
    if (!title) {
      alert("الرجاء إدخال اسم الاختبار");
      return;
    }
    const maxDegree = Number.isFinite(formData.maxDegree) && formData.maxDegree > 0
      ? formData.maxDegree
      : 100;
    setSaving(true);
    try {
      await addExam({
        title,
        type: formData.type,
        maxDegree,
        date: formData.date || new Date().toISOString().split("T")[0],
        studentScores: [],
      });
      setShowForm(false);
      setFormData({ title: "", type: "oral", maxDegree: 100, date: "" });
    } finally {
      setSaving(false);
    }
  };

  const handleOpenScores = (examId: string) => {
    const exam = exams.find(e => e.id === examId);
    if (exam) {
      const existingScores = exam.studentScores;
      setScoreData(students.map(s => {
        const existing = existingScores.find(es => es.studentId === s.id);
        return existing || { studentId: s.id, degree: 0, notes: "" };
      }));
      setShowScores(examId);
    }
  };

  const handleSaveScores = async () => {
    if (!showScores) return;
    for (const score of scoreData) {
      await updateExamScore(showScores, score.studentId, score.degree, score.notes);
    }
    setShowScores(null);
  };

  const stats = useMemo(() => {
    const totalExams = exams.length;
    const allScores = exams.flatMap(e => e.studentScores.filter(s => s.degree > 0));
    const avgDegree = allScores.length > 0 
      ? (allScores.reduce((sum, s) => sum + s.degree, 0) / allScores.length).toFixed(1)
      : "0.0";
    return { totalExams, avgDegree };
  }, [exams]);

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">سجل الامتحانات والاختبارات 🏆</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">وثق نتائج اختبارات طلابك وراقب مستوياتهم العلمية.</p>
        </div>
        <button 
          onClick={() => setShowForm(true)}
          className="bg-teal-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2 group"
        >
          <Plus className="w-5 h-5 group-hover:rotate-90 transition-transform" />
          إضافة امتحان جديد
        </button>
      </div>

      {/* Stats Cards */}
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8">
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-8 flex items-center gap-6 shadow-sm">
          <div className="w-16 h-16 bg-rose-50 dark:bg-rose-900/20 rounded-2xl flex items-center justify-center">
            <FileText className="w-8 h-8 text-rose-600 dark:text-rose-400" />
          </div>
          <div>
            <p className="text-3xl font-black text-gray-900 dark:text-white">{stats.totalExams}</p>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">إجمالي الامتحانات</p>
          </div>
        </div>
        
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-8 flex items-center gap-6 shadow-sm">
          <div className="w-16 h-16 bg-amber-50 dark:bg-amber-900/20 rounded-2xl flex items-center justify-center">
            <Trophy className="w-8 h-8 text-amber-600 dark:text-amber-400" />
          </div>
          <div>
            <p className="text-3xl font-black text-gray-900 dark:text-white">{stats.avgDegree}</p>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">متوسط الدرجات</p>
          </div>
        </div>
      </div>

      {/* Exams Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        {exams.length === 0 ? (
          <div className="md:col-span-2 bg-white/40 dark:bg-gray-900/40 backdrop-blur-md rounded-[3.5rem] border-2 border-dashed border-gray-200 dark:border-gray-800 p-20 text-center">
            <div className="w-20 h-20 bg-gray-50 dark:bg-gray-800 rounded-full flex items-center justify-center mx-auto mb-4">
              <FileText className="w-10 h-10 text-gray-200 dark:text-gray-700" />
            </div>
            <p className="text-gray-400 font-black">لا توجد سجلات امتحانات حالياً</p>
          </div>
        ) : (
          exams.map(exam => {
            const completedScores = exam.studentScores.filter(s => s.degree > 0).length;
            const progress = (completedScores / students.length) * 100;
            return (
              <div key={exam.id} className="group bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 p-8 hover:shadow-2xl hover:shadow-gray-200/50 dark:hover:shadow-none transition-all duration-500">
                <div className="flex items-start justify-between mb-8">
                  <div className="space-y-1">
                    <h4 className="text-xl font-black text-gray-900 dark:text-white group-hover:text-teal-600 dark:group-hover:text-teal-400 transition-colors">{exam.title}</h4>
                    <div className="flex items-center gap-3">
                      <span className={`text-[10px] font-black uppercase tracking-widest px-3 py-1 rounded-full ${
                        exam.type === "oral" ? "bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400" : "bg-purple-50 dark:bg-purple-900/20 text-purple-600 dark:text-purple-400"
                      }`}>
                        اختبار {exam.type === "oral" ? "شفهي" : "تحريري"}
                      </span>
                      <span className="text-[10px] font-bold text-gray-400 dark:text-gray-500 flex items-center gap-1">
                        <CalendarDays className="w-3 h-3" /> {exam.date}
                      </span>
                    </div>
                  </div>
                  <div className="w-12 h-12 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center text-gray-400 dark:text-gray-500 font-black">
                    {exam.maxDegree}
                  </div>
                </div>

                <div className="space-y-4">
                  <div className="flex justify-between items-end mb-1">
                    <span className="text-[10px] font-black text-gray-400 uppercase tracking-widest">نسبة الرصد</span>
                    <span className="text-xs font-black text-gray-900 dark:text-white">{Math.round(progress)}%</span>
                  </div>
                  <div className="h-2 w-full bg-gray-50 dark:bg-gray-800 rounded-full overflow-hidden">
                    <div 
                      className="h-full bg-teal-500 rounded-full transition-all duration-1000" 
                      style={{ width: `${progress}%` }} 
                    />
                  </div>
                </div>

                <button 
                  onClick={() => handleOpenScores(exam.id)}
                  className="w-full mt-8 py-4 bg-gray-900 dark:bg-teal-600 text-white rounded-2xl text-xs font-black hover:bg-teal-600 dark:hover:bg-teal-500 transition-all shadow-xl shadow-gray-200 dark:shadow-none group-hover:-translate-y-1"
                >
                  {completedScores > 0 ? "تعديل رصد الدرجات" : "ابدأ رصد الدرجات"}
                </button>
              </div>
            );
          })
        )}
      </div>

      {/* Create Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative animate-in zoom-in-95 duration-300" onClick={(e) => e.stopPropagation()}>
            <button onClick={() => setShowForm(false)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
              <X className="w-6 h-6 text-gray-400" />
            </button>
            
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8">إضافة امتحان جديد</h3>
            
            <form onSubmit={handleCreateExam} className="space-y-6">
              <div>
                <label className="block text-xs font-black text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2">عنوان الامتحان</label>
                <input 
                  type="text" 
                  value={formData.title} 
                  onChange={(e) => setFormData({ ...formData, title: e.target.value })} 
                  required 
                  placeholder="مثال: مراجعة جزء عم..."
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold text-gray-700 dark:text-gray-200 outline-none" 
                />
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-black text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2">نوع الاختبار</label>
                  <select 
                    value={formData.type} 
                    onChange={(e) => setFormData({ ...formData, type: e.target.value as "oral" | "written" })}
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold text-gray-700 dark:text-gray-200 outline-none"
                  >
                    <option value="oral">شفهي</option>
                    <option value="written">تحريري</option>
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-black text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2">الدرجة القصوى</label>
                  <input 
                    type="number" 
                    value={Number.isFinite(formData.maxDegree) ? formData.maxDegree : ""} 
                    onChange={(e) => {
                      const v = parseInt(e.target.value, 10);
                      setFormData({ ...formData, maxDegree: Number.isNaN(v) ? NaN : v });
                    }} 
                    min={1}
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold text-gray-700 dark:text-gray-200 outline-none" 
                  />
                </div>
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 dark:text-gray-500 uppercase tracking-widest mb-2">تاريخ الامتحان</label>
                <input 
                  type="date" 
                  value={formData.date} 
                  onChange={(e) => setFormData({ ...formData, date: e.target.value })} 
                  required
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold text-gray-700 dark:text-gray-200 outline-none" 
                />
              </div>
              <button type="submit" disabled={saving} className="w-full bg-teal-600 text-white py-5 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all disabled:opacity-50 disabled:cursor-not-allowed">
                {saving ? "جاري الحفظ..." : "إنشاء السجل"}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* Scores Modal */}
      {showScores && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-2xl max-h-[85vh] overflow-hidden flex flex-col shadow-2xl relative animate-in zoom-in-95 duration-300" onClick={(e) => e.stopPropagation()}>
            <button onClick={() => setShowScores(null)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors">
              <X className="w-6 h-6 text-gray-400" />
            </button>
            
            <div className="mb-10">
              <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-1">رصد درجات الطلاب</h3>
              <p className="text-xs font-bold text-gray-400 dark:text-gray-500 uppercase tracking-widest">
                امتحان: {exams.find(e => e.id === showScores)?.title}
              </p>
            </div>

            <div className="flex-1 overflow-y-auto space-y-4 pr-2">
              {scoreData.map(score => {
                const student = students.find(s => s.id === score.studentId);
                const exam = exams.find(e => e.id === showScores);
                return (
                  <div key={score.studentId} className="group bg-gray-50 dark:bg-gray-800/50 rounded-3xl p-5 flex items-center gap-6 hover:bg-white dark:hover:bg-gray-800 hover:shadow-xl hover:shadow-gray-100 dark:hover:shadow-none transition-all duration-300 border border-transparent hover:border-gray-100 dark:hover:border-gray-700">
                    <div className="w-14 h-14 bg-white dark:bg-gray-800 rounded-2xl flex items-center justify-center font-black text-gray-400 dark:text-gray-500 group-hover:bg-teal-600 group-hover:text-white transition-all shadow-sm">
                      {student?.name[0]}
                    </div>
                    <div className="flex-1">
                      <p className="font-black text-gray-800 dark:text-white text-sm">{student?.name}</p>
                      <p className="text-[10px] text-gray-400 dark:text-gray-500 font-bold mt-1">الرقم: {student?.id}</p>
                    </div>
                    <div className="flex items-center gap-4">
                      <input 
                        type="number" 
                        value={score.degree} 
                        onChange={(e) => setScoreData(scoreData.map(s => s.studentId === score.studentId ? { ...s, degree: parseInt(e.target.value) } : s))}
                        min={0} 
                        max={exam?.maxDegree || 100} 
                        className="w-24 bg-white dark:bg-gray-900 border-none rounded-xl px-4 py-3 text-center font-black text-teal-600 dark:text-teal-400 shadow-sm outline-none focus:ring-2 ring-teal-500/20" 
                      />
                      <span className="text-[10px] font-black text-gray-300 dark:text-gray-600 uppercase tracking-widest">/ {exam?.maxDegree}</span>
                    </div>
                  </div>
                );
              })}
            </div>

            <button 
              onClick={handleSaveScores} 
              className="w-full mt-10 bg-teal-600 text-white py-5 rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all shrink-0"
            >
              حفظ وتأكيد الدرجات
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
