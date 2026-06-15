"use client";

import { useState } from "react";
import { 
  Settings as SettingsIcon, 
  Bell, 
  Moon, 
  Sun, 
  ShieldCheck, 
  ChevronLeft, 
  LogOut, 
  User, 
  Zap, 
  Star, 
  Clock, 
  Flame, 
  AlertTriangle,
  Users,
  VenetianMask
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function SettingsPage() {
  const { 
    darkMode, toggleDarkMode, centerType, setCenterType, 
    profile, currentSupervisor, joinSupervisor 
  } = useStore();
  const [ramadanMode, setRamadanMode] = useState(false);
  const [activeTab, setActiveTab] = useState<"general" | "points" | "rules">("general");
  const [supervisorCode, setSupervisorCode] = useState("");

  return (
    <div className="max-w-5xl mx-auto space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header Section */}
      <div className="text-center space-y-2">
        <div className="w-20 h-20 bg-teal-50 dark:bg-teal-900/20 rounded-[2.5rem] flex items-center justify-center mx-auto mb-6">
          <SettingsIcon className="w-10 h-10 text-teal-600 dark:text-teal-400" />
        </div>
        <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">إعدادات النظام الذكية ⚙️</h1>
        <p className="text-gray-500 dark:text-gray-400 font-medium">تحكم في قواعد الحلقة ونظام النقاط الآلي.</p>
      </div>

      {/* Tabs */}
      <div className="flex bg-white dark:bg-gray-900 p-2 rounded-[2rem] border border-gray-100 dark:border-gray-800 w-fit mx-auto shadow-sm">
        <button onClick={() => setActiveTab("general")} className={`px-8 py-3 rounded-2xl text-xs font-black transition-all ${activeTab === "general" ? "bg-teal-600 text-white shadow-lg" : "text-gray-400"}`}>الإعدادات العامة</button>
        <button onClick={() => setActiveTab("points")} className={`px-8 py-3 rounded-2xl text-xs font-black transition-all ${activeTab === "points" ? "bg-amber-500 text-white shadow-lg" : "text-gray-400"}`}>توزيع النقاط</button>
        <button onClick={() => setActiveTab("rules")} className={`px-8 py-3 rounded-2xl text-xs font-black transition-all ${activeTab === "rules" ? "bg-rose-600 text-white shadow-lg" : "text-gray-400"}`}>قواعد الضبط</button>
      </div>

      <div className="grid gap-8">
        {activeTab === "general" && (
          <div className="space-y-6 animate-in fade-in duration-500">
            {/* Center Type Setting */}
            <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm">
              <h3 className="text-xl font-black text-gray-900 dark:text-white mb-6 flex items-center gap-3">
                <Users className="w-6 h-6 text-teal-600" /> نوع مركز التحفيظ
              </h3>
              <div className="grid grid-cols-2 gap-6">
                <button 
                  onClick={() => setCenterType('men')}
                  className={`p-8 rounded-[2.5rem] border-2 transition-all flex flex-col items-center gap-4 ${centerType === 'men' ? "border-teal-600 bg-teal-50 dark:bg-teal-900/20" : "border-gray-100 dark:border-gray-800 hover:border-teal-200"}`}
                >
                  <div className={`w-14 h-14 rounded-2xl flex items-center justify-center ${centerType === 'men' ? "bg-teal-600 text-white" : "bg-gray-100 dark:bg-gray-800 text-gray-400"}`}>
                    <Users className="w-8 h-8" />
                  </div>
                  <div className="text-center">
                    <span className={`block font-black text-sm ${centerType === 'men' ? "text-teal-900 dark:text-teal-100" : "text-gray-400"}`}>مركز رجال (بنين)</span>
                    {centerType === 'men' && <span className="text-[10px] font-bold text-teal-600 dark:text-teal-400">النوع النشط حالياً</span>}
                  </div>
                </button>
                <button 
                  onClick={() => setCenterType('women')}
                  className={`p-8 rounded-[2.5rem] border-2 transition-all flex flex-col items-center gap-4 ${centerType === 'women' ? "border-rose-500 bg-rose-50 dark:bg-rose-900/20" : "border-gray-100 dark:border-gray-800 hover:border-rose-200"}`}
                >
                  <div className={`w-14 h-14 rounded-2xl flex items-center justify-center ${centerType === 'women' ? "bg-rose-500 text-white" : "bg-gray-100 dark:bg-gray-800 text-gray-400"}`}>
                    <VenetianMask className="w-8 h-8" />
                  </div>
                  <div className="text-center">
                    <span className={`block font-black text-sm ${centerType === 'women' ? "text-rose-900 dark:text-rose-100" : "text-gray-400"}`}>مركز نساء (بنات)</span>
                    {centerType === 'women' && <span className="text-[10px] font-bold text-rose-500">النوع النشط حالياً</span>}
                  </div>
                </button>
              </div>
            </div>
            {/* Supervision Linking */}
            {profile?.role === 'center_admin' && (
              <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm overflow-hidden relative group">
                <div className="absolute top-0 left-0 w-2 h-full bg-teal-600" />
                <h3 className="text-xl font-black text-gray-900 dark:text-white mb-2 flex items-center gap-3">
                  <ShieldCheck className="w-6 h-6 text-teal-600" /> الربط بجهة إشرافية
                </h3>
                <p className="text-gray-500 dark:text-gray-400 text-xs font-medium mb-8">اربط مركزك بجمعية أو مؤسسة إشرافية لمشاركة الإحصاءات العامة.</p>
                
                <div className="flex gap-4">
                  <div className="relative flex-1 group">
                    <Zap className="absolute right-4 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400 group-focus-within:text-teal-600" />
                    <input 
                      type="text" 
                      placeholder="أدخل كود الجهة الإشرافية (مثلاً: HAL-123456)" 
                      className="w-full pr-12 pl-4 py-4 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl text-sm font-bold outline-none focus:ring-2 ring-teal-500/20 dark:text-white"
                      value={supervisorCode}
                      onChange={(e) => setSupervisorCode(e.target.value)}
                    />
                  </div>
                  <button 
                    onClick={async () => {
                      const success = await joinSupervisor(supervisorCode);
                      if (success) alert("تم ربط المركز بالجهة الإشرافية بنجاح!");
                      else alert("الكود غير صحيح، يرجى التأكد من الكود والمحاولة مرة أخرى.");
                    }}
                    className="bg-gray-900 dark:bg-white dark:text-gray-900 text-white px-8 py-4 rounded-2xl font-black text-sm hover:scale-105 transition-all shadow-lg"
                  >
                    ربط الآن
                  </button>
                </div>
              </div>
            )}

            {profile?.role === 'supervisor' && currentSupervisor && (
              <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm overflow-hidden relative">
                <div className="absolute top-0 left-0 w-2 h-full bg-amber-500" />
                <h3 className="text-xl font-black text-gray-900 dark:text-white mb-2 flex items-center gap-3">
                  <Star className="w-6 h-6 text-amber-500" /> كود الربط الخاص بك
                </h3>
                <p className="text-gray-500 dark:text-gray-400 text-xs font-medium mb-8">شارك هذا الكود مع مدراء المراكز ليتمكنوا من الانضمام لجهتكم الإشرافية.</p>
                
                <div className="flex items-center justify-between p-6 bg-amber-50 dark:bg-amber-900/20 rounded-[2rem] border border-amber-100 dark:border-amber-800">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 bg-white dark:bg-gray-800 rounded-2xl flex items-center justify-center text-amber-600 shadow-sm">
                      <Zap className="w-6 h-6" />
                    </div>
                    <div>
                      <p className="text-[10px] font-black text-amber-600 uppercase tracking-widest">كود الجهة الإشرافية</p>
                      <p className="text-2xl font-black text-gray-900 dark:text-white tracking-widest">{currentSupervisor.code}</p>
                    </div>
                  </div>
                  <button 
                    onClick={() => {
                      navigator.clipboard.writeText(currentSupervisor.code);
                      alert("تم نسخ الكود بنجاح!");
                    }}
                    className="bg-amber-500 text-white px-6 py-3 rounded-xl font-black text-xs hover:bg-amber-600 transition-all shadow-md"
                  >
                    نسخ الكود
                  </button>
                </div>
              </div>
            )}

            {/* Ramadan Mode Card */}
            <div className="bg-gradient-to-br from-amber-600 to-amber-500 dark:from-amber-900 dark:to-amber-700 rounded-[3rem] p-10 text-white shadow-xl relative overflow-hidden group">
              <div className="flex items-center justify-between relative z-10">
                <div className="flex items-center gap-6">
                  <div className="w-16 h-16 bg-white/20 rounded-[2rem] flex items-center justify-center backdrop-blur-md">
                    <Sun className="w-8 h-8" />
                  </div>
                  <div>
                    <h3 className="text-2xl font-black">وضع شهر رمضان 🌙</h3>
                    <p className="text-amber-50 text-sm font-medium">تغيير أوقات الحلقة تلقائياً لتناسب الشهر الفضيل.</p>
                  </div>
                </div>
                <button 
                  onClick={() => setRamadanMode(!ramadanMode)}
                  className={`w-16 h-9 rounded-full p-1.5 transition-all duration-500 ${ramadanMode ? "bg-white" : "bg-white/30"}`}
                >
                  <div className={`w-6 h-6 rounded-full shadow-md transition-all duration-500 ${ramadanMode ? "-translate-x-7 bg-amber-600" : "translate-x-0 bg-white"}`} />
                </button>
              </div>
              <Flame className="absolute -bottom-10 -left-10 w-40 h-40 text-white/10 group-hover:rotate-12 transition-transform duration-700" />
            </div>

            <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 divide-y divide-gray-50 dark:divide-gray-800 overflow-hidden shadow-sm">
              <div className="p-8 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <div className="flex items-center gap-6">
                  <div className="w-12 h-12 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center">
                    <Moon className="w-6 h-6 text-gray-400" />
                  </div>
                  <div>
                    <p className="font-black text-gray-800 dark:text-white text-sm">الوضع الداكن (Dark Mode)</p>
                    <p className="text-[10px] text-gray-400 font-bold mt-1">تفعيل مظهر لوحة التحكم المريح للعين</p>
                  </div>
                </div>
                <button onClick={toggleDarkMode} className={`w-14 h-8 rounded-full p-1 transition-all ${darkMode ? "bg-teal-600" : "bg-gray-200"}`}>
                  <div className={`w-6 h-6 bg-white rounded-full transition-all ${darkMode ? "-translate-x-6" : ""}`} />
                </button>
              </div>
            </div>
          </div>
        )}

        {activeTab === "points" && (
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm animate-in fade-in duration-500">
            <h3 className="text-xl font-black text-gray-900 dark:text-white mb-8 flex items-center gap-3">
              <Star className="w-6 h-6 text-amber-500 fill-amber-500" /> تخصيص توزيع النقاط
            </h3>
            <div className="grid md:grid-cols-2 gap-8">
              {[
                { label: "حفظ يومي (متقن)", points: 5, icon: Zap, color: "text-green-600" },
                { label: "حفظ زائد", points: 2, icon: Star, color: "text-amber-500" },
                { label: "حضور مبكر", points: 2, icon: Clock, color: "text-blue-600" },
                { label: "تجاوز اختبار", points: 10, icon: ShieldCheck, color: "text-purple-600" },
                { label: "مخالفة سلوكية", points: -3, icon: AlertTriangle, color: "text-rose-600" },
                { label: "غياب بدون عذر", points: -5, icon: LogOut, color: "text-rose-600" },
              ].map((item, i) => (
                <div key={i} className="flex items-center justify-between p-6 bg-gray-50 dark:bg-gray-800 rounded-3xl group hover:scale-[1.02] transition-all">
                  <div className="flex items-center gap-4">
                    <div className="w-10 h-10 bg-white dark:bg-gray-900 rounded-xl flex items-center justify-center shadow-sm">
                      <item.icon className={`w-5 h-5 ${item.color}`} />
                    </div>
                    <span className="text-sm font-bold text-gray-700 dark:text-gray-200">{item.label}</span>
                  </div>
                  <input type="number" defaultValue={item.points} className="w-16 bg-white dark:bg-gray-900 border-none rounded-xl px-2 py-2 text-center font-black text-teal-600 outline-none" />
                </div>
              ))}
            </div>
          </div>
        )}

        {activeTab === "rules" && (
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm animate-in fade-in duration-500">
            <h3 className="text-xl font-black text-gray-900 dark:text-white mb-8 flex items-center gap-3">
              <ShieldCheck className="w-6 h-6 text-teal-600" /> قواعد الضبط والتحذير
            </h3>
            <div className="space-y-6">
              <div className="flex items-center justify-between p-8 bg-rose-50 dark:bg-rose-900/10 rounded-[2.5rem] border border-rose-100 dark:border-rose-900/30">
                <div>
                  <h4 className="font-black text-rose-900 dark:text-rose-400">نظام الإنذار التلقائي</h4>
                  <p className="text-xs text-rose-700/60 font-medium">إصدار إنذار عند غياب الطالب لعدد محدد من الأيام المتتالية.</p>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-xs font-bold text-rose-900">بعد</span>
                  <input type="number" defaultValue={2} className="w-14 bg-white dark:bg-gray-800 border-none rounded-xl px-2 py-3 text-center font-black text-rose-600 outline-none" />
                  <span className="text-xs font-bold text-rose-900">أيام</span>
                </div>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}