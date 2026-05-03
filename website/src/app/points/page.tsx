"use client";

import { useState, useMemo } from "react";
import { 
  Plus, 
  Trophy, 
  Star, 
  History as HistoryIcon,
  Sparkles,
  ArrowUpRight,
  X,
  Target,
  ShieldCheck,
  Filter,
  Flame,
  Award,
  Zap,
  HelpCircle
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function PointsPage() {
  const { students, points, activities, addPoints, centerType } = useStore();
  const [showForm, setShowForm] = useState(false);
  
  const topStudents = useMemo(() => {
    return students
      .map(student => {
        const studentPoints = points
          .filter(p => p.studentId === student.id)
          .reduce((sum, p) => sum + p.amount, 0);
        const positive = points.filter(p => p.studentId === student.id && p.amount > 0).length;
        const negative = points.filter(p => p.studentId === student.id && p.amount < 0).length;
        return { ...student, totalPoints: studentPoints, positive, negative };
      })
      .sort((a, b) => b.totalPoints - a.totalPoints)
      .slice(0, 3);
  }, [students, points]);

  const [formData, setFormData] = useState({
    studentId: "",
    amount: 5,
    reason: "",
    type: "positive" as "positive" | "negative"
  });

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    await addPoints({
      studentId: formData.studentId,
      amount: formData.type === "positive" ? formData.amount : -formData.amount,
      reason: formData.reason,
      date: new Date().toISOString().split("T")[0],
      type: formData.type
    });
    setShowForm(false);
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            نظام النقاط والتحفيز 🏆
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">عزز السلوك الإيجابي وكافئ طلابك المتميزين بالأوسمة والنقاط.</p>
        </div>
        <button 
          onClick={() => setShowForm(true)}
          className="bg-purple-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-purple-700 shadow-xl shadow-purple-100 dark:shadow-none transition-all flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" /> إضافة نقاط جديدة
        </button>
      </div>

      <div className="space-y-6">
        <h2 className="text-xl font-black text-gray-900 dark:text-white">قائمة المتصدرين</h2>
        <div className="grid md:grid-cols-3 gap-8">
          {topStudents.map((student, i) => (
            <div key={student.id} className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-8 shadow-sm flex flex-col items-center relative overflow-hidden group">
              <div className="absolute top-6 left-6">
                <Trophy className={`w-10 h-10 ${i === 0 ? "text-amber-400" : "text-gray-200"}`} />
              </div>
              <div className={`w-24 h-24 rounded-[2.5rem] flex items-center justify-center text-3xl font-black mb-6 ${
                i === 0 ? "bg-amber-50 text-amber-600" : "bg-gray-100 text-gray-400"
              }`}>
                {student.name[0]}
              </div>
              <h3 className="text-xl font-black text-gray-900 dark:text-white mb-6">{student.name}</h3>
              <div className="flex items-center gap-10">
                <div className="text-center">
                  <p className="text-xs font-black text-green-500">+{student.positive}</p>
                  <p className="text-[10px] font-bold text-gray-400 uppercase">نقاط</p>
                </div>
                <div className="text-center">
                  <p className="text-2xl font-black text-orange-500">{student.totalPoints}</p>
                  <p className="text-[10px] font-bold text-gray-400 uppercase">نقطة</p>
                </div>
                <div className="text-center">
                  <p className="text-xs font-black text-rose-500">-{student.negative}</p>
                  <p className="text-[10px] font-bold text-gray-400 uppercase">نقاط</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="grid lg:grid-cols-3 gap-10">
        <div className="space-y-8">
          {/* Why Card */}
          <div className="bg-gradient-to-br from-purple-700 to-purple-500 rounded-[3rem] p-10 text-white shadow-2xl relative overflow-hidden group">
            <div className="w-14 h-14 bg-white/20 rounded-2xl flex items-center justify-center mb-6">
              <HelpCircle className="w-8 h-8" />
            </div>
            <h3 className="text-2xl font-black mb-4">لماذا نظام النقاط؟ 🤔</h3>
            <p className="text-purple-50 text-sm leading-relaxed font-medium">
              يساعد نظام النقاط في بناء عادات إيجابية لدى الطلاب حيث يشعر الطالب بقيمة إنجازه عند رؤية نقاطه تزداد، مما يشجع بقية الطلاب على الاقتداء به.
            </p>
            <div className="absolute -bottom-10 -right-10 w-40 h-40 bg-white/5 rounded-full blur-3xl group-hover:scale-150 transition-transform duration-700" />
          </div>

          {/* Suggested Distribution */}
          <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-[3rem] p-8">
            <h4 className="text-sm font-black text-gray-900 dark:text-white mb-8">توزيع النقاط المقترح</h4>
            <div className="space-y-6">
              {[
                { label: "حفظ سورة كاملة", points: "+10 ن", color: "text-green-600" },
                { label: "الحضور مبكراً", points: "+5 ن", color: "text-green-600" },
                { label: "مساعدة زميل", points: "+3 ن", color: "text-green-600" },
                { label: "الغياب بدون عذر", points: "-5 ن", color: "text-rose-600" },
              ].map((item, i) => (
                <div key={i} className="flex justify-between items-center text-xs">
                  <span className="font-bold text-gray-500">{item.label}</span>
                  <span className={`font-black ${item.color}`}>{item.points}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Activity Log */}
        <div className="lg:col-span-2 space-y-6">
          <div className="flex items-center justify-between">
            <h2 className="text-xl font-black text-gray-900 dark:text-white">سجل النشاطات</h2>
            <div className="flex items-center gap-3 bg-white dark:bg-gray-900 px-4 py-2 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm">
              <Filter className="w-4 h-4 text-gray-400" />
              <select className="text-xs font-bold text-gray-600 outline-none bg-transparent">
                <option>كل الطلاب</option>
              </select>
            </div>
          </div>
          <div className="bg-white/40 dark:bg-gray-900/40 backdrop-blur-md rounded-[3.5rem] border-2 border-dashed border-gray-200 dark:border-gray-800 p-20 text-center flex flex-col items-center justify-center">
            <p className="text-sm font-bold text-gray-400">لا يوجد سجلات حالياً</p>
          </div>
        </div>
      </div>

      {/* Point Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative">
            <button onClick={() => setShowForm(false)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full"><X className="w-6 h-6 text-gray-400" /></button>
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8">تسجيل نقاط جديدة</h3>
            <form onSubmit={handleSubmit} className="space-y-6">
              <select 
                value={formData.studentId} 
                onChange={e => setFormData({...formData, studentId: e.target.value})} 
                required 
                className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
              >
                <option value="">اختر الطالب</option>
                {students.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
              <div className="grid grid-cols-2 gap-4">
                <button type="button" onClick={() => setFormData({...formData, type: 'positive'})} className={`py-4 rounded-xl font-black text-xs ${formData.type === 'positive' ? "bg-green-600 text-white" : "bg-gray-50 text-gray-400"}`}>نقاط إيجابية</button>
                <button type="button" onClick={() => setFormData({...formData, type: 'negative'})} className={`py-4 rounded-xl font-black text-xs ${formData.type === 'negative' ? "bg-rose-600 text-white" : "bg-gray-50 text-gray-400"}`}>نقاط سلبية</button>
              </div>
              <input type="number" value={formData.amount} onChange={e => setFormData({...formData, amount: parseInt(e.target.value)})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" />
              <input type="text" value={formData.reason} onChange={e => setFormData({...formData, reason: e.target.value})} placeholder="السبب..." required className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" />
              <button type="submit" className="w-full py-5 bg-purple-600 text-white rounded-2xl font-black text-sm shadow-xl">تأكيد التسجيل</button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}