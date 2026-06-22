"use client";

import { useState, useMemo, useEffect } from "react";
import { 
  Search, 
  Plus, 
  Edit2, 
  Trash2, 
  Phone, 
  User, 
  Calendar, 
  Filter, 
  X, 
  Save, 
  GraduationCap,
  LayoutGrid,
  List as ListIcon,
  QrCode,
  Download,
  Target,
  Camera,
  CircleCheck,
  CircleDashed,
  Map,
  History
} from "lucide-react";
import { useStore, Student } from "@/store/useStore";
import { QRCodeSVG } from "qrcode.react";
import MushafVisualizer from "@/components/MushafVisualizer";
import { quranService } from "@/services/quranService";

const levels = [
  { id: "الكل", label: "الكل" },
  { id: "مبتدئ", label: "مبتدئ (جزء عم وتبارك)" },
  { id: "متوسط", label: "متوسط (3 - 10 أجزاء)" },
  { id: "متقدم", label: "متقدم (أكثر من 10 أجزاء)" }
];

export default function StudentsPage() {
  const { 
    students, 
    addStudent, 
    updateStudent, 
    deleteStudent, 
    loading, 
    homeworkGrades, 
    fetchHomeworkGrades,
    attendance,
    fetchCenterData
  } = useStore();
  const surahs = quranService.getSurahs();
  const [search, setSearch] = useState("");
  const [selectedLevel, setSelectedLevel] = useState("الكل");
  const [showForm, setShowForm] = useState(false);
  const [showQR, setShowQR] = useState<Student | null>(null);
  const [visualizingStudent, setVisualizingStudent] = useState<Student | null>(null);
  const [editingStudent, setEditingStudent] = useState<Student | null>(null);
  const [viewMode, setViewMode] = useState<"grid" | "list">("grid");

  useEffect(() => {
    fetchCenterData();
    quranService.initialize();
  }, [fetchCenterData]);

  const [timelineStudent, setTimelineStudent] = useState<Student | null>(null);
  const [sortByLeftOut, setSortByLeftOut] = useState(false);

  const checkDidNotReciteLastClass = (studentId: string) => {
    const studentAtt = attendance
      .filter(a => a.studentId === studentId && (a.status === 'present' || a.status === 'late'))
      .sort((a, b) => b.date.localeCompare(a.date));
      
    if (studentAtt.length === 0) return false;
    const lastAttendedDate = studentAtt[0].date;
    const hasRecited = homeworkGrades.some(g => g.studentId === studentId && g.date === lastAttendedDate && g.gradeMark !== 'absent');
    return !hasRecited;
  };

  const getStudentStats = (studentId: string) => {
    const studentGrades = homeworkGrades.filter(g => g.studentId === studentId && g.gradeMark !== 'absent');
    const uniquePages = new Set<number>();
    const uniqueAyahs = new Set<string>();

    const surahs = quranService.getSurahs();
    if (surahs.length === 0) return { pages: 0, ayahs: 0 };

    studentGrades.forEach(grade => {
      const surah = surahs.find(s => s.name === grade.surah);
      if (surah) {
        const ayahsInRange = surah.ayahs.filter(a => a.number >= grade.fromAyah && a.number <= grade.toAyah);
        ayahsInRange.forEach(a => {
          uniquePages.add(a.page);
          uniqueAyahs.add(`${surah.number}_${a.number}`);
        });
      }
    });

    return {
      pages: uniquePages.size,
      ayahs: uniqueAyahs.size
    };
  };

  const getPreMemorizedStats = (startSurah: number, startAyah: number, endSurah: number, endAyah: number) => {
    if (!startSurah || !endSurah) return { surahs: 0, ayahs: 0, pages: 0 };
    let surahCount = 0;
    let ayahCount = 0;
    const uniquePages = new Set<number>();

    const allSurahs = quranService.getSurahs();
    if (allSurahs.length === 0) return { surahs: 0, ayahs: 0, pages: 0 };

    const start = startSurah;
    const end = endSurah;
    
    if (start === end) {
      surahCount = 1;
      const s = allSurahs.find(x => x.number === start);
      if (s && endAyah >= startAyah) {
        const range = s.ayahs.filter(a => a.number >= startAyah && a.number <= endAyah);
        ayahCount = range.length;
        range.forEach(a => uniquePages.add(a.page));
      }
    } else if (start > end) {
      // Descending
      surahCount = start - end + 1;
      for (let i = end; i <= start; i++) {
        const s = allSurahs.find(x => x.number === i);
        if (s) {
          let range = s.ayahs;
          if (i === start) {
            range = s.ayahs.filter(a => a.number >= startAyah);
          } else if (i === end) {
            range = s.ayahs.filter(a => a.number <= endAyah);
          }
          ayahCount += range.length;
          range.forEach(a => uniquePages.add(a.page));
        }
      }
    } else {
      // Ascending
      surahCount = end - start + 1;
      for (let i = start; i <= end; i++) {
        const s = allSurahs.find(x => x.number === i);
        if (s) {
          let range = s.ayahs;
          if (i === start) {
            range = s.ayahs.filter(a => a.number >= startAyah);
          } else if (i === end) {
            range = s.ayahs.filter(a => a.number <= endAyah);
          }
          ayahCount += range.length;
          range.forEach(a => uniquePages.add(a.page));
        }
      }
    }
    return {
      surahs: surahCount,
      ayahs: ayahCount,
      pages: uniquePages.size
    };
  };

  const [formData, setFormData] = useState<Omit<Student, 'id'>>({ 
    name: "", 
    phone: "", 
    parentPhone: "", 
    age: 10, 
    level: "مبتدئ", 
    joinDate: new Date().toISOString().split("T")[0],
    planType: 'ayahs',
    planAmount: 5,
    status: 'active',
    memorizationDirection: 'desc',
    preMemorizedStartSurah: undefined,
    preMemorizedStartAyah: undefined,
    preMemorizedEndSurah: undefined,
    preMemorizedEndAyah: undefined,
  });

  const filteredStudents = useMemo(() => {
    let result = students.filter(s => {
      const matchSearch = s.name.includes(search) || s.phone.includes(search);
      const matchLevel = selectedLevel === "الكل" || s.level === selectedLevel;
      return matchSearch && matchLevel;
    });

    if (sortByLeftOut) {
      result = [...result].sort((a, b) => {
        const aLeft = checkDidNotReciteLastClass(a.id) ? 1 : 0;
        const bLeft = checkDidNotReciteLastClass(b.id) ? 1 : 0;
        return bLeft - aLeft;
      });
    }

    return result;
  }, [students, search, selectedLevel, sortByLeftOut, attendance, homeworkGrades]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    
    // Check for exact duplicate name in the same center
    const isDuplicate = students.some(s => 
      s.name.trim() === formData.name.trim() && s.id !== editingStudent?.id
    );

    if (isDuplicate) {
      alert("هذا الاسم مسجل بالفعل في المركز. يرجى التأكد من الاسم لتجنب التكرار.");
      return;
    }

    if (editingStudent) {
      await updateStudent(editingStudent.id, formData);
    } else {
      await addStudent(formData);
    }
    setShowForm(false);
    setEditingStudent(null);
    setFormData({ 
      name: "", phone: "", parentPhone: "", age: 10, level: "مبتدئ", 
      joinDate: new Date().toISOString().split("T")[0],
      planType: 'ayahs', planAmount: 5, status: 'active',
      memorizationDirection: 'desc',
      preMemorizedStartSurah: undefined,
      preMemorizedStartAyah: undefined,
      preMemorizedEndSurah: undefined,
      preMemorizedEndAyah: undefined,
    });
  };

  const handleEdit = (student: Student) => {
    setEditingStudent(student);
    setFormData(student);
    setShowForm(true);
  };

  const handleDelete = async (id: string) => {
    if (confirm("هل أنت متأكد من حذف هذا الطالب؟ سيتم حذف جميع بياناته بشكل نهائي.")) {
      await deleteStudent(id);
    }
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">إدارة شؤون الطلاب 👨‍🎓</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">متابعة دقيقة لبيانات الطلاب وخطط حفظهم اليومية.</p>
        </div>
        <button 
          onClick={() => { setShowForm(true); setEditingStudent(null); }}
          className="bg-teal-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2 group"
        >
          <Plus className="w-5 h-5 group-hover:rotate-90 transition-transform" />
          إضافة طالب جديد
        </button>
      </div>

      {/* Filters Bar */}
      <div className="bg-white/60 dark:bg-gray-900/60 backdrop-blur-md rounded-[2.5rem] border border-white dark:border-gray-800 p-6 shadow-xl shadow-gray-200/30 dark:shadow-none flex flex-col lg:flex-row gap-6 items-center">
        <div className="relative flex-1 w-full">
          <Search className="absolute right-5 top-1/2 -translate-y-1/2 w-5 h-5 text-gray-400" />
          <input 
            type="text" 
            placeholder="بحث باسم الطالب أو رقم الهاتف..." 
            value={search} 
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pr-14 pl-6 py-4 bg-white dark:bg-gray-800 border-none rounded-2xl shadow-sm outline-none focus:ring-2 ring-teal-500/20 text-sm font-bold text-gray-700 dark:text-gray-200 transition-all"
          />
        </div>

        <div className="flex items-center gap-4 w-full lg:w-auto">
          <div className="flex items-center gap-3 bg-white dark:bg-gray-800 px-4 py-2 rounded-2xl border border-gray-100 dark:border-gray-700 shadow-sm flex-1 lg:flex-none">
            <Filter className="w-4 h-4 text-gray-400" />
            <select 
              value={selectedLevel} 
              onChange={(e) => setSelectedLevel(e.target.value)}
              className="text-xs font-bold text-gray-600 dark:text-gray-400 outline-none bg-transparent py-2 px-2"
            >
              {levels.map(l => <option key={l.id} value={l.id}>{l.label}</option>)}
            </select>
          </div>

          <button
            onClick={() => setSortByLeftOut(!sortByLeftOut)}
            className={`px-4 py-3 rounded-2xl text-xs font-black transition-all border flex items-center gap-2 ${
              sortByLeftOut
                ? "bg-amber-50 border-amber-200 text-amber-700 dark:bg-amber-950/20 dark:border-amber-900 dark:text-amber-400"
                : "bg-white border-gray-105 text-gray-600 hover:text-teal-600 dark:bg-gray-800 dark:border-gray-700 dark:text-gray-400"
            }`}
          >
            ⚠️ {sortByLeftOut ? "إلغاء ترتيب الأولوية" : "ترتيب من لم يُسمّعوا أولاً"}
          </button>

          <div className="flex bg-gray-100 dark:bg-gray-800 p-1.5 rounded-2xl">
            <button 
              onClick={() => setViewMode("grid")}
              className={`p-2 rounded-xl transition-all ${viewMode === "grid" ? "bg-white dark:bg-gray-700 shadow-sm text-teal-600" : "text-gray-400"}`}
            >
              <LayoutGrid className="w-5 h-5" />
            </button>
            <button 
              onClick={() => setViewMode("list")}
              className={`p-2 rounded-xl transition-all ${viewMode === "list" ? "bg-white dark:bg-gray-700 shadow-sm text-teal-600" : "text-gray-400"}`}
            >
              <ListIcon className="w-5 h-5" />
            </button>
          </div>
        </div>
      </div>

      {/* Students Grid */}
      <div className={viewMode === "grid" ? "grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-8" : "space-y-4"}>
        {filteredStudents.map(student => (
          <div 
            key={student.id}
            className={`group bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 transition-all duration-500 hover:shadow-2xl flex flex-col ${
              viewMode === "grid" ? "rounded-[3rem] p-8" : "rounded-3xl p-5 md:flex-row md:items-center md:justify-between"
            }`}
          >
            <div className={viewMode === "grid" ? "flex flex-col items-center text-center" : "flex items-center gap-6"}>
              <div className={`relative ${viewMode === "grid" ? "w-24 h-24 mb-6" : "w-16 h-16"}`}>
                <div className="w-full h-full bg-gradient-to-br from-teal-500 to-teal-700 rounded-[2rem] flex items-center justify-center text-white text-3xl font-black shadow-xl shadow-teal-100 rotate-3 group-hover:rotate-0 transition-transform">
                  {student.name[0]}
                </div>
                {student.status === 'active' ? (
                  <div className="absolute -top-2 -right-2 w-7 h-7 bg-green-500 text-white rounded-full flex items-center justify-center shadow-lg border-2 border-white dark:border-gray-900">
                    <CircleCheck className="w-4 h-4" />
                  </div>
                ) : (
                  <div className="absolute -top-2 -right-2 w-7 h-7 bg-gray-400 text-white rounded-full flex items-center justify-center shadow-lg border-2 border-white dark:border-gray-900">
                    <CircleDashed className="w-4 h-4" />
                  </div>
                )}
              </div>

              <div>
                <h4 className="text-xl font-black text-gray-900 dark:text-white group-hover:text-teal-600 transition-colors flex flex-wrap items-center gap-2 justify-center md:justify-start">
                  {student.name}
                  {checkDidNotReciteLastClass(student.id) && (
                    <span className="inline-flex items-center gap-1 px-2.5 py-0.5 bg-amber-50 dark:bg-amber-950/20 text-amber-700 dark:text-amber-400 rounded-lg text-[9px] font-black border border-amber-100/30">
                      ⚠️ لم يُسمّع
                    </span>
                  )}
                </h4>
                <div className="flex items-center gap-3 mt-1 justify-center md:justify-start">
                  <span className="text-[10px] font-black uppercase tracking-widest text-teal-600 bg-teal-50 dark:bg-teal-900/20 px-3 py-1 rounded-full">
                    مستوى {student.level}
                  </span>
                  <span className="text-[10px] font-black text-gray-400 flex items-center gap-1">
                    <Target className="w-3 h-3" /> الخطة: {student.planAmount} {student.planType === 'ayahs' ? 'آيات' : 'صفحات'}
                  </span>
                </div>
                {(() => {
                  const stats = getStudentStats(student.id);
                  return (
                    <div className="flex flex-wrap items-center gap-x-3 gap-y-1 mt-2 justify-center md:justify-start text-[10px] font-black text-teal-600 bg-teal-50/50 dark:bg-teal-950/20 px-3 py-1.5 rounded-xl border border-teal-100/30">
                      <span>📖 صفحات فريدة: {stats.pages}</span>
                      <span className="text-teal-300">•</span>
                      <span>🔢 الآيات المنجزة: {stats.ayahs}</span>
                    </div>
                  );
                })()}
              </div>
            </div>

            <div className={`flex gap-3 ${viewMode === "grid" ? "mt-8 justify-center border-t border-gray-50 dark:border-gray-800 pt-8" : "mt-4 md:mt-0"}`}>
              <button 
                onClick={() => setVisualizingStudent(student)} 
                className="w-12 h-12 bg-teal-50 dark:bg-teal-900/20 text-teal-600 rounded-2xl flex items-center justify-center hover:bg-teal-600 hover:text-white transition-all"
                title="خريطة المصحف"
              >
                <Map className="w-5 h-5" />
              </button>
              <button 
                onClick={() => setTimelineStudent(student)} 
                className="w-12 h-12 bg-purple-50 dark:bg-purple-900/20 text-purple-600 rounded-2xl flex items-center justify-center hover:bg-purple-600 hover:text-white transition-all"
                title="سجل التسميع (Timeline)"
              >
                <History className="w-5 h-5" />
              </button>
              <button onClick={() => setShowQR(student)} className="w-12 h-12 bg-amber-50 dark:bg-amber-900/20 text-amber-600 rounded-2xl flex items-center justify-center hover:bg-amber-600 hover:text-white transition-all"><QrCode className="w-5 h-5" /></button>
              <button onClick={() => handleEdit(student)} className="w-12 h-12 bg-blue-50 dark:bg-blue-900/20 text-blue-600 rounded-2xl flex items-center justify-center hover:bg-blue-600 hover:text-white transition-all"><Edit2 className="w-5 h-5" /></button>
              <button onClick={() => handleDelete(student.id)} className="w-12 h-12 bg-rose-50 dark:bg-rose-900/20 text-rose-600 rounded-2xl flex items-center justify-center hover:bg-rose-600 hover:text-white transition-all"><Trash2 className="w-5 h-5" /></button>
            </div>
          </div>
        ))}
      </div>

      {/* Student Form Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-2xl shadow-2xl relative animate-in zoom-in-95 duration-300 overflow-y-auto max-h-[90vh]">
            <button onClick={() => setShowForm(false)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><X className="w-6 h-6 text-gray-400" /></button>
            <h3 className="text-3xl font-black text-gray-900 dark:text-white mb-2">{editingStudent ? "تعديل بيانات الطالب" : "إضافة طالب جديد"}</h3>
            <p className="text-gray-400 font-medium mb-10">أدخل بيانات الطالب وخطة حفظه اليومية بدقة.</p>
            
            <form onSubmit={handleSubmit} className="grid grid-cols-1 md:grid-cols-2 gap-8">
              <div className="md:col-span-2 relative">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3">الاسم الكامل</label>
                <input 
                  type="text" 
                  value={formData.name} 
                  onChange={e => setFormData({...formData, name: e.target.value})} 
                  required 
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none focus:ring-2 ring-teal-500/20" 
                  placeholder="مثال: أحمد محمد علي..."
                />
                
                {/* Duplicate Name Warning */}
                {formData.name.length > 2 && students.some(s => s.name.includes(formData.name) && s.id !== editingStudent?.id) && (
                  <div className="mt-3 p-4 bg-amber-50 dark:bg-amber-900/20 border border-amber-100 dark:border-amber-800 rounded-2xl animate-in fade-in slide-in-from-top-2 duration-300">
                    <div className="flex items-center gap-2 text-amber-600 mb-2">
                      <Search className="w-4 h-4" />
                      <span className="text-[10px] font-black uppercase">أسماء مشابهة مسجلة بالفعل:</span>
                    </div>
                    <div className="flex flex-wrap gap-2">
                      {students
                        .filter(s => s.name.includes(formData.name) && s.id !== editingStudent?.id)
                        .slice(0, 3)
                        .map(s => (
                          <span key={s.id} className="text-[10px] font-bold bg-white dark:bg-gray-800 px-3 py-1 rounded-full border border-amber-200 dark:border-amber-700 text-gray-600 dark:text-gray-300">
                            {s.name} ({s.level})
                          </span>
                        ))
                      }
                    </div>
                  </div>
                )}
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3">رقم الهاتف</label>
                <input type="tel" value={formData.phone} onChange={e => setFormData({...formData, phone: e.target.value})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" />
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3">المستوى</label>
                <select value={formData.level} onChange={e => setFormData({...formData, level: e.target.value})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none">
                  {levels.slice(1).map(l => <option key={l.id} value={l.id}>{l.label}</option>)}
                </select>
              </div>
              <div className="md:col-span-2">
                <label className="block text-xs font-black text-gray-400 uppercase tracking-widest mb-3">اتجاه الحفظ</label>
                <select 
                  value={formData.memorizationDirection || 'desc'} 
                  onChange={e => {
                    const val = e.target.value as 'asc' | 'desc';
                    const startSurah = val === 'desc' ? 114 : 1;
                    const startAyah = 1;
                    const endSurah = val === 'desc' ? 114 : 1;
                    const endAyah = val === 'desc' ? 6 : 7;
                    setFormData({
                      ...formData,
                      memorizationDirection: val,
                      preMemorizedStartSurah: startSurah,
                      preMemorizedStartAyah: startAyah,
                      preMemorizedEndSurah: endSurah,
                      preMemorizedEndAyah: endAyah
                    });
                  }}
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                >
                  <option value="desc">من الناس إلى البقرة (القصار أولاً - صعودي)</option>
                  <option value="asc">من البقرة إلى الناس (الطوال أولاً - نزولي)</option>
                </select>
              </div>

              <div className="md:col-span-2 p-6 bg-amber-500/5 dark:bg-amber-500/5 rounded-3xl border border-amber-100 dark:border-amber-900/30 space-y-4">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <GraduationCap className="w-5 h-5 text-amber-500" />
                    <h4 className="font-black text-gray-905 dark:text-gray-200 text-sm">المحفوظ المسبق للطالب</h4>
                  </div>
                  <button
                    type="button"
                    onClick={() => {
                      setFormData({
                        ...formData,
                        preMemorizedStartSurah: 1,
                        preMemorizedStartAyah: 1,
                        preMemorizedEndSurah: 114,
                        preMemorizedEndAyah: 6,
                      });
                    }}
                    className="bg-amber-500/10 hover:bg-amber-500/20 text-amber-700 dark:text-amber-400 border border-amber-500/20 px-4 py-2 rounded-2xl font-black text-xs transition-all flex items-center gap-1"
                  >
                    <span>🏆 ختم المصحف كاملًا</span>
                  </button>
                </div>

                <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                  <div>
                    <label className="block text-[10px] font-black text-gray-400 uppercase mb-2">من سورة (بداية الحفظ)</label>
                    <select
                      value={formData.preMemorizedStartSurah || ""}
                      onChange={e => {
                        const val = e.target.value ? parseInt(e.target.value) : undefined;
                        setFormData({
                          ...formData,
                          preMemorizedStartSurah: val,
                          preMemorizedStartAyah: val ? 1 : undefined,
                          preMemorizedEndSurah: val ? (formData.preMemorizedEndSurah || val) : undefined,
                          preMemorizedEndAyah: val ? (formData.preMemorizedEndAyah || 1) : undefined,
                        });
                      }}
                      className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none"
                    >
                      <option value="">بلا (لم يحفظ شيء بعد)</option>
                      {surahs.map(s => (
                        <option key={s.number} value={s.number}>سورة {s.name}</option>
                      ))}
                    </select>
                  </div>

                  {formData.preMemorizedStartSurah && (
                    <div>
                      <label className="block text-[10px] font-black text-gray-400 uppercase mb-2">من آية</label>
                      <select
                        value={formData.preMemorizedStartAyah || 1}
                        onChange={e => setFormData({ ...formData, preMemorizedStartAyah: parseInt(e.target.value) })}
                        className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none"
                      >
                        {Array.from({ length: surahs.find(s => s.number === formData.preMemorizedStartSurah)?.totalAyahs || 0 }, (_, i) => i + 1).map(num => (
                          <option key={num} value={num}>{num === 1 ? 'آية 1 (أول السورة)' : `آية ${num}`}</option>
                        ))}
                      </select>
                    </div>
                  )}

                  {formData.preMemorizedStartSurah && (
                    <>
                      <div>
                        <label className="block text-[10px] font-black text-gray-400 uppercase mb-2">إلى سورة</label>
                        <select
                          value={formData.preMemorizedEndSurah || ""}
                          onChange={e => {
                            const val = e.target.value ? parseInt(e.target.value) : undefined;
                            setFormData({
                              ...formData,
                              preMemorizedEndSurah: val,
                              preMemorizedEndAyah: val ? (surahs.find(s => s.number === val)?.totalAyahs || 1) : undefined,
                            });
                          }}
                          className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none"
                        >
                          <option value="">اختر سورة النهاية</option>
                          {surahs.map(s => (
                            <option key={s.number} value={s.number}>سورة {s.name}</option>
                          ))}
                        </select>
                      </div>

                      {formData.preMemorizedEndSurah && (
                        <div>
                          <label className="block text-[10px] font-black text-gray-400 uppercase mb-2">إلى آية</label>
                          <select
                            value={formData.preMemorizedEndAyah || 1}
                            onChange={e => setFormData({ ...formData, preMemorizedEndAyah: parseInt(e.target.value) })}
                            className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none"
                          >
                            {Array.from({ length: surahs.find(s => s.number === formData.preMemorizedEndSurah)?.totalAyahs || 0 }, (_, i) => i + 1).map(num => (
                              <option key={num} value={num}>{num === 1 ? 'آية 1 (أول السورة)' : `آية ${num}`}</option>
                            ))}
                          </select>
                        </div>
                      )}
                    </>
                  )}
                </div>

                {formData.preMemorizedStartSurah && formData.preMemorizedEndSurah && (
                  (() => {
                    const stats = getPreMemorizedStats(
                      formData.preMemorizedStartSurah,
                      formData.preMemorizedStartAyah || 1,
                      formData.preMemorizedEndSurah,
                      formData.preMemorizedEndAyah || 1
                    );
                    return (
                      <div className="flex justify-around items-center bg-white dark:bg-gray-800 p-4 rounded-2xl text-center border border-amber-100/50 dark:border-amber-900/10">
                        <div>
                          <div className="text-xs font-black text-amber-600 dark:text-amber-400">سور</div>
                          <div className="text-sm font-black text-gray-850 dark:text-gray-200 mt-0.5">{stats.surahs}</div>
                        </div>
                        <div className="w-[1px] h-6 bg-gray-100 dark:bg-gray-700" />
                        <div>
                          <div className="text-xs font-black text-amber-600 dark:text-amber-400">آيات</div>
                          <div className="text-sm font-black text-gray-850 dark:text-gray-200 mt-0.5">{stats.ayahs}</div>
                        </div>
                        <div className="w-[1px] h-6 bg-gray-100 dark:bg-gray-700" />
                        <div>
                          <div className="text-xs font-black text-amber-600 dark:text-amber-400">صفحات</div>
                          <div className="text-sm font-black text-gray-850 dark:text-gray-200 mt-0.5">{stats.pages}</div>
                        </div>
                      </div>
                    );
                  })()
                )}
              </div>
              
              <div className="md:col-span-2 p-6 bg-teal-50 dark:bg-teal-900/10 rounded-3xl border border-teal-100 dark:border-teal-800 grid grid-cols-1 md:grid-cols-2 gap-6">
                <div className="md:col-span-2 flex items-center gap-2 mb-2">
                  <Target className="w-5 h-5 text-teal-600" />
                  <h4 className="font-black text-teal-900 dark:text-teal-400 text-sm">خطة الحفظ اليومية</h4>
                </div>
                <div>
                  <label className="block text-[10px] font-black text-teal-600 uppercase mb-2">نوع الحساب</label>
                  <select value={formData.planType} onChange={e => setFormData({...formData, planType: e.target.value as 'ayahs' | 'pages'})} className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none">
                    <option value="ayahs">بعدد الآيات</option>
                    <option value="pages">بعدد الصفحات</option>
                  </select>
                </div>
                <div>
                  <label className="block text-[10px] font-black text-teal-600 uppercase mb-2">الكمية اليومية</label>
                  <input 
                    type="number" 
                    value={formData.planAmount || 0} 
                    onChange={e => setFormData({...formData, planAmount: parseInt(e.target.value) || 0})} 
                    className="w-full bg-white dark:bg-gray-800 border-none rounded-xl px-4 py-3 text-xs font-bold outline-none" 
                  />
                </div>
              </div>

              <button type="submit" className="md:col-span-2 bg-teal-600 text-white py-5 rounded-[2.5rem] font-black text-sm hover:bg-teal-700 shadow-xl transition-all mt-6">
                حفظ بيانات الطالب
              </button>
            </form>
          </div>
        </div>
      )}

      {/* QR Modal Placeholder (Same as before but with Dark Mode support) */}
      {showQR && (
        <div className="fixed inset-0 bg-gray-900/60 backdrop-blur-md flex items-center justify-center z-50 p-4" onClick={() => setShowQR(null)}>
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-sm text-center relative" onClick={e => e.stopPropagation()}>
            <QRCodeSVG value={showQR.id} size={200} className="mx-auto mb-6 p-4 bg-white rounded-3xl border-4 border-teal-500/20" />
            <h3 className="text-xl font-black text-gray-900 dark:text-white">{showQR.name}</h3>
            <p className="text-xs font-bold text-gray-400 mt-2">كود الحضور الذكي</p>
          </div>
        </div>
      )}

      {/* Mushaf Map Modal */}
      {visualizingStudent && (
        <MushafVisualizer 
          student={visualizingStudent} 
          onClose={() => setVisualizingStudent(null)} 
        />
      )}

      {/* Timeline Modal */}
      {timelineStudent && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-2xl shadow-2xl relative animate-in zoom-in-95 duration-300 flex flex-col max-h-[85vh]">
            <button onClick={() => setTimelineStudent(null)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><X className="w-6 h-6 text-gray-400" /></button>
            
            <div className="flex items-center gap-4 mb-6">
              <div className="w-14 h-14 bg-teal-650 rounded-2xl flex items-center justify-center text-white text-2xl font-black shadow-lg">
                {timelineStudent.name[0]}
              </div>
              <div>
                <h3 className="text-2xl font-black text-gray-905 dark:text-white">{timelineStudent.name}</h3>
                <p className="text-gray-400 font-medium text-xs">سجل الحفظ والمراجعة الأكاديمي</p>
              </div>
            </div>

            <div className="flex-1 overflow-y-auto pr-2 space-y-6">
              {(() => {
                // Filter grades for this student and sort by date descending
                const grades = homeworkGrades
                  .filter(g => g.studentId === timelineStudent.id)
                  .sort((a, b) => b.date.localeCompare(a.date));

                if (grades.length === 0) {
                  return (
                    <div className="text-center py-12 text-gray-400 font-bold">
                      لا توجد سجلات تسميع أو حضور لهذا الطالب بعد.
                    </div>
                  );
                }

                return (
                  <div className="relative border-r-2 border-gray-100 dark:border-gray-800 mr-4 pl-4 space-y-8">
                    {grades.map(grade => {
                      const gradeColors: Record<string, {bg: string, text: string, label: string}> = {
                        excellent: { bg: "bg-green-50 dark:bg-green-950/20", text: "text-green-600", label: "ممتاز 🌟" },
                        very_good: { bg: "bg-emerald-50 dark:bg-emerald-950/20", text: "text-emerald-600", label: "جيد جداً" },
                        good: { bg: "bg-blue-50 dark:bg-blue-950/20", text: "text-blue-600", label: "جيد" },
                        needs_work: { bg: "bg-amber-50 dark:bg-amber-950/20", text: "text-amber-600", label: "يحتاج تركيز" },
                        absent: { bg: "bg-red-50 dark:bg-red-950/20", text: "text-red-600", label: "غائب" }
                      };
                      const color = gradeColors[grade.gradeMark] || { bg: "bg-gray-50", text: "text-gray-600", label: grade.gradeMark };

                      return (
                        <div key={grade.id} className="relative pr-8">
                          {/* Timeline dot */}
                          <div className={`absolute -right-[9px] top-1.5 w-4 h-4 rounded-full border-4 border-white dark:border-gray-900 ${
                            grade.gradeMark === 'absent' ? 'bg-red-500' : 'bg-teal-500'
                          }`} />

                          <div className="bg-gray-50/50 dark:bg-gray-800/30 rounded-3xl p-6 border border-gray-100/50 dark:border-gray-800 flex flex-col md:flex-row md:items-center justify-between gap-4">
                            <div className="space-y-2">
                              <div className="flex items-center gap-3">
                                <span className="text-xs font-bold text-gray-400 flex items-center gap-1">
                                  <Calendar className="w-3.5 h-3.5" /> {grade.date}
                                </span>
                                <span className={`text-[10px] font-black px-2.5 py-0.5 rounded-full ${color.bg} ${color.text}`}>
                                  {color.label}
                                </span>
                                <span className={`text-[10px] font-black px-2.5 py-0.5 rounded-full ${
                                  grade.isRevision ? "bg-amber-50 dark:bg-amber-950/20 text-amber-600" : "bg-teal-50 dark:bg-teal-950/20 text-teal-600"
                                }`}>
                                  {grade.isRevision ? "مراجعة 🔁" : "حفظ جديد 📖"}
                                </span>
                              </div>
                              
                              {grade.gradeMark !== 'absent' ? (
                                <p className="text-sm font-black text-gray-800 dark:text-white">
                                  سورة {grade.surah} (من آية {grade.fromAyah} إلى آية {grade.toAyah})
                                </p>
                              ) : (
                                <p className="text-sm font-bold text-red-500">تم تسجيل الطالب غائباً عن التسميع</p>
                              )}

                              {grade.remark && (
                                <p className="text-xs text-gray-500 dark:text-gray-400 bg-white dark:bg-gray-900/40 p-3 rounded-xl border border-gray-50 dark:border-gray-800 font-medium">
                                  📝 {grade.remark}
                                </p>
                              )}
                            </div>

                            {grade.gradeMark !== 'absent' && (
                              <div className="text-right shrink-0">
                                <div className="text-2xl font-black text-teal-600">{grade.mistakesCount}</div>
                                <div className="text-[9px] font-black text-gray-400 uppercase tracking-wider">الأخطاء والملاحظات</div>
                              </div>
                            )}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                );
              })()}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}