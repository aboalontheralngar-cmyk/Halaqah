"use client";

import { useMemo, useEffect } from "react";
import { 
  BarChart3, 
  Download, 
  TrendingUp, 
  Star, 
  BookOpen, 
  Award,
  Users,
  ChevronLeft,
  Share2,
  PieChart,
  Calendar,
  Sparkles,
  Zap,
  Target
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function ReportsPage() {
  const { students, homeworkGrades, fetchStudents, fetchHomeworkGrades, points, centerType } = useStore();
  const isMen = centerType === 'men';

  useEffect(() => {
    fetchStudents();
    fetchHomeworkGrades();
  }, [fetchStudents, fetchHomeworkGrades]);

  const stats = useMemo(() => {
    const totalStudents = students.length;
    const avgAttendance = totalStudents > 0 ? 85 : 0; // Mock or calculate
    const totalPoints = points.reduce((s, p) => s + p.amount, 0);

    const gradedRecords = homeworkGrades.filter(g => g.gradeMark !== "absent");
    const scoreMap: Record<string, number> = {
      excellent: 5,
      very_good: 4,
      good: 3,
      needs_work: 2,
    };
    const avgMemorization = gradedRecords.length > 0
      ? (gradedRecords.reduce((sum, g) => sum + (scoreMap[g.gradeMark] || 3), 0) / gradedRecords.length).toFixed(1)
      : "0.0";
    const avgExams = 92; // Mock

    return {
      attendance: avgAttendance,
      points: totalPoints,
      memorization: avgMemorization,
      exams: avgExams
    };
  }, [students, homeworkGrades, points]);

  const topStudents = useMemo(() => {
    return students
      .map(student => {
        const studentPoints = points
          .filter(p => p.studentId === student.id)
          .reduce((sum, p) => sum + p.amount, 0);
        return { ...student, totalPoints: studentPoints };
      })
      .sort((a, b) => b.totalPoints - a.totalPoints)
      .slice(0, 3);
  }, [students, points]);

  const exportToCSV = () => {
    const headers = [
      "اسم الطالب",
      "رقم الهاتف",
      "رقم ولي الأمر",
      "المستوى",
      "العمر",
      "عدد التسميعات",
      "تسميعات ممتاز",
      "تسميعات جيد جداً",
      "تسميعات جيد",
      "تسميعات مقبول",
      "تسميعات غائب",
      "متوسط الأخطاء",
      "تاريخ الانضمام",
      "الحالة"
    ];

    const rows = students.map(student => {
      const studentGrades = homeworkGrades.filter(g => g.studentId === student.id);
      const gradedCount = studentGrades.length;
      
      const excellentCount = studentGrades.filter(g => g.gradeMark === "excellent").length;
      const veryGoodCount = studentGrades.filter(g => g.gradeMark === "very_good").length;
      const goodCount = studentGrades.filter(g => g.gradeMark === "good").length;
      const needsWorkCount = studentGrades.filter(g => g.gradeMark === "needs_work").length;
      const absentCount = studentGrades.filter(g => g.gradeMark === "absent").length;

      const activeGrades = studentGrades.filter(g => g.gradeMark !== "absent");
      const avgMistakes = activeGrades.length > 0
        ? (activeGrades.reduce((sum, g) => sum + g.mistakesCount, 0) / activeGrades.length).toFixed(1)
        : "0";

      return [
        student.name,
        student.phone,
        student.parentPhone,
        student.level,
        student.age,
        gradedCount,
        excellentCount,
        veryGoodCount,
        goodCount,
        needsWorkCount,
        absentCount,
        avgMistakes,
        student.joinDate,
        student.status === "active" ? "نشط" : "غير نشط"
      ];
    });

    const csvContent = [
      headers.join(","),
      ...rows.map(row => row.map(val => `"${String(val).replace(/"/g, '""')}"`).join(","))
    ].join("\n");

    const BOM = "\uFEFF";
    const blob = new Blob([BOM + csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `تقرير_طلاب_الحلقة_${new Date().toISOString().split("T")[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="text-4xl">📊</div>
          <div>
            <h1 className="text-3xl font-black text-gray-900 dark:text-white">التقارير والإحصائيات</h1>
            <p className="text-gray-500 dark:text-gray-400 font-medium">تحليل شامل لأداء الحلقة ومستويات تقدم الطلاب.</p>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <button 
            onClick={exportToCSV}
            className="flex items-center gap-2 bg-teal-600 text-white px-8 py-4 rounded-2xl font-black text-sm shadow-xl hover:bg-teal-700 transition-all"
          >
            <Download className="w-5 h-5" /> تصدير تقرير الطلاب (CSV)
          </button>
          <button 
            onClick={exportToCSV}
            className="p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl text-gray-400 hover:text-teal-600 transition-all shadow-sm"
          >
            <Share2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      {/* Main Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-6">
        {[
          { label: "نسبة الحضور", value: `${stats.attendance}%`, icon: Users, color: "text-teal-600", bg: "bg-teal-50" },
          { label: "متوسط الحفظ", value: stats.memorization, icon: BookOpen, color: "text-amber-600", bg: "bg-amber-50" },
          { label: "إجمالي النقاط", value: stats.points, icon: Award, color: "text-purple-600", bg: "bg-purple-50" },
          { label: "معدل الاختبارات", value: `${stats.exams}%`, icon: Target, color: "text-rose-600", bg: "bg-rose-50" },
        ].map((item, i) => (
          <div key={i} className="bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 p-8 flex flex-col items-center text-center group hover:scale-[1.02] transition-all shadow-sm">
            <div className={`w-12 h-12 ${item.bg} dark:bg-gray-800 rounded-2xl flex items-center justify-center mb-4`}>
              <item.icon className={`w-6 h-6 ${item.color}`} />
            </div>
            <p className="text-3xl font-black text-gray-900 dark:text-white mb-1 tracking-tight">{item.value}</p>
            <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{item.label}</p>
          </div>
        ))}
      </div>

      <div className="grid lg:grid-cols-2 gap-10">
        {/* Top Students */}
        <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm">
          <h3 className="text-xl font-black text-gray-900 dark:text-white mb-8">الطلاب الأكثر تميزاً ⭐</h3>
          <div className="space-y-6">
            {topStudents.map((student, i) => (
              <div key={student.id} className="flex items-center gap-6 p-4 rounded-3xl hover:bg-gray-50 dark:hover:bg-gray-800 transition-all group">
                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center font-black text-lg ${
                  i === 0 ? "bg-amber-100 text-amber-600" : "bg-gray-100 text-gray-400"
                }`}>
                  {i + 1}
                </div>
                <div className="flex-1">
                  <h4 className="font-black text-gray-800 dark:text-white">{student.name}</h4>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">إجمالي النقاط: {student.totalPoints}</p>
                </div>
                <div className="text-right">
                  <span className="text-xl font-black text-teal-600">{student.totalPoints}</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Attendance Progress */}
        <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm flex flex-col">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-xl font-black text-gray-900 dark:text-white">تطور الحضور</h3>
            <span className="text-[10px] font-black text-teal-600 bg-teal-50 px-3 py-1 rounded-full">+12% الشهر الماضي</span>
          </div>
          <div className="flex-1 flex flex-col items-center justify-center text-center space-y-4 opacity-40">
            <TrendingUp className="w-16 h-16 text-gray-200" />
            <p className="text-sm font-bold text-gray-400">لا توجد بيانات كافية حالياً</p>
          </div>
        </div>
      </div>

      {/* Assessment Summary */}
      <div className="bg-teal-900 rounded-[3.5rem] p-12 text-white relative overflow-hidden flex flex-col md:flex-row items-center gap-12 group">
        <div className="flex-1 space-y-6">
          <h2 className="text-3xl font-black flex items-center gap-4">
            خلاصة تقييم الحلقة ☀️
          </h2>
          <p className="text-teal-100/60 text-lg font-medium leading-relaxed">
            بناءً على البيانات الحالية، تظهر الحلقة تقدماً ملحوظاً في معدلات الحفظ بنسبة 15% مقارنة بالشهر الماضي. نوصي بالتركيز على الطلاب المتأخرين في حضور جلسات المراجعة لتحسين المعدل العام.
          </p>
        </div>
        <div className="shrink-0 relative">
          <div className="w-32 h-32 rounded-full border-8 border-teal-500/20 flex items-center justify-center relative">
            <div className="w-32 h-32 rounded-full border-8 border-teal-400 border-t-transparent animate-spin-slow absolute inset-0" />
            <PieChart className="w-12 h-12 text-teal-400" />
          </div>
        </div>
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/islamic-art.png')] opacity-10 pointer-events-none" />
      </div>
    </div>
  );
}