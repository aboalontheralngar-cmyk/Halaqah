"use client";

import { useState, useMemo } from "react";
import {
  Plus,
  Calendar,
  TrendingUp,
  BookOpen,
  ArrowUp,
  Edit,
  Trash2,
  X,
  Target,
  Zap,
  AlertCircle,
  CheckCircle,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface Plan {
  id: string;
  studentId: string;
  type: "ayahs" | "pages";
  startAmount: number;
  currentAmount: number;
  targetAmount: number;
  weeklyIncrease: number;
  startDate: string;
  status: "active" | "completed" | "paused";
  notes?: string;
}

interface RecitationLevel {
  studentId: string;
  level: number;
  lastUpdated: string;
  nextTarget: number;
}

export default function PlansPage() {
  const { students } = useStore();

  // محاكاة بيانات الخطط
  const [plans, setPlans] = useState<Plan[]>([
    {
      id: "1",
      studentId: "1",
      type: "ayahs",
      startAmount: 5,
      currentAmount: 15,
      targetAmount: 20,
      weeklyIncrease: 2,
      startDate: "2024-05-15",
      status: "active",
      notes: "خطة تصاعدية منتظمة",
    },
    {
      id: "2",
      studentId: "2",
      type: "pages",
      startAmount: 0.5,
      currentAmount: 1.5,
      targetAmount: 2,
      weeklyIncrease: 0.25,
      startDate: "2024-06-01",
      status: "active",
      notes: "",
    },
  ]);

  const [recitationLevels, setRecitationLevels] = useState<RecitationLevel[]>([
    { studentId: "1", level: 3, lastUpdated: "2024-06-10", nextTarget: 4 },
    { studentId: "2", level: 1, lastUpdated: "2024-06-08", nextTarget: 2 },
  ]);

  const [showForm, setShowForm] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    studentId: "",
    type: "ayahs" as "ayahs" | "pages",
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

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (editingId) {
      setPlans(
        plans.map((p) =>
          p.id === editingId
            ? {
                ...p,
                type: formData.type,
                startAmount: formData.startAmount,
                currentAmount: formData.startAmount,
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
        type: formData.type,
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
    setFormData({
      studentId: "",
      type: "ayahs",
      startAmount: 5,
      targetAmount: 20,
      weeklyIncrease: 2,
      notes: "",
    });
  };

  const getProgressPercent = (current: number, target: number) => {
    return Math.min((current / target) * 100, 100);
  };

  const getProgressColor = (percent: number) => {
    if (percent >= 100) return "bg-green-500";
    if (percent >= 75) return "bg-blue-500";
    if (percent >= 50) return "bg-yellow-500";
    return "bg-orange-500";
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
                  (plans.reduce((sum, p) => sum + getProgressPercent(p.currentAmount, p.targetAmount), 0) /
                    plans.length) * 10
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

          return (
            <div key={studentId} className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-200 dark:border-gray-800 p-8 space-y-6">
              <div className="flex items-center justify-between">
                <div>
                  <h2 className="text-2xl font-black text-gray-900 dark:text-white">
                    {student.name}
                  </h2>
                  <p className="text-sm text-gray-500 dark:text-gray-400 mt-1">
                    المستوى: <span className="font-bold text-teal-600">{student.level}</span>
                  </p>
                </div>
                <div className="w-12 h-12 rounded-2xl bg-teal-100 dark:bg-teal-900/30 flex items-center justify-center text-teal-600 dark:text-teal-400 font-black">
                  {student.name[0]}
                </div>
              </div>

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
                          <div className="flex items-center gap-2">
                            <BookOpen className="w-5 h-5 text-teal-600" />
                            <h3 className="font-bold text-gray-900 dark:text-white">
                              {plan.type === "ayahs" ? "آيات" : "صفحات"}
                            </h3>
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
                                type: plan.type,
                                startAmount: plan.startAmount,
                                targetAmount: plan.targetAmount,
                                weeklyIncrease: plan.weeklyIncrease,
                                notes: plan.notes || "",
                              });
                              setEditingId(plan.id);
                              setShowForm(true);
                            }}
                            className="p-2 text-blue-600 hover:bg-blue-100 rounded-lg transition-colors"
                          >
                            <Edit className="w-4 h-4" />
                          </button>
                          <button
                            onClick={() =>
                              setPlans(plans.filter((p) => p.id !== plan.id))
                            }
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
                          <p className={`text-lg font-black ${
                            isCompleted ? "text-green-600" : "text-orange-600"
                          }`}>
                            {Math.round(progress)}%
                          </p>
                        </div>
                      </div>

                      {/* Progress Bar */}
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
                onClick={() => setShowForm(false)}
                className="text-gray-400 hover:text-gray-600"
              >
                <X className="w-6 h-6" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label className="block text-sm font-bold mb-3">الطالب</label>
                <select
                  value={formData.studentId}
                  onChange={(e) =>
                    setFormData({ ...formData, studentId: e.target.value })
                  }
                  disabled={!!editingId}
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium disabled:opacity-50"
                  required
                >
                  <option value="">اختر طالباً</option>
                  {students.map((s) => (
                    <option key={s.id} value={s.id}>
                      {s.name}
                    </option>
                  ))}
                </select>
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">نوع المقرر</label>
                <select
                  value={formData.type}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      type: e.target.value as "ayahs" | "pages",
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                >
                  <option value="ayahs">آيات</option>
                  <option value="pages">صفحات</option>
                </select>
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">المقرر الأولي</label>
                <input
                  type="number"
                  step="0.5"
                  value={formData.startAmount}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      startAmount: Number(e.target.value),
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">الهدف النهائي</label>
                <input
                  type="number"
                  step="0.5"
                  value={formData.targetAmount}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      targetAmount: Number(e.target.value),
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">
                  الزيادة الأسبوعية
                </label>
                <input
                  type="number"
                  step="0.5"
                  value={formData.weeklyIncrease}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      weeklyIncrease: Number(e.target.value),
                    })
                  }
                  className="w-full px-4 py-2 border border-gray-300 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800 font-medium"
                  required
                />
              </div>

              <div>
                <label className="block text-sm font-bold mb-3">ملاحظات</label>
                <textarea
                  value={formData.notes}
                  onChange={(e) =>
                    setFormData({ ...formData, notes: e.target.value })
                  }
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
