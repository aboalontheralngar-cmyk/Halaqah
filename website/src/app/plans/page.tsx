"use client";

import { useState, useMemo } from "react";
import {
  Plus,
  BookOpen,
  Edit,
  Trash2,
  X,
  Target,
  Zap,
  CheckCircle,
  Printer,
  Lock,
  Minus,
} from "lucide-react";
import { useStore } from "@/store/useStore";

type PlanUnit = "ayahs" | "pages" | "lines";
type PlanPeriod = "weekly" | "monthly";

interface Plan {
  id: string;
  studentId: string;
  unit: PlanUnit;
  period: PlanPeriod;
  startAmount: number;
  currentAmount: number;
  targetAmount: number;
  weeklyIncrease: number;
  startDate: string;
  status: "active" | "completed" | "paused";
  notes?: string;
}

const UNIT_LABEL: Record<PlanUnit, string> = {
  ayahs: "آيات",
  pages: "صفحات",
  lines: "أسطر",
};

const UNIT_STEP: Record<PlanUnit, number> = {
  ayahs: 1,
  pages: 0.5,
  lines: 0.5,
};

const PERIOD_LABEL: Record<PlanPeriod, string> = {
  weekly: "أسبوعية",
  monthly: "شهرية",
};

export default function PlansPage() {
  const { students, exams } = useStore();

  const [plans, setPlans] = useState<Plan[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [gateWarning, setGateWarning] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    studentId: "",
    unit: "ayahs" as PlanUnit,
    period: "weekly" as PlanPeriod,
    startAmount: 5,
    targetAmount: 20,
    weeklyIncrease: 2,
    notes: "",
  });

  const plansByStudent = useMemo(() => {
    const grouped: { [key: string]: Plan[] } = {};
    plans.forEach((plan) => {
      if (!grouped[plan.studentId]) grouped[plan.studentId] = [];
      grouped[plan.studentId].push(plan);
    });
    return grouped;
  }, [plans]);

  // هل اجتاز الطالب اختباراً (>= 50% من الدرجة) بعد بدء خطته النشطة الأخيرة؟
  const hasPassedExamSince = (studentId: string, sinceDate: string) => {
    return exams.some((exam) => {
      if (exam.date < sinceDate) return false;
      const score = exam.studentScores.find((s) => s.studentId === studentId);
      if (!score || score.degree <= 0) return false;
      return score.degree >= exam.maxDegree * 0.5;
    });
  };

  // الطالب الذي لديه خطة نشطة لم يجتز بعدها اختباراً يُمنع من خطة جديدة
  const isGatedForNewPlan = (studentId: string) => {
    const active = plans.find(
      (p) => p.studentId === studentId && p.status === "active"
    );
    if (!active) return false;
    return !hasPassedExamSince(studentId, active.startDate);
  };

  const resetForm = () => {
    setFormData({
      studentId: "",
      unit: "ayahs",
      period: "weekly",
      startAmount: 5,
      targetAmount: 20,
      weeklyIncrease: 2,
      notes: "",
    });
    setGateWarning(null);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();

    // بوابة الاختبار: لا تُكتب خطة جديدة قبل اجتياز اختبار الخطة السابقة
    if (!editingId && isGatedForNewPlan(formData.studentId)) {
      const student = students.find((s) => s.id === formData.studentId);
      setGateWarning(
        `لا يمكن إنشاء خطة جديدة للطالب ${student?.name ?? ""} قبل اجتياز اختبار الخطة الحالية بنجاح.`
      );
      return;
    }

    if (editingId) {
      setPlans(
        plans.map((p) =>
          p.id === editingId
            ? {
                ...p,
                unit: formData.unit,
                period: formData.period,
                startAmount: formData.startAmount,
                targetAmount: formData.targetAmount,
                weeklyIncrease: formData.weeklyIncrease,
                notes: formData.notes,
              }
            : p
        )
      );
      setEditingId(null);
    } else {
      const newPlan: Plan = {
        id: Date.now().toString(),
        studentId: formData.studentId,
        unit: formData.unit,
        period: formData.period,
        startAmount: formData.startAmount,
        currentAmount: formData.startAmount,
        targetAmount: formData.targetAmount,
        weeklyIncrease: formData.weeklyIncrease,
        startDate: new Date().toISOString().split("T")[0],
        status: "active",
        notes: formData.notes,
      };
      setPlans([...plans, newPlan]);
    }
    setShowForm(false);
    resetForm();
  };

  const getProgressPercent = (current: number, target: number) =>
    Math.min((current / target) * 100, 100);

  const getProgressColor = (percent: number) => {
    if (percent >= 100) return "bg-green-500";
    if (percent >= 75) return "bg-blue-500";
    if (percent >= 50) return "bg-yellow-500";
    return "bg-orange-500";
  };

  // طباعة خطة طالب — قالبان: كاشير (80مم) أو A4
  const printPlan = (studentId: string, size: "cashier" | "a4") => {
    const student = students.find((s) => s.id === studentId);
    const studentPlans = plansByStudent[studentId] || [];
    if (!student) return;

    const today = new Date().toLocaleDateString("ar-SA");
    const rows = studentPlans
      .map(
        (p) => `
        <tr>
          <td>${UNIT_LABEL[p.unit]} (${PERIOD_LABEL[p.period]})</td>
          <td>${p.currentAmount}</td>
          <td>${p.targetAmount}</td>
          <td>+${p.weeklyIncrease}</td>
        </tr>`
      )
      .join("");

    const isCashier = size === "cashier";
    const pageCss = isCashier
      ? "@page { size: 80mm auto; margin: 4mm; } body { width: 72mm; font-size: 12px; }"
      : "@page { size: A4; margin: 18mm; } body { font-size: 15px; }";

    const html = `
      <html dir="rtl" lang="ar">
      <head>
        <meta charset="utf-8" />
        <title>خطة ${student.name}</title>
        <style>
          ${pageCss}
          * { font-family: 'Segoe UI', Tahoma, sans-serif; }
          body { color: #111; }
          h1 { text-align: center; font-size: ${isCashier ? "15px" : "22px"}; margin: 0 0 4px; }
          .sub { text-align: center; color: #555; margin: 0 0 12px; font-size: ${isCashier ? "11px" : "13px"}; }
          table { width: 100%; border-collapse: collapse; margin-top: 8px; }
          th, td { border: 1px solid #999; padding: ${isCashier ? "4px" : "8px"}; text-align: center; }
          th { background: #0d9488; color: #fff; }
          .notes { margin-top: 10px; font-size: ${isCashier ? "10px" : "13px"}; }
          .footer { margin-top: 16px; text-align: center; color: #777; font-size: ${isCashier ? "9px" : "12px"}; }
        </style>
      </head>
      <body>
        <h1>خطة الحفظ</h1>
        <p class="sub">${student.name} — ${today}</p>
        <table>
          <thead>
            <tr><th>النوع</th><th>المقرر الحالي</th><th>الهدف</th><th>الزيادة</th></tr>
          </thead>
          <tbody>${rows || `<tr><td colspan="4">لا توجد خطط</td></tr>`}</tbody>
        </table>
        <div class="footer">منصة حلقة — إدارة حلقات التحفيظ</div>
        <script>window.onload = function(){ window.print(); window.onafterprint = function(){ window.close(); }; };</script>
      </body>
      </html>`;

    const w = window.open("", "_blank", "width=480,height=640");
    if (!w) return;
    w.document.write(html);
    w.document.close();
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-20">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight flex items-center gap-4">
            <Target className="w-8 h-8" />
            الخطط والمقرر الذكي
          </h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
            ضع خطط تصاعدية ذكية لكل طالب مع زيادة تلقائية منتظمة
          </p>
        </div>
        <button
          onClick={() => {
            setEditingId(null);
            resetForm();
            setShowForm(true);
          }}
          className="bg-teal-600 text-white px-8 py-4 rounded-3xl font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2"
        >
          <Plus className="w-5 h-5" /> خطة جديدة
        </button>
      </div>

      {/* Overview Cards */}
      <div className="grid md:grid-cols-4 gap-4">
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">إجمالي الخطط</p>
          <p className="text-3xl font-black text-teal-600">{plans.length}</p>
          <p className="text-xs text-gray-400 mt-1">
            {plans.filter((p) => p.status === "active").length} نشطة
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">مكتملة</p>
          <p className="text-3xl font-black text-green-600">
            {plans.filter((p) => p.status === "completed").length}
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">متوسط التقدم</p>
          <p className="text-3xl font-black text-blue-600">
            {plans.length > 0
              ? Math.round(
                  (plans.reduce(
                    (sum, p) => sum + getProgressPercent(p.currentAmount, p.targetAmount),
                    0
                  ) /
                    plans.length) *
                    10
                ) / 10
              : 0}
            %
          </p>
        </div>
        <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-6">
          <p className="text-xs font-bold text-gray-500 uppercase mb-3">طلاب نشطون</p>
          <p className="text-3xl font-black text-purple-600">
            {Object.keys(plansByStudent).length}
          </p>
        </div>
      </div>

      {/* Plans by Student */}
      <div className="space-y-8">
        {Object.entries(plansByStudent).map(([studentId, studentPlans]) => {
          const student = students.find((s) => s.id === studentId);
          if (!student) return null;
          const gated = isGatedForNewPlan(studentId);

          return (
            <div
              key={studentId}
              className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-800 p-8 space-y-6"
            >
              <div className="flex items-center justify-between gap-4 flex-wrap">
                <div>
                  <h2 className="text-2xl font-black text-gray-900 dark:text-white">
                    {student.name}
                  </h2>
                  <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                    المستوى:{" "}
                    <span className="font-bold text-teal-600">{student.level}</span>
                  </p>
                </div>
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => printPlan(studentId, "cashier")}
                    className="flex items-center gap-1 px-3 py-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 text-xs font-bold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                    title="طباعة على ورق الكاشير"
                  >
                    <Printer className="w-4 h-4" /> كاشير
                  </button>
                  <button
                    onClick={() => printPlan(studentId, "a4")}
                    className="flex items-center gap-1 px-3 py-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 text-xs font-bold hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                    title="طباعة على ورق A4"
                  >
                    <Printer className="w-4 h-4" /> A4
                  </button>
                </div>
              </div>

              {gated && (
                <div className="flex items-center gap-2 p-3 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400 text-xs font-bold">
                  <Lock className="w-4 h-4" />
                  يجب اجتياز اختبار الخطة الحالية قبل كتابة خطة جديدة.
                </div>
              )}

              <div className="space-y-4">
                {studentPlans.map((plan) => {
                  const progress = getProgressPercent(
                    plan.currentAmount,
                    plan.targetAmount
                  );
                  const isCompleted = plan.status === "completed" || progress >= 100;

                  return (
                    <div
                      key={plan.id}
                      className={`p-4 rounded-xl border-2 transition-all ${
                        isCompleted
                          ? "border-green-200 bg-green-50 dark:border-green-800 dark:bg-green-900/10"
                          : "border-gray-200 dark:border-gray-800 bg-gray-50 dark:bg-gray-800/50"
                      }`}
                    >
                      <div className="flex items-start justify-between mb-4">
                        <div>
                          <div className="flex items-center gap-2 flex-wrap">
                            <BookOpen className="w-5 h-5 text-teal-600" />
                            <h3 className="font-bold text-gray-900 dark:text-white">
                              {UNIT_LABEL[plan.unit]}
                            </h3>
                            <span className="text-[10px] font-bold px-2 py-0.5 rounded-full bg-teal-100 dark:bg-teal-900/30 text-teal-700 dark:text-teal-400">
                              {PERIOD_LABEL[plan.period]}
                            </span>
                            {isCompleted && (
                              <CheckCircle className="w-5 h-5 text-green-600" />
                            )}
                          </div>
                          <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                            من {plan.startDate}
                          </p>
                        </div>
                        <div className="flex gap-2">
                          <button
                            onClick={() => {
                              setFormData({
                                studentId: plan.studentId,
                                unit: plan.unit,
                                period: plan.period,
                                startAmount: plan.startAmount,
                                targetAmount: plan.targetAmount,
                                weeklyIncrease: plan.weeklyIncrease,
                                notes: plan.notes || "",
                              });
                              setEditingId(plan.id);
                              setGateWarning(null);
                              setShowForm(true);
                            }}
                            className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() => setPlans(plans.filter((p) => p.id !== plan.id))}
                            className="p-2 text-red-600 hover:bg-red-100 rounded-lg transition-colors"
                          >
                            <Trash2 className="w-4 h-4" />
                          </button>
                        </div>
                      </div>

                      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
                        <div>
                          <p className="text-xs text-gray-500 font-bold">المقرر الحالي</p>
                          <p className="text-lg font-black text-teal-600">
                            {plan.currentAmount}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500 font-bold">الهدف</p>
                          <p className="text-lg font-black text-blue-600">
                            {plan.targetAmount}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500 font-bold">الزيادة الأسبوعية</p>
                          <p className="text-lg font-black text-purple-600">
                            +{plan.weeklyIncrease}
                          </p>
                        </div>
                        <div>
                          <p className="text-xs text-gray-500 font-bold">التقدم</p>
                          <p
                            className={`text-lg font-black ${
                              isCompleted ? "text-green-600" : "text-orange-600"
                            }`}
                          >
                            {Math.round(progress)}%
                          </p>
                        </div>
                      </div>

                      <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3 overflow-hidden mb-2">
                        <div
                          className={`h-full ${getProgressColor(progress)} transition-all duration-500`}
                          style={{ width: `${progress}%` }}
                        />
                      </div>

                      {plan.notes && (
                        <p className="text-xs text-gray-600 dark:text-gray-400 italic">
                          ملاحظات: {plan.notes}
                        </p>
                      )}
                    </div>
                  );
                })}
              </div>

              {/* Next Target */}
              <div className="p-4 bg-purple-50 dark:bg-purple-900/20 border border-purple-200 dark:border-purple-800 rounded-xl">
                <div className="flex items-center gap-3">
                  <Zap className="w-5 h-5 text-purple-600" />
                  <div className="flex-1">
                    <p className="font-bold text-gray-900 dark:text-white">الهدف التالي</p>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      وصول المقرر إلى{" "}
                      {Math.max(...studentPlans.map((p) => p.targetAmount)) + 5} بزيادة
                      منتظمة كل أسبوع
                    </p>
                  </div>
                </div>
              </div>
            </div>
          );
        })}

        {plans.length === 0 && (
          <div className="text-center py-16 bg-gray-50 dark:bg-gray-900 rounded-3xl border-2 border-dashed border-gray-300 dark:border-gray-700">
            <Target className="w-16 h-16 text-gray-300 mx-auto mb-4" />
            <p className="text-gray-500 dark:text-gray-400 font-bold text-lg">
              لا توجد خطط حالية
            </p>
            <p className="text-sm text-gray-400 mt-2">أضف خطة تصاعدية لأول طالب</p>
          </div>
        )}
      </div>

      {/* Modal Form */}
      {showForm && (
        <div className="fixed inset-0 bg-black/50 flex items-end md:items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md shadow-2xl max-h-[90vh] overflow-y-auto">
            <div className="flex items-center justify-between mb-6">
              <h2 className="text-2xl font-black">
                {editingId ? "تعديل الخطة" : "خطة جديدة"}
              </h2>
              <button
                onClick={() => {
                  setShowForm(false);
                  setEditingId(null);
                  resetForm();
                }}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            {gateWarning && (
              <div className="flex items-center gap-2 mb-5 p-3 rounded-xl bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400 text-xs font-bold">
                <Lock className="w-4 h-4 flex-shrink-0" />
                {gateWarning}
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-sm font-bold mb-3">الطالب</label>
                <select
                  value={formData.studentId}
                  onChange={(e) => {
                    setFormData({ ...formData, studentId: e.target.value });
                    setGateWarning(null);
                  }}
                  disabled={!!editingId}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium disabled:opacity-50"
                  required
                >
                  <option value="">اختر طالباً</option>
                  {students.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                      {isGatedForNewPlan(s.id) ? " (بانتظار الاختبار)" : ""}
                    </option>
                  ))}
                </select>
              </div>

              {/* نوع المقرر: آيات / صفحات / أسطر */}
              <div>
                <label className="block text-sm font-bold mb-3">نوع المقرر</label>
                <div className="grid grid-cols-3 gap-3">
                  {(["ayahs", "pages", "lines"] as PlanUnit[]).map((u) => (
                    <button
                      key={u}
                      type="button"
                      onClick={() => setFormData({ ...formData, unit: u })}
                      className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                        formData.unit === u
                          ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                          : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                      }`}
                    >
                      {UNIT_LABEL[u]}
                    </button>
                  ))}
                </div>
              </div>

              {/* مدة الخطة: أسبوعية / شهرية */}
              <div>
                <label className="block text-sm font-bold mb-3">مدة الخطة</label>
                <div className="grid grid-cols-2 gap-3">
                  {(["weekly", "monthly"] as PlanPeriod[]).map((p) => (
                    <button
                      key={p}
                      type="button"
                      onClick={() => setFormData({ ...formData, period: p })}
                      className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                        formData.period === p
                          ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                          : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                      }`}
                    >
                      {PERIOD_LABEL[p]}
                    </button>
                  ))}
                </div>
              </div>

              {/* Stepper: المقرر الأولي */}
              <Stepper
                label={`المقرر الأولي (${UNIT_LABEL[formData.unit]})`}
                value={formData.startAmount}
                step={UNIT_STEP[formData.unit]}
                onChange={(v) => setFormData({ ...formData, startAmount: v })}
              />

              {/* Stepper: الهدف النهائي */}
              <Stepper
                label={`الهدف النهائي (${UNIT_LABEL[formData.unit]})`}
                value={formData.targetAmount}
                step={UNIT_STEP[formData.unit]}
                onChange={(v) => setFormData({ ...formData, targetAmount: v })}
              />

              {/* Stepper: الزيادة الأسبوعية */}
              <Stepper
                label="الزيادة الأسبوعية"
                value={formData.weeklyIncrease}
                step={UNIT_STEP[formData.unit]}
                onChange={(v) => setFormData({ ...formData, weeklyIncrease: v })}
              />

              <div>
                <label className="block text-sm font-bold mb-3">ملاحظات</label>
                <textarea
                  value={formData.notes}
                  onChange={(e) => setFormData({ ...formData, notes: e.target.value })}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium resize-none"
                  rows={3}
                  placeholder="مثل: خطة صيفية مكثفة"
                />
              </div>

              <button
                type="submit"
                className="w-full bg-teal-600 text-white font-bold py-3 rounded-xl hover:bg-teal-700 transition-all"
              >
                {editingId ? "تحديث الخطة" : "إنشاء الخطة"}
              </button>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}

function Stepper({
  label,
  value,
  step,
  onChange,
}: {
  label: string;
  value: number;
  step: number;
  onChange: (v: number) => void;
}) {
  const round = (n: number) => Math.round(n * 100) / 100;
  return (
    <div>
      <label className="block text-sm font-bold mb-3">{label}</label>
      <div className="flex items-center gap-3">
        <button
          type="button"
          onClick={() => onChange(round(Math.max(0, value - step)))}
          className="w-11 h-11 flex items-center justify-center rounded-xl bg-gray-100 dark:bg-gray-800 text-gray-700 dark:text-gray-200 hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
          aria-label="إنقاص"
        >
          <Minus className="w-4 h-4" />
        </button>
        <input
          type="number"
          step={step}
          min={0}
          value={value}
          onChange={(e) => onChange(round(Number(e.target.value)))}
          className="flex-1 text-center px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-black text-lg"
        />
        <button
          type="button"
          onClick={() => onChange(round(value + step))}
          className="w-11 h-11 flex items-center justify-center rounded-xl bg-teal-600 text-white hover:bg-teal-700 transition-colors"
          aria-label="زيادة"
        >
          <Plus className="w-4 h-4" />
        </button>
      </div>
    </div>
  );
}
