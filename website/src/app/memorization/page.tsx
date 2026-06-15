"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  BookOpen, 
  Plus, 
  X, 
  Sparkles, 
  Filter,
  Lightbulb,
  Share2,
  Copy,
  PlusCircle,
  MinusCircle,
  MessageCircle,
  CheckCircle,
  AlertCircle
} from "lucide-react";
import { useStore, HomeworkGrade } from "@/store/useStore";
import { quranService, Surah } from "@/services/quranService";

const DEFAULT_GRADING_TEMPLATE = "السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}";

export default function MemorizationPage() {
  const { 
    students, 
    homeworkGrades, 
    addHomeworkGrade, 
    fetchHomeworkGrades, 
    fetchStudents, 
    messageTemplates, 
    fetchMessageTemplates,
    loading 
  } = useStore();

  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [studentFilter, setStudentFilter] = useState("");
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    studentId: "",
    surahNum: "" as number | "",
    fromAyah: 1,
    toAyah: 1,
    gradeMark: "excellent" as HomeworkGrade["gradeMark"],
    mistakesCount: 0,
    isRevision: false,
    remark: ""
  });

  useEffect(() => {
    quranService.initialize().then(() => {
      setSurahs(quranService.getSurahs());
    });
    fetchStudents();
    fetchHomeworkGrades();
    fetchMessageTemplates();
  }, [fetchStudents, fetchHomeworkGrades, fetchMessageTemplates]);

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  const selectedSurah = useMemo(() => {
    if (!formData.surahNum) return undefined;
    return surahs.find(s => s.number === formData.surahNum);
  }, [formData.surahNum, surahs]);

  const getTemplateText = (type: "assignment" | "grading") => {
    const template = messageTemplates.find(t => t.type === type);
    return template ? template.content : DEFAULT_GRADING_TEMPLATE;
  };

  const generateReportMessage = (grade: Omit<HomeworkGrade, "id">) => {
    const student = students.find(s => s.id === grade.studentId);
    const studentName = student?.name || "";
    const templateText = getTemplateText("grading");
    
    const gradeTranslation: Record<string, string> = {
      excellent: "ممتاز ⭐⭐⭐⭐⭐",
      very_good: "جيد جداً ⭐⭐⭐⭐",
      good: "جيد ⭐⭐⭐",
      needs_work: "يحتاج تركيز ⭐⭐",
      absent: "غائب ❌",
    };

    return templateText
      .replace(/{اسم_الطالب}/g, studentName)
      .replace(/{السورة}/g, grade.surah)
      .replace(/{من}/g, String(grade.fromAyah))
      .replace(/{إلى}/g, String(grade.toAyah))
      .replace(/{التقييم}/g, gradeTranslation[grade.gradeMark] || grade.gradeMark)
      .replace(/{الأخطاء}/g, String(grade.mistakesCount))
      .replace(/{الملاحظة}/g, grade.remark || "لا يوجد");
  };

  const handleSave = async (e: React.FormEvent, shouldShare = false) => {
    e.preventDefault();
    if (!formData.studentId || !formData.surahNum) return;

    const surah = surahs.find(s => s.number === formData.surahNum);
    const newGrade = {
      studentId: formData.studentId,
      surah: surah?.name || "",
      fromAyah: formData.fromAyah,
      toAyah: formData.toAyah,
      date: new Date().toISOString().split("T")[0],
      gradeMark: formData.gradeMark,
      mistakesCount: formData.mistakesCount,
      isRevision: formData.isRevision,
      remark: formData.remark,
    };

    await addHomeworkGrade(newGrade);

    if (shouldShare) {
      const msg = generateReportMessage(newGrade);
      const student = students.find(s => s.id === formData.studentId);
      const parentPhone = student?.parentPhone || "";

      if (navigator.share) {
        try {
          await navigator.share({
            title: `تقرير تسميع ${student?.name}`,
            text: msg,
          });
          showToast("تمت المشاركة بنجاح");
        } catch (err) {
          // Fallback to clipboard if sharing is cancelled or fails
          navigator.clipboard.writeText(msg);
          showToast("تم نسخ التقرير للحافظة");
          if (parentPhone) {
            window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
          }
        }
      } else {
        navigator.clipboard.writeText(msg);
        showToast("تم نسخ التقرير للحافظة");
        if (parentPhone) {
          window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
        }
      }
    } else {
      showToast("تم حفظ التقييم بنجاح");
    }

    setShowForm(false);
    setFormData({
      studentId: "",
      surahNum: "",
      fromAyah: 1,
      toAyah: 1,
      gradeMark: "excellent",
      mistakesCount: 0,
      isRevision: false,
      remark: ""
    });
  };

  const handleShareExisting = (grade: HomeworkGrade) => {
    const msg = generateReportMessage(grade);
    const student = students.find(s => s.id === grade.studentId);
    const parentPhone = student?.parentPhone || "";

    if (navigator.clipboard) {
      navigator.clipboard.writeText(msg);
      showToast("تم نسخ التقرير للحافظة");
    }
    
    if (parentPhone) {
      window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
    }
  };

  const filteredGrades = useMemo(() => {
    return homeworkGrades
      .filter(m => !studentFilter || m.studentId === studentFilter)
      .sort((a, b) => new Date(b.date).getTime() - new Date(a.date).getTime());
  }, [homeworkGrades, studentFilter]);

  const stats = useMemo(() => {
    const count = filteredGrades.length;
    if (count === 0) return { count, avg: "0.0" };

    const scoreMap: Record<string, number> = {
      excellent: 5,
      very_good: 4,
      good: 3,
      needs_work: 2,
      absent: 0
    };

    const gradedRecords = filteredGrades.filter(g => g.gradeMark !== "absent");
    if (gradedRecords.length === 0) return { count, avg: "0.0" };

    const sum = gradedRecords.reduce((acc, curr) => acc + scoreMap[curr.gradeMark], 0);
    const avg = (sum / gradedRecords.length).toFixed(1);
    return { count, avg };
  }, [filteredGrades]);

  const getStudentName = (id: string) => students.find(s => s.id === id)?.name || "طالب محذوف";

  const gradeBadges: Record<string, { label: string; style: string }> = {
    excellent: { label: "ممتاز", style: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400" },
    very_good: { label: "جيد جداً", style: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400" },
    good: { label: "جيد", style: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400" },
    needs_work: { label: "مقبول", style: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400" },
    absent: { label: "غائب", style: "bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-400" }
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20 relative">
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-10 left-10 z-50 bg-gray-900 text-white px-6 py-4 rounded-2xl shadow-2xl flex items-center gap-3 animate-in fade-in slide-in-from-left-4">
          <CheckCircle className="w-5 h-5 text-emerald-400" />
          <span className="font-bold text-xs">{toastMessage}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">سجل التقييم والتسميع المطور 📖</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">نظام التقييم التفصيلي بخمسة مستويات، ومتابعة الأخطاء والمشاركة مع أولياء الأمور.</p>
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
            تسجيل تقييم جديد
          </button>

          <div className="w-full bg-gradient-to-br from-teal-600 to-teal-400 rounded-[3rem] p-10 text-white shadow-xl relative overflow-hidden group">
            <h3 className="text-xl font-black mb-8 relative z-10 flex items-center gap-2">
              إحصائيات التقييم 📊
            </h3>
            <div className="grid grid-cols-2 gap-4 relative z-10">
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.avg}</p>
                <p className="text-[10px] font-bold text-teal-100 uppercase mt-1">معدل الدرجات</p>
              </div>
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.count}</p>
                <p className="text-[10px] font-bold text-teal-100 uppercase mt-1">تسميع مسجل</p>
              </div>
            </div>
            <Sparkles className="absolute -bottom-10 -right-10 w-40 h-40 text-white/10" />
          </div>

          <div className="w-full bg-cyan-50/50 dark:bg-cyan-900/10 border border-cyan-100 dark:border-cyan-800 rounded-[3rem] p-8 flex flex-col gap-4">
            <div className="w-12 h-12 bg-white dark:bg-gray-800 rounded-2xl flex items-center justify-center shadow-sm">
              <Lightbulb className="w-6 h-6 text-teal-600" />
            </div>
            <div>
              <h4 className="text-sm font-black text-gray-900 dark:text-white mb-2">مشاركة أولياء الأمور 💬</h4>
              <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed font-medium">
                بإمكانك إرسال التقرير اليومي لولي الأمر مباشرة عبر واتساب بضغطة زر. يمكنك تخصيص قالب الرسائل في صفحة الإعدادات لتغيير صيغة الخطاب.
              </p>
            </div>
          </div>
        </div>

        {/* Main Records List */}
        <div className="lg:col-span-2 space-y-6 order-1 lg:order-2">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-black text-gray-900 dark:text-white">آخر التقييمات</h2>
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

          {filteredGrades.length === 0 ? (
            <div className="bg-white/40 dark:bg-gray-900/40 backdrop-blur-md rounded-[3.5rem] border-2 border-dashed border-gray-200 dark:border-gray-800 p-24 text-center flex flex-col items-center justify-center space-y-4">
              <div className="w-20 h-20 bg-gray-50 dark:bg-gray-800 rounded-full flex items-center justify-center">
                <BookOpen className="w-10 h-10 text-gray-300" />
              </div>
              <p className="text-sm font-bold text-gray-400">لا يوجد تقييمات مسجلة حالياً</p>
            </div>
          ) : (
            <div className="grid gap-6">
              {filteredGrades.map((grade) => {
                const badge = gradeBadges[grade.gradeMark];
                return (
                  <div 
                    key={grade.id} 
                    className="bg-white dark:bg-gray-900 rounded-3xl p-6 border border-gray-100 dark:border-gray-850 hover:border-teal-500/30 transition-all flex flex-col md:flex-row justify-between md:items-center gap-4 group"
                  >
                    <div className="space-y-3">
                      <div className="flex items-center gap-3">
                        <span className="font-black text-base text-gray-900 dark:text-white">
                          {getStudentName(grade.studentId)}
                        </span>
                        <span className={`text-[10px] px-3 py-1 rounded-full font-black ${badge.style}`}>
                          {badge.label}
                        </span>
                        <span className={`text-[10px] px-3 py-1 rounded-full font-black ${
                          grade.isRevision 
                            ? "bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400" 
                            : "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
                        }`}>
                          {grade.isRevision ? "مراجعة" : "حفظ جديد"}
                        </span>
                      </div>
                      
                      <div className="text-xs font-bold text-gray-500 dark:text-gray-400 flex flex-wrap items-center gap-x-4 gap-y-1">
                        <span>📖 سورة {grade.surah} ({grade.fromAyah} - {grade.toAyah})</span>
                        {grade.gradeMark !== "absent" && (
                          <span className={grade.mistakesCount > 0 ? "text-rose-500 font-bold" : ""}>
                            ⚠️ الأخطاء: {grade.mistakesCount}
                          </span>
                        )}
                        <span>📅 {grade.date}</span>
                      </div>

                      {grade.remark && (
                        <p className="text-xs bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 px-4 py-2 rounded-xl border-r-4 border-teal-500">
                          {grade.remark}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-2 self-end md:self-center">
                      <button 
                        onClick={() => handleShareExisting(grade)}
                        className="bg-teal-50 hover:bg-teal-100 text-teal-700 dark:bg-teal-900/20 dark:hover:bg-teal-900/40 dark:text-teal-400 p-3 rounded-2xl text-xs font-bold flex items-center gap-2 transition-colors"
                        title="مشاركة عبر واتساب"
                      >
                        <MessageCircle className="w-4 h-4" />
                        <span>مشاركة</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Entry Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-xl shadow-2xl relative overflow-y-auto max-h-[90vh] border border-gray-100 dark:border-gray-800">
            <button 
              onClick={() => setShowForm(false)} 
              className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
            >
              <X className="w-6 h-6 text-gray-400" />
            </button>
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8 text-center">تسجيل تقييم جديد</h3>
            
            <form onSubmit={(e) => handleSave(e, false)} className="space-y-6">
              {/* Student */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">الطالب</label>
                <select 
                  value={formData.studentId} 
                  onChange={e => setFormData({...formData, studentId: e.target.value})} 
                  required 
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                >
                  <option value="">اختر الطالب</option>
                  {students.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>

              {/* Type Chip selector */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">نوع التسميع</label>
                <div className="grid grid-cols-2 gap-4">
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, isRevision: false })}
                    className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                      !formData.isRevision 
                        ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                        : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                    }`}
                  >
                    حفظ جديد
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, isRevision: true })}
                    className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                      formData.isRevision 
                        ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                        : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                    }`}
                  >
                    مراجعة
                  </button>
                </div>
              </div>

              {/* Surah and Ayah Selection */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">السورة</label>
                  <select 
                    value={formData.surahNum} 
                    onChange={e => {
                      const num = parseInt(e.target.value);
                      const s = surahs.find(x => x.number === num);
                      setFormData({...formData, surahNum: num, fromAyah: 1, toAyah: s?.totalAyahs || 1});
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
                      {Array.from({ length: selectedSurah?.totalAyahs || 0 }, (_, i) => i + 1).map(n => (
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
                      {Array.from({ length: selectedSurah?.totalAyahs || 0 }, (_, i) => i + 1)
                        .filter(n => n >= formData.fromAyah)
                        .map(n => (
                        <option key={n} value={n}>{n}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              {/* 5-Level Grade Mark */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">التقييم</label>
                <div className="grid grid-cols-5 gap-2">
                  {[
                    { key: "excellent", label: "ممتاز", style: "bg-emerald-500 hover:bg-emerald-600 text-white" },
                    { key: "very_good", label: "جيد جداً", style: "bg-green-500 hover:bg-green-600 text-white" },
                    { key: "good", label: "جيد", style: "bg-amber-500 hover:bg-amber-600 text-white" },
                    { key: "needs_work", label: "مقبول", style: "bg-orange-500 hover:bg-orange-600 text-white" },
                    { key: "absent", label: "غائب", style: "bg-rose-500 hover:bg-rose-600 text-white" }
                  ].map(item => {
                    const isSelected = formData.gradeMark === item.key;
                    return (
                      <button
                        key={item.key}
                        type="button"
                        onClick={() => setFormData({ ...formData, gradeMark: item.key as any })}
                        className={`py-3 rounded-xl font-black text-[11px] transition-all border ${
                          isSelected 
                            ? `${item.style} border-transparent shadow-lg shadow-black/10 scale-[1.03]`
                            : "bg-gray-50 dark:bg-gray-800 border-gray-100 dark:border-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-100"
                        }`}
                      >
                        {item.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Mistakes Counter */}
              {formData.gradeMark !== "absent" && (
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">عدد الأخطاء</label>
                  <div className="flex items-center gap-4">
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, mistakesCount: Math.max(0, formData.mistakesCount - 1) })}
                      className="text-teal-600 hover:text-teal-700 dark:text-teal-400 transition-colors"
                    >
                      <MinusCircle className="w-8 h-8" />
                    </button>
                    <span className="text-lg font-black w-8 text-center text-gray-900 dark:text-white">
                      {formData.mistakesCount}
                    </span>
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, mistakesCount: formData.mistakesCount + 1 })}
                      className="text-teal-600 hover:text-teal-700 dark:text-teal-400 transition-colors"
                    >
                      <PlusCircle className="w-8 h-8" />
                    </button>
                  </div>
                </div>
              )}

              {/* Remark */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">ملاحظات</label>
                <textarea 
                  value={formData.remark} 
                  onChange={e => setFormData({...formData, remark: e.target.value})} 
                  rows={2} 
                  placeholder="ملاحظات حول الأداء ومخارج الحروف..."
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" 
                />
              </div>

              {/* Action Buttons */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4 border-t border-gray-50 dark:border-gray-800">
                <button 
                  type="submit" 
                  className="w-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-750 text-gray-800 dark:text-white py-5 rounded-[2rem] font-black text-xs transition-all flex items-center justify-center gap-2"
                >
                  حفظ التقييم فقط
                </button>
                <button 
                  type="button"
                  onClick={(e) => handleSave(e, true)}
                  className="w-full bg-teal-600 hover:bg-teal-700 text-white py-5 rounded-[2rem] font-black text-xs transition-all flex items-center justify-center gap-2 shadow-lg shadow-teal-100 dark:shadow-none"
                >
                  <MessageCircle className="w-4 h-4" />
                  حفظ وإرسال لولي الأمر
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}