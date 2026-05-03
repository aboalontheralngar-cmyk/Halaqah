"use client";

import { useMemo } from "react";
import { useRouter } from "next/navigation";
import { 
  Users, 
  ClipboardCheck, 
  BookOpen, 
  Award, 
  BarChart3, 
  UserPlus,
  Calendar,
  Sparkles,
  TrendingUp,
  Gift,
  Zap,
  CheckCircle2,
  AlertTriangle,
  Moon,
  Clock,
  ArrowUpRight,
  ShieldCheck,
  Bell,
  Activity,
  Lightbulb,
  Trophy,
  X
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { StatCard, ActionButton } from "@/components/ui/DashboardCards";
import { getHijriDate } from "@/utils/dateUtils";

export default function Dashboard() {
  const router = useRouter();
  const { students, attendance, memorization, centerType, activities } = useStore();
  const hijriDate = getHijriDate();
  
  const isMen = centerType === 'men';
  const labels = {
    welcome: "أهلاً بك 👋",
    students: isMen ? "الطلاب" : "الطالبات",
    student: isMen ? "طالب" : "طالبة",
    honorTitle: isMen ? "فرسان الحلقة" : "ملكات الحلقة",
    addStudent: isMen ? "إضافة طالب" : "إضافة طالبة",
  };

  const stats = useMemo(() => {
    const today = new Date().toISOString().split("T")[0];
    const todayAttendance = attendance.filter(a => a.date === today);
    const presentCount = todayAttendance.filter(a => a.status === "present" || a.status === "late").length;
    const absentCount = todayAttendance.filter(a => a.status === "absent").length;
    return {
      totalStudents: students.length,
      presentToday: presentCount,
      absentToday: absentCount,
      attendanceRate: students.length > 0 ? Math.round((presentCount / students.length) * 100) : 0,
    };
  }, [students, attendance]);

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-8">
        <div className="space-y-2">
          <div className="flex items-center gap-3">
            <h1 className="text-4xl lg:text-5xl font-black text-gray-900 dark:text-white tracking-tight">{labels.welcome}</h1>
            <Sparkles className="w-8 h-8 text-amber-500 animate-pulse" />
          </div>
          <p className="text-3xl font-black text-teal-600 dark:text-teal-400">طبت وطاب يومك ✨</p>
        </div>
        
        <div className="flex items-center gap-4">
          <div className="bg-white dark:bg-gray-900 p-6 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 shadow-xl flex items-center gap-6">
            <div className="w-14 h-14 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center">
              <Calendar className="w-7 h-7 text-teal-600 dark:text-teal-400" />
            </div>
            <div>
              <p className="text-[11px] font-black text-teal-600 dark:text-teal-400 uppercase tracking-[0.2em] mb-1">التاريخ الهجري</p>
              <p className="text-xl font-black text-gray-800 dark:text-white">{hijriDate.full}</p>
            </div>
          </div>
          <button className="w-16 h-16 bg-white dark:bg-gray-900 rounded-[1.5rem] flex items-center justify-center border border-gray-100 dark:border-gray-800 shadow-xl text-gray-400 hover:text-teal-600 transition-all">
            <Bell className="w-6 h-6" />
          </button>
        </div>
      </div>

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-8">
        <StatCard label={`إجمالي ${labels.students}`} value={stats.totalStudents.toString()} icon={Users} trend="+2" color={isMen ? "teal" : "rose"} />
        <StatCard label={`الطلاب الحاضرين`} value={stats.presentToday.toString()} icon={CheckCircle2} trend="نشط" color="teal" />
        <StatCard label="الطلاب الغائبين" value={stats.absentToday.toString()} icon={X} trend="انتباه" color="rose" />
      </div>

      <div className="grid lg:grid-cols-3 gap-10">
        {/* Recent Activities */}
        <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-8 shadow-sm flex flex-col h-full">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-xl font-black text-gray-900 dark:text-white flex items-center gap-2">
              آخر النشاطات
            </h3>
            <Activity className="w-5 h-5 text-teal-600" />
          </div>
          <div className="space-y-6 flex-1">
            {activities.length > 0 ? activities.slice(0, 3).map((act, i) => (
              <div key={act.id} className="relative pr-6 border-r-2 border-teal-500/20 py-2">
                <div className="absolute -right-[7px] top-1/2 -translate-y-1/2 w-3 h-3 bg-teal-500 rounded-full" />
                <p className="text-sm font-black text-gray-800 dark:text-white">{act.description}</p>
                <p className="text-[10px] font-bold text-gray-400 mt-1">منذ قليل</p>
              </div>
            )) : (
              <div className="text-center py-10">
                <p className="text-xs font-bold text-gray-400">لا توجد نشاطات حالياً</p>
              </div>
            )}
          </div>
          <button className="mt-8 w-full py-4 bg-teal-50 dark:bg-teal-900/20 rounded-2xl text-[10px] font-black text-teal-600 dark:text-teal-400 hover:bg-teal-600 hover:text-white transition-all uppercase tracking-widest">
            عرض السجل الكامل
          </button>
        </div>

        {/* Quick Actions */}
        <div className="lg:col-span-2 space-y-8">
          <div className="flex items-center justify-between">
            <h2 className="text-2xl font-black text-gray-900 dark:text-white">إجراءات سريعة</h2>
          </div>
          <div className="grid grid-cols-2 sm:grid-cols-3 gap-6">
            {[
              { label: "تسجيل الحضور", icon: ClipboardCheck, color: "text-teal-600", bg: "bg-teal-50 dark:bg-teal-900/20", href: "/attendance" },
              { label: labels.addStudent, icon: UserPlus, color: "text-blue-600", bg: "bg-blue-50 dark:bg-blue-900/20", href: "/students" },
              { label: "الحفظ والمراجعة", icon: BookOpen, color: "text-amber-600", bg: "bg-amber-50 dark:bg-amber-900/20", href: "/memorization" },
              { label: "النقاط والسلوك", icon: Award, color: "text-purple-600", bg: "bg-purple-50 dark:bg-purple-900/20", href: "/points" },
              { label: "الامتحانات", icon: ShieldCheck, color: "text-rose-600", bg: "bg-rose-50 dark:bg-rose-900/20", href: "/exams" },
              { label: "التقارير", icon: BarChart3, color: "text-cyan-600", bg: "bg-cyan-50 dark:bg-cyan-900/20", href: "/reports" },
            ].map((action, i) => (
              <button 
                key={i}
                onClick={() => router.push(action.href)}
                className="group flex flex-col items-center justify-center p-8 bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 hover:shadow-xl hover:scale-[1.02] transition-all"
              >
                <div className={`w-14 h-14 ${action.bg} rounded-2xl flex items-center justify-center mb-4 transition-transform group-hover:scale-110`}>
                  <action.icon className={`w-7 h-7 ${action.color}`} />
                </div>
                <span className="text-xs font-black text-gray-700 dark:text-gray-200">{action.label}</span>
              </button>
            ))}
          </div>
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-10">
        {/* Daily Tip */}
        <div className="bg-teal-50/50 dark:bg-teal-900/10 border border-teal-100 dark:border-teal-800 rounded-[2.5rem] p-8 flex items-center gap-6 relative overflow-hidden group">
          <div className="w-14 h-14 bg-teal-600 rounded-2xl flex items-center justify-center text-white shadow-lg shrink-0">
            <Lightbulb className="w-7 h-7" />
          </div>
          <div className="relative z-10">
            <h4 className="text-sm font-black text-gray-900 dark:text-white mb-1">نصيحة اليوم</h4>
            <p className="text-xs text-gray-500 dark:text-gray-400 font-bold leading-relaxed">
              الاستمرارية في مراجعة المحفوظات القديمة تضمن ثبات الحفظ على المدى البعيد.
            </p>
          </div>
          <div className="absolute -bottom-10 -left-10 w-32 h-32 bg-teal-600/5 rounded-full blur-2xl" />
        </div>

        {/* Smart Motivation Banner */}
        <div className="lg:col-span-2 bg-gray-900 rounded-[3.5rem] p-10 text-white relative overflow-hidden flex flex-col md:flex-row items-center justify-between gap-10">
          <div className="relative z-10 space-y-6 text-center md:text-right">
            <div className="inline-flex items-center gap-2 px-4 py-2 bg-teal-500/20 rounded-full text-teal-400 text-[10px] font-black uppercase tracking-widest">
              <span className="w-2 h-2 bg-teal-400 rounded-full animate-pulse" /> ميزة جديدة
            </div>
            <h2 className="text-3xl font-black">نظام التحفيز الذكي 🏆</h2>
            <p className="text-gray-400 text-sm font-medium max-w-md">
              كافئ طلابك بنقاط تشجيعية فورية! تم إضافة نظام الأوسمة الجديد لتحفيز الطلاب على الحفظ والمواظبة.
            </p>
            <button className="bg-white text-gray-900 px-10 py-4 rounded-2xl font-black text-sm hover:bg-teal-500 hover:text-white transition-all shadow-xl">
              استكشف النظام الآن
            </button>
          </div>
          <div className="relative shrink-0">
            <div className="w-48 h-48 bg-teal-500/20 rounded-[3rem] flex items-center justify-center backdrop-blur-3xl border border-white/10 rotate-12">
              <Trophy className="w-24 h-24 text-teal-400 -rotate-12" />
            </div>
            <div className="absolute -top-10 -right-10 w-32 h-32 bg-teal-500/10 rounded-full blur-3xl animate-pulse" />
          </div>
          <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/islamic-art.png')] opacity-5 pointer-events-none" />
        </div>
      </div>
    </div>
  );
}