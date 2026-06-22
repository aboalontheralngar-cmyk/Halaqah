"use client";

import { useState, useEffect } from "react";
import Link from "next/link";
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
    profile, currentSupervisor, joinSupervisor,
    currencySymbol, updateCurrencySymbol, fetchCenterSettings,
    pointsConfig, fetchPointsConfig, savePointsConfig
  } = useStore();
  const [ramadanMode, setRamadanMode] = useState(false);
  const [activeTab, setActiveTab] = useState<"general" | "points" | "rules">("general");
  const [supervisorCode, setSupervisorCode] = useState("");
  
  // State for new points rule
  const [newRuleName, setNewRuleName] = useState("");
  const [newRulePoints, setNewRulePoints] = useState(1);
  const [newRuleType, setNewRuleType] = useState<"positive" | "negative">("positive");
  const [showAddRuleModal, setShowAddRuleModal] = useState(false);

  useEffect(() => {
    fetchCenterSettings();
    fetchPointsConfig();
  }, [fetchCenterSettings, fetchPointsConfig]);

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

              <div className="p-8 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors">
                <div className="flex items-center gap-6">
                  <div className="w-12 h-12 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center">
                    <SettingsIcon className="w-6 h-6 text-gray-400" />
                  </div>
                  <div>
                    <p className="font-black text-gray-800 dark:text-white text-sm">رمز عملة الصندوق</p>
                    <p className="text-[10px] text-gray-400 font-bold mt-1">تخصيص رمز العملة المستخدم في حسابات صندوق الحلقة (مثل: ر.س، $، د.أ، €)</p>
                  </div>
                </div>
                <input 
                  type="text" 
                  value={currencySymbol} 
                  onChange={(e) => updateCurrencySymbol(e.target.value)}
                  className="w-24 px-4 py-2 bg-gray-50 dark:bg-gray-850 border border-gray-200 dark:border-gray-800 rounded-xl text-center font-black text-xs text-teal-600 outline-none focus:ring-2 ring-teal-500/20"
                />
              </div>

              <Link 
                href="/settings/templates" 
                className="p-8 flex items-center justify-between hover:bg-gray-50 dark:hover:bg-gray-800 transition-colors cursor-pointer group"
              >
                <div className="flex items-center gap-6">
                  <div className="w-12 h-12 bg-gray-50 dark:bg-gray-800 rounded-2xl flex items-center justify-center">
                    <SettingsIcon className="w-6 h-6 text-gray-400 group-hover:text-teal-600 transition-colors" />
                  </div>
                  <div>
                    <p className="font-black text-gray-800 dark:text-white text-sm group-hover:text-teal-600 transition-colors">قوالب الرسائل لولي الأمر 💬</p>
                    <p className="text-[10px] text-gray-400 font-bold mt-1">تخصيص قوالب رسائل تكليف الحفظ وتسميع الواجبات ومشاركتها اليومية</p>
                  </div>
                </div>
                <ChevronLeft className="w-5 h-5 text-gray-400 group-hover:-translate-x-1 transition-transform" />
              </Link>
            </div>
          </div>
        )}

        {activeTab === "points" && (
          <div className="space-y-6 animate-in fade-in duration-500">
            <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm">
              <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-8">
                <h3 className="text-xl font-black text-gray-900 dark:text-white flex items-center gap-3">
                  <Star className="w-6 h-6 text-amber-500 fill-amber-500" /> تخصيص قواعد توزيع النقاط
                </h3>
                <button
                  onClick={() => setShowAddRuleModal(true)}
                  className="bg-teal-600 text-white px-6 py-3 rounded-2xl font-black text-xs hover:bg-teal-700 transition-all flex items-center gap-2"
                >
                  إضافة بند مخصص ➕
                </button>
              </div>

              <div className="space-y-8">
                {/* Standard Rules Section */}
                <div>
                  <h4 className="text-xs font-black text-gray-400 uppercase tracking-widest mb-4">القواعد الأساسية للنظام</h4>
                  <div className="grid md:grid-cols-2 gap-6">
                    {[
                      { key: "daily_memorization", label: "حفظ يومي (متقن)", icon: Zap, color: "text-green-600" },
                      { key: "extra_memorization", label: "حفظ زائد عن المقرر", icon: Star, color: "text-amber-500" },
                      { key: "early_attendance", label: "حضور مبكر", icon: Clock, color: "text-blue-600" },
                      { key: "revision_complete", label: "إتمام المراجعة", icon: ShieldCheck, color: "text-purple-600" },
                      { key: "monthly_exam_pass", label: "تجاوز اختبار شهري", icon: ShieldCheck, color: "text-indigo-600" },
                      { key: "good_appearance", label: "المظهر الحسن والترتيب", icon: Star, color: "text-emerald-500" },
                      { key: "late_penalty", label: "التأخير عن الحلقة", icon: AlertTriangle, color: "text-rose-600" },
                      { key: "incomplete_penalty", label: "عدم إتمام المقرر اليومي", icon: AlertTriangle, color: "text-rose-600" },
                      { key: "unexcused_absence", label: "الغياب بدون عذر مقبول", icon: LogOut, color: "text-rose-600" },
                      { key: "appearance_violation", label: "مخالفة المظهر أو الحلاقة", icon: AlertTriangle, color: "text-rose-600" },
                    ].map((item) => {
                      const currentVal = pointsConfig[item.key] !== undefined ? pointsConfig[item.key] : (item.key.includes("penalty") || item.key.includes("absence") || item.key.includes("violation") ? -3 : 2);
                      return (
                        <div key={item.key} className="flex items-center justify-between p-6 bg-gray-50 dark:bg-gray-800 rounded-3xl group hover:scale-[1.01] transition-all">
                          <div className="flex items-center gap-4">
                            <div className="w-10 h-10 bg-white dark:bg-gray-900 rounded-xl flex items-center justify-center shadow-sm">
                              <item.icon className={`w-5 h-5 ${item.color}`} />
                            </div>
                            <span className="text-sm font-bold text-gray-700 dark:text-gray-200">{item.label}</span>
                          </div>
                          <div className="flex items-center gap-2">
                            <input 
                              type="number" 
                              value={currentVal} 
                              onChange={(e) => {
                                const val = parseInt(e.target.value) || 0;
                                const updated = { ...pointsConfig, [item.key]: val };
                                savePointsConfig(updated);
                              }}
                              className="w-16 bg-white dark:bg-gray-900 border-none rounded-xl px-2 py-2 text-center font-black text-teal-600 outline-none" 
                            />
                            <span className="text-xs font-bold text-gray-400">نقطة</span>
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>

                {/* Custom Rules Section */}
                <div>
                  <h4 className="text-xs font-black text-gray-400 uppercase tracking-widest mb-4">بنود سلوكية مخصصة (المعلم)</h4>
                  {Object.entries(pointsConfig).filter(([key]) => key.startsWith("c_")).length === 0 ? (
                    <div className="p-8 text-center bg-gray-50 dark:bg-gray-800 rounded-3xl border border-dashed border-gray-200 dark:border-gray-700">
                      <p className="text-xs text-gray-400 font-bold">لا يوجد بنود سلوكية مخصصة حالياً. أضف بنداً مخصصاً لظهور خياراتك المخصصة في قائمة السلوك.</p>
                    </div>
                  ) : (
                    <div className="grid md:grid-cols-2 gap-6">
                      {Object.entries(pointsConfig).filter(([key]) => key.startsWith("c_")).map(([key, val]) => {
                        const label = key.substring(2);
                        const isPositive = val >= 0;
                        return (
                          <div key={key} className="flex items-center justify-between p-6 bg-gray-50 dark:bg-gray-800 rounded-3xl group hover:scale-[1.01] transition-all border border-teal-500/10">
                            <div className="flex items-center gap-4">
                              <div className="w-10 h-10 bg-white dark:bg-gray-900 rounded-xl flex items-center justify-center shadow-sm">
                                {isPositive ? <Star className="w-5 h-5 text-amber-500 fill-amber-500" /> : <AlertTriangle className="w-5 h-5 text-rose-600" />}
                              </div>
                              <span className="text-sm font-bold text-gray-700 dark:text-gray-200">{label}</span>
                            </div>
                            <div className="flex items-center gap-4">
                              <div className="flex items-center gap-2">
                                <input 
                                  type="number" 
                                  value={val} 
                                  onChange={(e) => {
                                    const v = parseInt(e.target.value) || 0;
                                    const updated = { ...pointsConfig, [key]: v };
                                    savePointsConfig(updated);
                                  }}
                                  className="w-16 bg-white dark:bg-gray-900 border-none rounded-xl px-2 py-2 text-center font-black text-teal-600 outline-none" 
                                />
                                <span className="text-xs font-bold text-gray-400">نقطة</span>
                              </div>
                              <button 
                                onClick={() => {
                                  if (confirm(`هل أنت متأكد من حذف البند "${label}"؟`)) {
                                    const updated = { ...pointsConfig };
                                    delete updated[key];
                                    savePointsConfig(updated);
                                  }
                                }}
                                className="text-rose-500 hover:text-rose-700 p-1 transition-colors font-bold text-xs"
                              >
                                حذف
                              </button>
                            </div>
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>

            {/* Add Custom Rule Modal */}
            {showAddRuleModal && (
              <div className="fixed inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
                <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-md shadow-2xl relative border border-gray-100 dark:border-gray-800">
                  <h3 className="text-xl font-black text-gray-900 dark:text-white mb-6 text-center">إضافة بند سلوك مخصص</h3>
                  <form 
                    onSubmit={(e) => {
                      e.preventDefault();
                      if (!newRuleName.trim()) return;
                      const key = `c_${newRuleName.trim()}`;
                      const value = newRuleType === "positive" ? Math.abs(newRulePoints) : -Math.abs(newRulePoints);
                      const updated = { ...pointsConfig, [key]: value };
                      savePointsConfig(updated);
                      setNewRuleName("");
                      setNewRulePoints(1);
                      setShowAddRuleModal(false);
                    }}
                    className="space-y-6"
                  >
                    <div>
                      <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">اسم البند</label>
                      <input 
                        type="text" 
                        required 
                        placeholder="مثال: التميز في التسميع، صلاة الجماعة..."
                        value={newRuleName}
                        onChange={(e) => setNewRuleName(e.target.value)}
                        className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none dark:text-white"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">النقاط</label>
                      <input 
                        type="number" 
                        required 
                        min="1"
                        value={newRulePoints}
                        onChange={(e) => setNewRulePoints(parseInt(e.target.value) || 1)}
                        className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none dark:text-white"
                      />
                    </div>
                    <div>
                      <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">نوع البند</label>
                      <div className="grid grid-cols-2 gap-4">
                        <button
                          type="button"
                          onClick={() => setNewRuleType("positive")}
                          className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                            newRuleType === "positive" 
                              ? "bg-emerald-50 border-emerald-500 text-emerald-800 dark:bg-emerald-900/30 dark:border-emerald-400 dark:text-emerald-400"
                              : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                          }`}
                        >
                          مكافأة إيجابية (+)
                        </button>
                        <button
                          type="button"
                          onClick={() => setNewRuleType("negative")}
                          className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                            newRuleType === "negative" 
                              ? "bg-rose-50 border-rose-500 text-rose-800 dark:bg-rose-900/30 dark:border-rose-500 dark:text-rose-450"
                              : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                          }`}
                        >
                          عقوبة سالبة (-)
                        </button>
                      </div>
                    </div>
                    <div className="flex gap-4 pt-4 border-t border-gray-50 dark:border-gray-800">
                      <button 
                        type="button" 
                        onClick={() => setShowAddRuleModal(false)}
                        className="flex-1 bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300 py-4 rounded-2xl text-xs font-black"
                      >
                        إلغاء
                      </button>
                      <button 
                        type="submit" 
                        className="flex-1 bg-teal-600 text-white py-4 rounded-2xl text-xs font-black hover:bg-teal-700 shadow-md"
                      >
                        حفظ البند
                      </button>
                    </div>
                  </form>
                </div>
              </div>
            )}
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