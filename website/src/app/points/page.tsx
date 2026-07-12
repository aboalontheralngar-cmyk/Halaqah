"use client";

import { useState, useMemo, useEffect } from "react";
import { 
  Plus, 
  Trophy, 
  X,
  Filter,
  HelpCircle,
  Trash2,
  UserRoundSearch,
} from "lucide-react";
import { useStore } from "@/store/useStore";

export default function PointsPage() {
  const {
    students,
    points,
    addPoints,
    reassignPoint,
    deletePointWithAudit,
    pointsConfig,
    fetchPointsConfig,
  } = useStore();
  const [showForm, setShowForm] = useState(false);
  const [confirmingPoint, setConfirmingPoint] = useState(false);
  const [studentFilter, setStudentFilter] = useState('all');
  const [correctionPoint, setCorrectionPoint] = useState<(typeof points)[number] | null>(null);
  const [correctionAction, setCorrectionAction] = useState<'reassign' | 'delete'>('reassign');
  const [correctedStudentId, setCorrectedStudentId] = useState('');
  const [correctionReason, setCorrectionReason] = useState('');
  
  useEffect(() => {
    fetchPointsConfig();
  }, [fetchPointsConfig]);

  const topStudents = useMemo(() => {
    return students
      .filter(student => student.status === 'active' || student.status === 'suspended')
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

  const activeStudents = useMemo(
    () => students
      .filter(student => student.status === 'active' || student.status === 'suspended')
      .sort((a, b) => a.name.localeCompare(b.name, 'ar', { sensitivity: 'base' })),
    [students]
  );

  const visiblePoints = useMemo(
    () => points
      .filter(point => studentFilter === 'all' || point.studentId === studentFilter)
      .sort((a, b) => b.date.localeCompare(a.date)),
    [points, studentFilter]
  );

  const [formData, setFormData] = useState({
    studentId: "",
    amount: 5,
    reason: "",
    type: "positive" as "positive" | "negative"
  });

  const reasonChoices = useMemo(() => {
    const isPositive = formData.type === "positive";
    
    // Standard rules mapping
    const positiveStandards = [
      { key: "daily_memorization", label: "إتمام الحفظ اليومي", defaultVal: 5 },
      { key: "extra_memorization", label: "زيادة عن المقرر", defaultVal: 2 },
      { key: "early_attendance", label: "الحضور المبكر", defaultVal: 2 },
      { key: "revision_complete", label: "إتمام المراجعة", defaultVal: 3 },
      { key: "monthly_exam_pass", label: "نجاح في الامتحان", defaultVal: 10 },
      { key: "good_appearance", label: "المظهر الحسن", defaultVal: 1 },
    ];

    const negativeStandards = [
      { key: "late_penalty", label: "التأخير عن الحلقة", defaultVal: -2 },
      { key: "incomplete_penalty", label: "عدم إتمام المقرر اليومي", defaultVal: -3 },
      { key: "unexcused_absence", label: "الغياب بدون عذر مقبول", defaultVal: -5 },
      { key: "appearance_violation", label: "مخالفة المظهر/الحلاقة", defaultVal: -3 },
      { key: "no_thobe", label: "عدم لبس الثوب", defaultVal: -3 },
    ];

    const standards = isPositive ? positiveStandards : negativeStandards;
    const list = standards.map(s => {
      const amt = pointsConfig[s.key] !== undefined ? pointsConfig[s.key] : s.defaultVal;
      return {
        label: s.label,
        amount: Math.abs(amt)
      };
    });

    // Custom rules
    Object.entries(pointsConfig).forEach(([key, val]) => {
      if (key.startsWith("c_")) {
        const label = key.substring(2);
        const isRulePositive = val >= 0;
        if (isPositive === isRulePositive) {
          list.push({
            label,
            amount: Math.abs(val)
          });
        }
      }
    });

    return list;
  }, [formData.type, pointsConfig]);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!formData.studentId || !formData.reason.trim() || formData.amount <= 0) return;
    setConfirmingPoint(true);
  };

  const confirmPointRegistration = async () => {
    await addPoints({
      studentId: formData.studentId,
      amount: formData.type === "positive" ? formData.amount : -formData.amount,
      reason: formData.reason,
      date: new Date().toISOString().split("T")[0],
      type: formData.type
    });
    setConfirmingPoint(false);
    setShowForm(false);
    setFormData({ studentId: '', amount: 5, reason: '', type: 'positive' });
  };

  const openCorrection = (
    point: (typeof points)[number],
    action: 'reassign' | 'delete'
  ) => {
    setCorrectionPoint(point);
    setCorrectionAction(action);
    setCorrectedStudentId('');
    setCorrectionReason('');
  };

  const submitCorrection = async () => {
    if (!correctionPoint || !correctionReason.trim()) return;
    if (correctionAction === 'reassign') {
      if (!correctedStudentId) return;
      await reassignPoint(correctionPoint.id, correctedStudentId, correctionReason.trim());
    } else {
      await deletePointWithAudit(correctionPoint.id, correctionReason.trim());
    }
    setCorrectionPoint(null);
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
          </div>
          <div className="flex items-center gap-3 bg-white dark:bg-gray-900 px-4 py-3 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm">
            <Filter className="w-4 h-4 text-gray-400" />
            <select
              value={studentFilter}
              onChange={e => setStudentFilter(e.target.value)}
              className="w-full text-xs font-bold text-gray-600 dark:text-gray-300 outline-none bg-transparent"
            >
              <option value="all">كل الطلاب</option>
              {activeStudents.map(student => <option key={student.id} value={student.id}>{student.name}</option>)}
            </select>
          </div>
          {visiblePoints.length === 0 ? (
            <div className="bg-white/40 dark:bg-gray-900/40 rounded-[3.5rem] border-2 border-dashed border-gray-200 dark:border-gray-800 p-16 text-center">
              <p className="text-sm font-bold text-gray-400">لا توجد سجلات مطابقة</p>
            </div>
          ) : (
            <div className="space-y-3">
              {visiblePoints.map(point => {
                const student = students.find(item => item.id === point.studentId);
                const positive = point.amount > 0;
                return (
                  <div key={point.id} className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-5 flex flex-col md:flex-row md:items-center gap-4">
                    <div className={`w-11 h-11 rounded-2xl flex items-center justify-center font-black ${positive ? 'bg-green-50 text-green-600' : 'bg-rose-50 text-rose-600'}`}>
                      {positive ? '+' : ''}{point.amount}
                    </div>
                    <div className="flex-1 min-w-0">
                      <div className="font-black text-gray-900 dark:text-white truncate">{student?.name || 'طالب غير معروف'}</div>
                      <div className="text-xs font-bold text-gray-500 mt-1">{point.reason} — {point.date}</div>
                    </div>
                    <div className="flex items-center gap-2">
                      <button
                        onClick={() => openCorrection(point, 'reassign')}
                        className="p-3 rounded-xl bg-blue-50 text-blue-600 hover:bg-blue-600 hover:text-white transition-colors"
                        title="تصحيح الطالب المسند إليه"
                      >
                        <UserRoundSearch className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => openCorrection(point, 'delete')}
                        className="p-3 rounded-xl bg-rose-50 text-rose-600 hover:bg-rose-600 hover:text-white transition-colors"
                        title="حذف سجل خاطئ مع توثيق السبب"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
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
                {activeStudents.map(s => (
                  <option key={s.id} value={s.id}>
                    {s.name}{s.parentPhone ? ` — ولي الأمر ••••${s.parentPhone.replace(/\s/g, '').slice(-4)}` : ''}
                  </option>
                ))}
              </select>
              <div className="grid grid-cols-2 gap-4">
                <button type="button" onClick={() => setFormData({...formData, type: 'positive', amount: 5, reason: ''})} className={`py-4 rounded-xl font-black text-xs ${formData.type === 'positive' ? "bg-green-600 text-white" : "bg-gray-50 dark:bg-gray-850 text-gray-400"}`}>نقاط إيجابية</button>
                <button type="button" onClick={() => setFormData({...formData, type: 'negative', amount: 3, reason: ''})} className={`py-4 rounded-xl font-black text-xs ${formData.type === 'negative' ? "bg-rose-600 text-white" : "bg-gray-50 dark:bg-gray-850 text-gray-400"}`}>نقاط سلبية</button>
              </div>
              
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">اختر البند السلوكي</label>
                <select
                  onChange={e => {
                    const idx = e.target.value;
                    if (idx !== "") {
                      const choice = reasonChoices[parseInt(idx)];
                      setFormData({
                        ...formData,
                        reason: choice.label,
                        amount: choice.amount
                      });
                    }
                  }}
                  className="w-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-750 rounded-2xl px-6 py-4 text-sm font-bold outline-none dark:text-white"
                >
                  <option value="">اختر من القائمة المحددة</option>
                  {reasonChoices.map((choice, index) => (
                    <option key={index} value={index}>
                      {choice.label} ({formData.type === "positive" ? "+" : "-"}{choice.amount} نقاط)
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">النقاط</label>
                <input type="number" value={formData.amount} onChange={e => setFormData({...formData, amount: parseInt(e.target.value) || 0})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none dark:text-white" />
              </div>

              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase">السبب التفصيلي</label>
                <input type="text" value={formData.reason} onChange={e => setFormData({...formData, reason: e.target.value})} placeholder="اكتب السبب هنا أو عدّله..." required className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none dark:text-white" />
              </div>
              <button type="submit" className="w-full py-5 bg-purple-600 text-white rounded-2xl font-black text-sm shadow-xl hover:bg-purple-700 transition-colors">تأكيد التسجيل</button>
            </form>
          </div>
        </div>
      )}

      {confirmingPoint && (
        <div className="fixed inset-0 bg-gray-950/60 backdrop-blur-sm flex items-center justify-center z-[60] p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-8 w-full max-w-md shadow-2xl">
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-6">تأكيد هوية الطالب</h3>
            {(() => {
              const student = activeStudents.find(item => item.id === formData.studentId);
              return (
                <div className="space-y-3 bg-gray-50 dark:bg-gray-800 rounded-2xl p-5 text-sm font-bold">
                  <div>الطالب: <span className="font-black">{student?.name}</span></div>
                  <div>ولي الأمر: {student?.parentPhone ? `••••${student.parentPhone.replace(/\s/g, '').slice(-4)}` : 'غير مسجل'}</div>
                  <div>السبب: {formData.reason}</div>
                  <div className={formData.type === 'positive' ? 'text-green-600' : 'text-rose-600'}>
                    القيمة: {formData.type === 'positive' ? '+' : '-'}{formData.amount} نقطة
                  </div>
                </div>
              );
            })()}
            <p className="text-xs font-bold text-amber-700 dark:text-amber-300 mt-4">راجع الاسم ورقم ولي الأمر قبل الحفظ لتجنب الإسناد لطالب متشابه الاسم.</p>
            <div className="grid grid-cols-2 gap-3 mt-6">
              <button onClick={() => setConfirmingPoint(false)} className="py-4 rounded-2xl bg-gray-100 dark:bg-gray-800 font-black">رجوع</button>
              <button onClick={confirmPointRegistration} className="py-4 rounded-2xl bg-purple-600 text-white font-black">تأكيد وحفظ</button>
            </div>
          </div>
        </div>
      )}

      {correctionPoint && (
        <div className="fixed inset-0 bg-gray-950/60 backdrop-blur-sm flex items-center justify-center z-[60] p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-8 w-full max-w-lg shadow-2xl">
            <div className="flex items-start justify-between gap-4 mb-6">
              <div>
                <h3 className="text-2xl font-black text-gray-900 dark:text-white">
                  {correctionAction === 'reassign' ? 'تصحيح إسناد السجل' : 'حذف سجل خاطئ'}
                </h3>
                <p className="text-xs font-bold text-gray-500 mt-2">
                  {students.find(student => student.id === correctionPoint.studentId)?.name} — {correctionPoint.reason}
                </p>
              </div>
              <button onClick={() => setCorrectionPoint(null)} className="p-2 text-gray-400"><X className="w-5 h-5" /></button>
            </div>
            <div className="space-y-5">
              {correctionAction === 'reassign' && (
                <select
                  value={correctedStudentId}
                  onChange={e => setCorrectedStudentId(e.target.value)}
                  className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl px-5 py-4 font-bold outline-none"
                >
                  <option value="">اختر الطالب الصحيح</option>
                  {activeStudents.filter(student => student.id !== correctionPoint.studentId).map(student => (
                    <option key={student.id} value={student.id}>
                      {student.name}{student.parentPhone ? ` — ولي الأمر ••••${student.parentPhone.replace(/\s/g, '').slice(-4)}` : ''}
                    </option>
                  ))}
                </select>
              )}
              <textarea
                value={correctionReason}
                onChange={e => setCorrectionReason(e.target.value)}
                placeholder="سبب التصحيح (إلزامي)"
                rows={3}
                className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl px-5 py-4 font-bold outline-none resize-none"
              />
              <div className="bg-amber-50 dark:bg-amber-950/20 rounded-2xl p-4 text-xs font-bold text-amber-800 dark:text-amber-300">
                سيُحفظ السجل الأصلي والقيمة والطالب السابق وسبب التصحيح في سجل التدقيق.
              </div>
              <button
                type="button"
                disabled={!correctionReason.trim() || (correctionAction === 'reassign' && !correctedStudentId)}
                onClick={submitCorrection}
                className={`w-full py-4 text-white rounded-2xl font-black disabled:opacity-40 ${correctionAction === 'delete' ? 'bg-rose-600' : 'bg-blue-600'}`}
              >
                {correctionAction === 'delete' ? 'تأكيد الحذف الموثق' : 'تأكيد نقل السجل'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
