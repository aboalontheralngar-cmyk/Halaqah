"use client";

import { FormEvent, useEffect, useMemo, useState } from "react";
import {
  CalendarDays,
  CheckCircle2,
  Edit3,
  LockKeyhole,
  Minus,
  Plus,
  Printer,
  Target,
  Trash2,
  X,
} from "lucide-react";
import { SmartPlan, useStore } from "@/store/useStore";

type PlanUnit = SmartPlan["unit"];
type PlanPeriod = SmartPlan["period"];
type PlanFilter = "all" | "active" | "exam" | "passed";

const UNIT_LABEL: Record<PlanUnit, string> = {
  ayahs: "آيات",
  pages: "صفحات",
  lines: "أسطر",
};

const PERIOD_LABEL: Record<PlanPeriod, string> = {
  weekly: "أسبوعية",
  monthly: "شهرية",
};

const today = () => new Date().toISOString().slice(0, 10);

const addDays = (date: string, days: number) => {
  const value = new Date(`${date}T12:00:00`);
  value.setDate(value.getDate() + days);
  return value.toISOString().slice(0, 10);
};

const emptyForm = () => ({
  studentId: "",
  period: "weekly" as PlanPeriod,
  startDate: today(),
  endDate: addDays(today(), 6),
  unit: "ayahs" as PlanUnit,
  newAmount: 5,
  reviewAmount: 10,
  notes: "",
});

export default function PlansPage() {
  const {
    students,
    exams,
    plans,
    fetchPlans,
    addSmartPlan,
    updateSmartPlan,
    deleteSmartPlan,
  } = useStore();
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<SmartPlan | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [filter, setFilter] = useState<PlanFilter>("all");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");

  useEffect(() => {
    fetchPlans().catch((reason) => setError(cleanError(reason)));
  }, [fetchPlans]);

  const visiblePlans = useMemo(
    () =>
      plans.filter((plan) => {
        if (filter === "active") return plan.status === "active";
        if (filter === "exam") {
          return plan.status === "completed" && ["pending", "failed"].includes(plan.testStatus);
        }
        if (filter === "passed") {
          return plan.status === "completed" && plan.testStatus === "passed";
        }
        return true;
      }),
    [plans, filter]
  );

  const gateReason = (studentId: string) => {
    const latest = plans
      .filter((plan) => plan.studentId === studentId && plan.status !== "cancelled")
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0];
    if (!latest) return "";
    if (latest.status === "active") return "للطالب خطة نشطة؛ أكملها أولًا.";
    if (["pending", "failed"].includes(latest.testStatus)) {
      return "لا يمكن إنشاء خطة جديدة قبل اجتياز اختبار الخطة السابقة.";
    }
    return "";
  };

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm());
    setError("");
    setShowForm(true);
  };

  const openEdit = (plan: SmartPlan) => {
    setEditing(plan);
    setForm({
      studentId: plan.studentId,
      period: plan.period,
      startDate: plan.startDate,
      endDate: plan.endDate,
      unit: plan.unit,
      newAmount: plan.newAmount,
      reviewAmount: plan.reviewAmount,
      notes: plan.notes || "",
    });
    setError("");
    setShowForm(true);
  };

  const savePlan = async (event: FormEvent) => {
    event.preventDefault();
    setError("");
    const gate = editing ? "" : gateReason(form.studentId);
    if (gate) return setError(gate);
    if (form.newAmount < 1 || form.reviewAmount < 1 || form.endDate < form.startDate) {
      return setError("تحقق من مقدار المقرر وتاريخ نهاية الخطة.");
    }
    setBusy(true);
    try {
      if (editing) {
        await updateSmartPlan(editing.id, {
          period: form.period,
          startDate: form.startDate,
          endDate: form.endDate,
          unit: form.unit,
          newAmount: form.newAmount,
          reviewAmount: form.reviewAmount,
          notes: form.notes,
        });
      } else {
        await addSmartPlan({
          ...form,
          status: "active",
          testStatus: "not_required",
          notes: form.notes || undefined,
        });
      }
      setShowForm(false);
    } catch (reason) {
      setError(cleanError(reason));
    } finally {
      setBusy(false);
    }
  };

  const changeAmount = async (
    plan: SmartPlan,
    field: "newAmount" | "reviewAmount",
    delta: number
  ) => {
    const value = Math.max(1, plan[field] + delta);
    try {
      await updateSmartPlan(plan.id, { [field]: value });
    } catch (reason) {
      setError(cleanError(reason));
    }
  };

  const completePlan = async (plan: SmartPlan) => {
    if (!window.confirm("سيحتاج الطالب إلى اختبار تجاوز ناجح قبل الخطة التالية. هل تريد إكمال الخطة؟")) return;
    try {
      await updateSmartPlan(plan.id, {
        status: "completed",
        testStatus: "pending",
        completedAt: new Date().toISOString(),
        completionExamId: "",
      });
    } catch (reason) {
      setError(cleanError(reason));
    }
  };

  const approveExam = async (plan: SmartPlan) => {
    const boundary = (plan.completedAt || plan.endDate).slice(0, 10);
    const eligible = exams.filter((exam) => {
      const score = exam.studentScores.find((item) => item.studentId === plan.studentId);
      return exam.date >= boundary && !!score && score.degree >= exam.maxDegree * 0.6;
    });
    if (!eligible.length) {
      return setError("لا يوجد اختبار ناجح بعد إكمال الخطة. سجّل نتيجة اختبار التجاوز أولًا.");
    }
    const description = eligible
      .map((exam, index) => `${index + 1}- ${exam.title} (${exam.date})`)
      .join("\n");
    const selected = window.prompt(`اختر رقم الاختبار الذي تريد اعتماده:\n${description}`, "1");
    if (!selected) return;
    const exam = eligible[Number(selected) - 1];
    if (!exam) return setError("رقم الاختبار غير صحيح.");
    try {
      await updateSmartPlan(plan.id, {
        testStatus: "passed",
        completionExamId: exam.id,
      });
    } catch (reason) {
      setError(cleanError(reason));
    }
  };

  const removePlan = async (plan: SmartPlan) => {
    if (!window.confirm("هل تريد حذف هذه الخطة نهائيًا؟")) return;
    try {
      await deleteSmartPlan(plan.id);
    } catch (reason) {
      setError(cleanError(reason));
    }
  };

  const printPlan = (plan: SmartPlan, cashier: boolean) => {
    const student = students.find((item) => item.id === plan.studentId);
    if (!student) return;
    const days: string[] = [];
    let current = plan.startDate;
    while (current <= plan.endDate) {
      const date = new Date(`${current}T12:00:00`);
      if (date.getDay() !== 5) days.push(current);
      current = addDays(current, 1);
    }
    const rows = days
      .map(
        (date) => `<tr><td>${date}</td><td>${plan.newAmount} ${UNIT_LABEL[plan.unit]}</td><td>${plan.reviewAmount} ${UNIT_LABEL[plan.unit]}</td><td>□</td></tr>`
      )
      .join("");
    const popup = window.open("", "_blank", "width=700,height=800");
    if (!popup) return setError("اسمح بفتح نافذة الطباعة من إعدادات المتصفح.");
    popup.document.write(`<!doctype html><html dir="rtl" lang="ar"><head><meta charset="utf-8"><title>خطة ${student.name}</title><style>
      @font-face{font-family:Tajawal;font-style:normal;font-weight:400;src:url('/fonts/tajawal-arabic-400.woff2') format('woff2');unicode-range:U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08FF,U+FB50-FDFF,U+FE70-FEFC}
      @font-face{font-family:Tajawal;font-style:normal;font-weight:400;src:url('/fonts/tajawal-latin-400.woff2') format('woff2')}
      @font-face{font-family:Tajawal;font-style:normal;font-weight:700;src:url('/fonts/tajawal-arabic-700.woff2') format('woff2');unicode-range:U+0600-06FF,U+0750-077F,U+0870-088E,U+0890-0891,U+0897-08FF,U+FB50-FDFF,U+FE70-FEFC}
      @font-face{font-family:Tajawal;font-style:normal;font-weight:700;src:url('/fonts/tajawal-latin-700.woff2') format('woff2')}
      @page { size: ${cashier ? "80mm auto" : "A4"}; margin: ${cashier ? "4mm" : "15mm"}; }
      *{box-sizing:border-box} body{font-family:Tajawal,Arial,sans-serif;color:#111;margin:0;${cashier ? "width:72mm;font-size:10px" : "font-size:14px"}}
      h1,p{text-align:center;margin:4px}.info{background:#ecfdf5;border:1px solid #99f6e4;padding:8px;margin:10px 0}table{width:100%;border-collapse:collapse}th,td{border:1px solid #777;padding:${cashier ? "3px" : "7px"};text-align:center}th{background:#0f766e;color:white}.notes{margin-top:10px}.sign{display:flex;justify-content:space-between;margin-top:18px}
      </style></head><body><h1>خطة الحفظ ${PERIOD_LABEL[plan.period]}</h1><p>${student.name}</p><div class="info">من ${plan.startDate} إلى ${plan.endDate}<br>الحفظ: ${plan.newAmount} ${UNIT_LABEL[plan.unit]} — المراجعة: ${plan.reviewAmount} ${UNIT_LABEL[plan.unit]}</div><table><thead><tr><th>اليوم</th><th>الحفظ</th><th>المراجعة</th><th>تم</th></tr></thead><tbody>${rows}</tbody></table>${plan.notes ? `<div class="notes">ملاحظات: ${escapeHtml(plan.notes)}</div>` : ""}<div class="sign"><span>المعلم: ______</span><span>ولي الأمر: ______</span></div><script>onload=()=>print()</script></body></html>`);
    popup.document.close();
  };

  const activeCount = plans.filter((plan) => plan.status === "active").length;
  const waitingCount = plans.filter(
    (plan) => plan.status === "completed" && ["pending", "failed"].includes(plan.testStatus)
  ).length;
  const passedCount = plans.filter((plan) => plan.testStatus === "passed").length;

  return (
    <div className="space-y-6 pb-20">
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-black flex items-center gap-3 text-gray-900 dark:text-white">
            <Target className="text-teal-600" /> الخطط الأسبوعية والشهرية
          </h1>
          <p className="text-gray-500 mt-2">خطط محفوظة في السحابة مع بوابة اختبار التجاوز والطباعة.</p>
        </div>
        <button onClick={openCreate} className="bg-teal-600 text-white px-6 py-3 rounded-2xl font-bold flex items-center justify-center gap-2">
          <Plus className="w-5 h-5" /> خطة جديدة
        </button>
      </header>

      {error && <div className="bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-300 p-4 rounded-2xl flex justify-between gap-3"><span>{error}</span><button onClick={() => setError("")}><X className="w-4 h-4" /></button></div>}

      <section className="grid grid-cols-3 gap-3">
        <Stat label="نشطة" value={activeCount} color="text-teal-600" />
        <Stat label="بانتظار الاختبار" value={waitingCount} color="text-orange-600" />
        <Stat label="مجتازة" value={passedCount} color="text-green-600" />
      </section>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {([['all','الكل'],['active','نشطة'],['exam','بانتظار الاختبار'],['passed','مجتازة']] as [PlanFilter,string][]).map(([value,label]) => <button key={value} onClick={() => setFilter(value)} className={`px-4 py-2 rounded-full text-sm font-bold whitespace-nowrap ${filter === value ? 'bg-teal-600 text-white' : 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-300'}`}>{label}</button>)}
      </div>

      <section className="space-y-4">
        {visiblePlans.map((plan) => {
          const student = students.find((item) => item.id === plan.studentId);
          const waiting = plan.status === "completed" && ["pending", "failed"].includes(plan.testStatus);
          const passed = plan.testStatus === "passed";
          return <article key={plan.id} className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-3xl p-5 space-y-4">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <div><h2 className="text-xl font-black text-gray-900 dark:text-white">{student?.name || "طالب غير متاح"}</h2><p className="text-xs text-gray-500 mt-1">{PERIOD_LABEL[plan.period]} · {plan.startDate} — {plan.endDate}</p></div>
              <div className="flex items-center gap-2">
                <StatusBadge plan={plan} />
                <button onClick={() => openEdit(plan)} className="p-2 rounded-xl bg-blue-50 dark:bg-blue-950/30 text-blue-600" title="تعديل"><Edit3 className="w-4 h-4" /></button>
                <button onClick={() => removePlan(plan)} className="p-2 rounded-xl bg-red-50 dark:bg-red-950/30 text-red-600" title="حذف"><Trash2 className="w-4 h-4" /></button>
              </div>
            </div>
            <AmountRow label="الحفظ اليومي" value={plan.newAmount} unit={UNIT_LABEL[plan.unit]} enabled={plan.status === "active"} onMinus={() => changeAmount(plan,'newAmount',-1)} onPlus={() => changeAmount(plan,'newAmount',1)} />
            <AmountRow label="المراجعة اليومية" value={plan.reviewAmount} unit={UNIT_LABEL[plan.unit]} enabled={plan.status === "active"} onMinus={() => changeAmount(plan,'reviewAmount',-1)} onPlus={() => changeAmount(plan,'reviewAmount',1)} />
            {plan.notes && <p className="text-sm text-gray-500">ملاحظات: {plan.notes}</p>}
            {waiting && <div className="bg-orange-50 dark:bg-orange-950/30 border border-orange-200 dark:border-orange-800 text-orange-700 dark:text-orange-300 p-3 rounded-xl text-sm flex items-center gap-2"><LockKeyhole className="w-4 h-4" /> لا تُنشأ خطة جديدة حتى اعتماد اختبار تجاوز ناجح.</div>}
            <div className="flex flex-wrap gap-2 pt-1">
              <button onClick={() => printPlan(plan,false)} className="px-3 py-2 bg-gray-100 dark:bg-gray-800 rounded-xl text-sm font-bold flex items-center gap-2"><Printer className="w-4 h-4" /> A4</button>
              <button onClick={() => printPlan(plan,true)} className="px-3 py-2 bg-gray-100 dark:bg-gray-800 rounded-xl text-sm font-bold flex items-center gap-2"><Printer className="w-4 h-4" /> كاشير 80مم</button>
              {plan.status === "active" && <><button onClick={() => updateSmartPlan(plan.id,{status:'cancelled'})} className="px-3 py-2 border border-red-300 text-red-600 rounded-xl text-sm font-bold">إلغاء</button><button onClick={() => completePlan(plan)} className="px-4 py-2 bg-teal-600 text-white rounded-xl text-sm font-bold flex items-center gap-2"><CheckCircle2 className="w-4 h-4" /> إكمال وطلب اختبار</button></>}
              {waiting && <button onClick={() => approveExam(plan)} className="px-4 py-2 bg-orange-600 text-white rounded-xl text-sm font-bold">اعتماد اختبار التجاوز</button>}
              {passed && <span className="px-3 py-2 text-green-700 dark:text-green-400 font-bold text-sm">يمكن إنشاء الخطة التالية</span>}
            </div>
          </article>;
        })}
        {!visiblePlans.length && <div className="text-center py-16 border-2 border-dashed border-gray-300 dark:border-gray-700 rounded-3xl text-gray-500"><CalendarDays className="w-12 h-12 mx-auto mb-3 opacity-40" />لا توجد خطط مطابقة</div>}
      </section>

      {showForm && <div className="fixed inset-0 z-50 bg-black/50 flex items-end md:items-center justify-center p-0 md:p-4"><div className="bg-white dark:bg-gray-900 rounded-t-3xl md:rounded-3xl w-full max-w-2xl max-h-[92vh] overflow-y-auto p-6"><div className="flex justify-between items-center mb-5"><h2 className="text-xl font-black">{editing ? "تعديل الخطة" : "خطة جديدة"}</h2><button onClick={() => setShowForm(false)}><X /></button></div><form onSubmit={savePlan} className="space-y-5">
        <label className="block"><span className="block text-sm font-bold mb-2">الطالب</span><select required disabled={!!editing} value={form.studentId} onChange={(event) => setForm({...form,studentId:event.target.value})} className="w-full p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700"><option value="">اختر الطالب</option>{students.map((student) => <option key={student.id} value={student.id}>{student.name}</option>)}</select></label>
        {!editing && form.studentId && gateReason(form.studentId) && <div className="p-3 bg-orange-50 text-orange-700 rounded-xl text-sm font-bold">{gateReason(form.studentId)}</div>}
        <div className="grid grid-cols-2 gap-3">{(['weekly','monthly'] as PlanPeriod[]).map((period) => <button type="button" key={period} onClick={() => setForm({...form,period,endDate:addDays(form.startDate,period === 'weekly' ? 6 : 29)})} className={`p-3 rounded-xl font-bold border ${form.period === period ? 'bg-teal-50 border-teal-500 text-teal-700' : 'border-gray-200 dark:border-gray-700'}`}>{PERIOD_LABEL[period]}</button>)}</div>
        <label className="block"><span className="block text-sm font-bold mb-2">وحدة المقرر</span><select value={form.unit} onChange={(event) => setForm({...form,unit:event.target.value as PlanUnit})} className="w-full p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700">{(['ayahs','pages','lines'] as PlanUnit[]).map((unit) => <option key={unit} value={unit}>{UNIT_LABEL[unit]}</option>)}</select></label>
        <Stepper label={`الحفظ اليومي (${UNIT_LABEL[form.unit]})`} value={form.newAmount} onChange={(value) => setForm({...form,newAmount:value})} />
        <Stepper label={`المراجعة اليومية (${UNIT_LABEL[form.unit]})`} value={form.reviewAmount} onChange={(value) => setForm({...form,reviewAmount:value})} />
        <div className="grid grid-cols-2 gap-3"><label><span className="block text-sm font-bold mb-2">من</span><input type="date" required value={form.startDate} onChange={(event) => setForm({...form,startDate:event.target.value,endDate:addDays(event.target.value,form.period === 'weekly' ? 6 : 29)})} className="w-full p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700" /></label><label><span className="block text-sm font-bold mb-2">إلى</span><input type="date" required value={form.endDate} min={form.startDate} onChange={(event) => setForm({...form,endDate:event.target.value})} className="w-full p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700" /></label></div>
        <label className="block"><span className="block text-sm font-bold mb-2">ملاحظات</span><textarea value={form.notes} onChange={(event) => setForm({...form,notes:event.target.value})} rows={3} className="w-full p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700" /></label>
        {error && <p className="text-red-600 text-sm font-bold">{error}</p>}
        <button disabled={busy || (!editing && !!form.studentId && !!gateReason(form.studentId))} className="w-full bg-teal-600 disabled:bg-gray-400 text-white p-3 rounded-xl font-black">{busy ? "جارٍ الحفظ..." : editing ? "حفظ التعديل" : "إنشاء الخطة"}</button>
      </form></div></div>}
    </div>
  );
}

function Stepper({label,value,onChange}:{label:string;value:number;onChange:(value:number)=>void}) { return <div><p className="text-sm font-bold mb-2">{label}</p><div className="flex items-center gap-3"><button type="button" onClick={() => onChange(Math.max(1,value-1))} className="w-11 h-11 rounded-xl bg-gray-100 dark:bg-gray-800 flex items-center justify-center"><Minus className="w-4 h-4" /></button><input type="number" min={1} value={value} onChange={(event) => onChange(Math.max(1,Number(event.target.value)||1))} className="flex-1 text-center p-3 rounded-xl border bg-white dark:bg-gray-800 dark:border-gray-700 font-black" /><button type="button" onClick={() => onChange(value+1)} className="w-11 h-11 rounded-xl bg-teal-600 text-white flex items-center justify-center"><Plus className="w-4 h-4" /></button></div></div>; }

function AmountRow({label,value,unit,enabled,onMinus,onPlus}:{label:string;value:number;unit:string;enabled:boolean;onMinus:()=>void;onPlus:()=>void}) { return <div className="flex items-center gap-2"><span className="flex-1 text-sm font-bold">{label}</span><button disabled={!enabled || value<=1} onClick={onMinus} className="p-2 disabled:opacity-30"><Minus className="w-4 h-4" /></button><strong className="w-24 text-center text-teal-700 dark:text-teal-400">{value} {unit}</strong><button disabled={!enabled} onClick={onPlus} className="p-2 text-teal-600 disabled:opacity-30"><Plus className="w-5 h-5" /></button></div>; }

function Stat({label,value,color}:{label:string;value:number;color:string}) { return <div className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-2xl p-4 text-center"><strong className={`text-2xl ${color}`}>{value}</strong><p className="text-xs text-gray-500 mt-1">{label}</p></div>; }

function StatusBadge({plan}:{plan:SmartPlan}) { let label="نشطة", style="bg-teal-50 text-teal-700 dark:bg-teal-950/30 dark:text-teal-300"; if(plan.status==='cancelled'){label="ملغاة";style="bg-red-50 text-red-700 dark:bg-red-950/30 dark:text-red-300";} else if(['pending','failed'].includes(plan.testStatus)){label="بانتظار الاختبار";style="bg-orange-50 text-orange-700 dark:bg-orange-950/30 dark:text-orange-300";} else if(plan.testStatus==='passed'){label="مجتازة";style="bg-green-50 text-green-700 dark:bg-green-950/30 dark:text-green-300";} else if(plan.status==='completed'){label="مكتملة قديمة";style="bg-gray-100 text-gray-700 dark:bg-gray-800 dark:text-gray-300";} return <span className={`px-3 py-1 rounded-full text-xs font-bold ${style}`}>{label}</span>; }

function cleanError(reason: unknown) { const text = reason instanceof Error ? reason.message : String(reason); if(text.includes('previous_plan_requires_passing_exam')) return 'لا يمكن إنشاء خطة جديدة قبل اجتياز اختبار الخطة السابقة.'; if(text.includes('invalid_or_early_completion_exam')) return 'الاختبار غير ناجح أو تاريخه يسبق إكمال الخطة.'; return text; }

function escapeHtml(value:string) { return value.replace(/[&<>'"]/g,(char)=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[char] || char)); }
