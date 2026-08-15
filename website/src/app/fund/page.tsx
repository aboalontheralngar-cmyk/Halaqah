"use client";

import { FormEvent, ReactNode, useCallback, useEffect, useMemo, useState } from "react";
import { useShallow } from "zustand/react/shallow";
import {
  AlertCircle,
  Banknote,
  CircleDollarSign,
  Loader2,
  Plus,
  Receipt,
  Wallet,
  X,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useStore } from "@/store/useStore";
import { localDateKey } from "@/utils/dateUtils";

type FundType = "subscription" | "donation" | "penalty" | "expense";

type FundTransaction = {
  id: string;
  centerId: string;
  halaqaId?: string;
  studentId?: string;
  behaviorPointId?: string;
  settledNegativePoints: number;
  type: FundType;
  amount: number;
  note?: string;
  date: string;
  createdAt?: string;
};

type NegativePoint = {
  id: string;
  studentId: string;
  amount: number;
  reason: string;
  date: string;
};

const fundTypeLabels: Record<FundType, string> = {
  subscription: "اشتراك",
  donation: "تبرع",
  penalty: "تسوية / غرامة",
  expense: "مصروف",
};

function isMissingColumnError(error: { code?: string; message?: string } | null) {
  if (!error) return false;
  return error.code === "PGRST204" || error.code === "42703" ||
    (error.message || "").toLowerCase().includes("column");
}

export default function FundPage() {
  const {
    students,
    currentCenter,
    currencySymbol,
    fetchStudents
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      currentCenter: state.currentCenter,
      currencySymbol: state.currencySymbol,
      fetchStudents: state.fetchStudents,
    })),
  );
  const [transactions, setTransactions] = useState<FundTransaction[]>([]);
  const [negativePoints, setNegativePoints] = useState<NegativePoint[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showForm, setShowForm] = useState(false);
  const [filterType, setFilterType] = useState<"all" | FundType>("all");
  const [formData, setFormData] = useState({
    type: "subscription" as FundType,
    studentId: "",
    behaviorPointId: "",
    settledNegativePoints: 0,
    amount: 0,
    note: "",
  });

  const halaqaId = currentCenter?.activeHalaqa?.id;

  const loadFund = useCallback(async () => {
    if (!supabase || !currentCenter) {
      setTransactions([]);
      setNegativePoints([]);
      setLoading(false);
      setError(!supabase ? "Supabase غير مهيأ في نسخة الويب." : "اختر المركز والحلقة أولًا.");
      return;
    }

    setLoading(true);
    setError(null);
    try {
      if (students.length === 0) await fetchStudents();

      let txQuery = supabase
        .from("fund_transactions")
        .select("*")
        .eq("center_id", currentCenter.id)
        .order("date", { ascending: false })
        .order("created_at", { ascending: false });
      if (halaqaId) txQuery = txQuery.eq("halaqa_id", halaqaId);
      let txResult = await txQuery;

      // يسمح بقراءة مخطط أقدم مؤقتًا، لكن عمليات التسوية الجديدة تتطلب P1.25.
      if (txResult.error && halaqaId && isMissingColumnError(txResult.error)) {
        txResult = await supabase
          .from("fund_transactions")
          .select("*")
          .eq("center_id", currentCenter.id)
          .order("date", { ascending: false });
      }
      if (txResult.error) throw txResult.error;

      let pointsQuery = supabase
        .from("points")
        .select("id,student_id,amount,reason,date")
        .eq("center_id", currentCenter.id)
        .lt("amount", 0)
        .order("date", { ascending: false });
      if (halaqaId) pointsQuery = pointsQuery.eq("halaqa_id", halaqaId);
      const pointsResult = await pointsQuery;
      if (pointsResult.error) throw pointsResult.error;

      setTransactions(
        (txResult.data || []).map((row) => ({
          id: String(row.id),
          centerId: String(row.center_id),
          halaqaId: row.halaqa_id ? String(row.halaqa_id) : undefined,
          studentId: row.student_id ? String(row.student_id) : undefined,
          behaviorPointId: row.behavior_point_id ? String(row.behavior_point_id) : undefined,
          settledNegativePoints: Number(row.settled_negative_points || 0),
          type: row.type as FundType,
          amount: Number(row.amount || 0),
          note: row.note || undefined,
          date: String(row.date),
          createdAt: row.created_at || undefined,
        }))
      );
      setNegativePoints(
        (pointsResult.data || []).map((row) => ({
          id: String(row.id),
          studentId: String(row.student_id),
          amount: Number(row.amount || 0),
          reason: String(row.reason || "مخالفة"),
          date: String(row.date),
        }))
      );
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "تعذر تحميل الصندوق.");
    } finally {
      setLoading(false);
    }
  }, [currentCenter, fetchStudents, halaqaId, students.length]);

  useEffect(() => {
    void loadFund();
  }, [loadFund]);

  const outstandingByStudent = useMemo(() => {
    const result = new Map<string, number>();
    for (const point of negativePoints) {
      result.set(point.studentId, (result.get(point.studentId) || 0) + Math.abs(point.amount));
    }
    for (const tx of transactions) {
      if (tx.type !== "penalty" || !tx.studentId || tx.settledNegativePoints <= 0) continue;
      result.set(
        tx.studentId,
        Math.max(0, (result.get(tx.studentId) || 0) - tx.settledNegativePoints)
      );
    }
    return result;
  }, [negativePoints, transactions]);

  const selectedOutstanding = formData.studentId
    ? outstandingByStudent.get(formData.studentId) || 0
    : 0;

  const selectedStudentPoints = useMemo(
    () => negativePoints.filter((point) => point.studentId === formData.studentId),
    [formData.studentId, negativePoints]
  );

  const filteredTransactions = useMemo(
    () => filterType === "all" ? transactions : transactions.filter((tx) => tx.type === filterType),
    [filterType, transactions]
  );

  const balance = useMemo(
    () => transactions.reduce((sum, tx) => sum + (tx.type === "expense" ? -tx.amount : tx.amount), 0),
    [transactions]
  );

  const stats = useMemo(() => {
    const totals: Record<FundType, number> = { subscription: 0, donation: 0, penalty: 0, expense: 0 };
    for (const tx of transactions) totals[tx.type] += tx.amount;
    return totals;
  }, [transactions]);

  const totalOutstanding = useMemo(
    () => Array.from(outstandingByStudent.values()).reduce((sum, value) => sum + value, 0),
    [outstandingByStudent]
  );

  const resetForm = () => setFormData({
    type: "subscription",
    studentId: "",
    behaviorPointId: "",
    settledNegativePoints: 0,
    amount: 0,
    note: "",
  });

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    if (!supabase || !currentCenter) return;
    if (formData.amount <= 0) {
      setError("أدخل مبلغًا أكبر من صفر.");
      return;
    }
    if (["subscription", "penalty"].includes(formData.type) && !formData.studentId) {
      setError("اختر الطالب المرتبط بالعملية.");
      return;
    }
    if (formData.settledNegativePoints < 0 || formData.settledNegativePoints > selectedOutstanding) {
      setError(`قيمة التسوية يجب أن تكون بين 0 و${selectedOutstanding} نقطة.`);
      return;
    }

    setSaving(true);
    setError(null);
    const payload: Record<string, unknown> = {
      id: crypto.randomUUID(),
      center_id: currentCenter.id,
      halaqa_id: halaqaId || null,
      student_id: formData.studentId || null,
      behavior_point_id: formData.behaviorPointId || null,
      settled_negative_points: formData.type === "penalty" ? formData.settledNegativePoints : 0,
      type: formData.type,
      amount: formData.amount,
      note: formData.note.trim() || null,
      date: localDateKey(),
      created_at: new Date().toISOString(),
    };

    try {
      let result = await supabase.from("fund_transactions").insert(payload);
      if (result.error && isMissingColumnError(result.error)) {
        if (formData.type === "penalty" && formData.settledNegativePoints > 0) {
          throw new Error("تسوية النقاط تحتاج تنفيذ P1.25 SQL أولًا حتى لا تضيع قيمة التسوية.");
        }
        const legacyPayload = { ...payload };
        delete legacyPayload.halaqa_id;
        delete legacyPayload.behavior_point_id;
        delete legacyPayload.settled_negative_points;
        delete legacyPayload.created_at;
        result = await supabase.from("fund_transactions").insert(legacyPayload);
      }
      if (result.error) throw result.error;
      setShowForm(false);
      resetForm();
      await loadFund();
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : "تعذر حفظ العملية المالية.");
    } finally {
      setSaving(false);
    }
  };

  const studentName = (studentId?: string) =>
    studentId ? students.find((student) => student.id === studentId)?.name || "طالب غير متاح" : "عملية عامة";

  if (loading) {
    return <div className="flex min-h-[45vh] items-center justify-center"><Loader2 className="h-8 w-8 animate-spin text-[var(--primary)]" /></div>;
  }

  return (
    <div className="space-y-6 pb-20" dir="rtl">
      <header className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <div className="flex items-center gap-3">
            <span className="flex h-10 w-10 items-center justify-center rounded-xl bg-[var(--primary-soft)] text-[var(--primary)]"><Wallet className="h-5 w-5" /></span>
            <div><h1 className="text-2xl font-black">صندوق الحلقة</h1><p className="mt-1 text-sm text-[var(--muted)]">سجل مالي حقيقي ومتزامن مع تسويات النقاط السلبية.</p></div>
          </div>
        </div>
        <button onClick={() => setShowForm(true)} className="inline-flex items-center justify-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-3 text-sm font-extrabold text-white hover:bg-[var(--primary-hover)]">
          <Plus className="h-4 w-4" /> عملية جديدة
        </button>
      </header>

      {error && <div className="flex items-start gap-3 rounded-2xl border border-red-200 bg-red-50 p-4 text-sm font-bold text-red-700"><AlertCircle className="mt-0.5 h-5 w-5 shrink-0" /><span>{error}</span></div>}

      <section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon={<CircleDollarSign className="h-5 w-5" />} label="الرصيد" value={balance} suffix={currencySymbol} />
        <StatCard icon={<Banknote className="h-5 w-5" />} label="الاشتراكات والتبرعات" value={stats.subscription + stats.donation} suffix={currencySymbol} />
        <StatCard icon={<Receipt className="h-5 w-5" />} label="المصروفات" value={stats.expense} suffix={currencySymbol} />
        <StatCard icon={<AlertCircle className="h-5 w-5" />} label="نقاط سالبة غير مسوّاة" value={totalOutstanding} suffix="نقطة" />
      </section>

      <section className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-4 sm:p-5">
        <div className="mb-4 flex gap-2 overflow-x-auto pb-1">
          {(["all", "subscription", "donation", "penalty", "expense"] as const).map((type) => (
            <button key={type} onClick={() => setFilterType(type)} className={`whitespace-nowrap rounded-full px-4 py-2 text-xs font-black ${filterType === type ? "bg-[var(--primary)] text-white" : "bg-[var(--surface-soft)] text-[var(--muted)]"}`}>
              {type === "all" ? "الكل" : fundTypeLabels[type]}
            </button>
          ))}
        </div>

        <div className="divide-y divide-[var(--border)]">
          {filteredTransactions.length === 0 ? (
            <div className="py-14 text-center text-sm font-bold text-[var(--muted)]">لا توجد عمليات في هذا النطاق.</div>
          ) : filteredTransactions.map((tx) => (
            <article key={tx.id} className="flex flex-col gap-2 py-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="min-w-0">
                <div className="flex flex-wrap items-center gap-2"><span className="rounded-lg bg-[var(--surface-soft)] px-2.5 py-1 text-[11px] font-black">{fundTypeLabels[tx.type]}</span><strong className="truncate text-sm">{studentName(tx.studentId)}</strong></div>
                <p className="mt-1 text-xs text-[var(--muted)]">{tx.date}{tx.note ? ` • ${tx.note}` : ""}</p>
                {tx.settledNegativePoints > 0 && <p className="mt-1 text-[11px] font-bold text-amber-700">غطّت هذه العملية {tx.settledNegativePoints} نقطة سلبية مع بقاء المخالفة في سجلها.</p>}
              </div>
              <strong className={`text-base ${tx.type === "expense" ? "text-red-600" : "text-[var(--primary)]"}`}>{tx.type === "expense" ? "−" : "+"}{tx.amount.toLocaleString()} {currencySymbol}</strong>
            </article>
          ))}
        </div>
      </section>

      {showForm && (
        <div className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-0 sm:items-center sm:p-4" onClick={() => setShowForm(false)}>
          <div className="max-h-[92vh] w-full max-w-lg overflow-y-auto rounded-t-3xl bg-[var(--surface)] p-5 shadow-2xl sm:rounded-3xl sm:p-6" onClick={(event) => event.stopPropagation()}>
            <div className="mb-5 flex items-center justify-between"><div><h2 className="text-lg font-black">عملية مالية جديدة</h2><p className="mt-1 text-xs text-[var(--muted)]">المبلغ يُحفظ موجبًا، ويُخصم المصروف آليًا من الرصيد.</p></div><button onClick={() => setShowForm(false)} className="rounded-xl p-2 text-[var(--muted)] hover:bg-[var(--surface-soft)]"><X className="h-5 w-5" /></button></div>
            <form onSubmit={handleSubmit} className="space-y-4">
              <Field label="نوع العملية"><select value={formData.type} onChange={(event) => setFormData((old) => ({ ...old, type: event.target.value as FundType, behaviorPointId: "", settledNegativePoints: 0 }))} className="field"><option value="subscription">اشتراك</option><option value="donation">تبرع</option><option value="penalty">غرامة / تسوية</option><option value="expense">مصروف</option></select></Field>

              {(formData.type === "subscription" || formData.type === "penalty") && <Field label="الطالب"><select required value={formData.studentId} onChange={(event) => setFormData((old) => ({ ...old, studentId: event.target.value, behaviorPointId: "", settledNegativePoints: 0 }))} className="field"><option value="">اختر الطالب</option>{[...students].sort((a,b) => a.name.localeCompare(b.name, "ar")).map((student) => <option key={student.id} value={student.id}>{student.name}</option>)}</select></Field>}

              {formData.type === "penalty" && formData.studentId && <div className="space-y-3 rounded-2xl border border-amber-200 bg-amber-50/70 p-4"><p className="text-xs font-black text-amber-800">الرصيد السلبي غير المسوّى: {selectedOutstanding} نقطة</p><Field label="المخالفة المرتبطة (اختياري)"><select value={formData.behaviorPointId} onChange={(event) => setFormData((old) => ({ ...old, behaviorPointId: event.target.value }))} className="field"><option value="">بدون ربط بمخالفة محددة</option>{selectedStudentPoints.map((point) => <option key={point.id} value={point.id}>{point.reason} ({point.amount}) — {point.date}</option>)}</select></Field><Field label="عدد النقاط التي يغطيها السداد"><input type="number" min={0} max={selectedOutstanding} value={formData.settledNegativePoints} onChange={(event) => setFormData((old) => ({ ...old, settledNegativePoints: Number(event.target.value) }))} className="field" /></Field></div>}

              <Field label={`المبلغ (${currencySymbol})`}><input required type="number" min="0.01" step="0.01" value={formData.amount || ""} onChange={(event) => setFormData((old) => ({ ...old, amount: Number(event.target.value) }))} className="field" /></Field>
              <Field label="البيان / الملاحظات"><textarea rows={3} value={formData.note} onChange={(event) => setFormData((old) => ({ ...old, note: event.target.value }))} className="field resize-none" placeholder="مثال: اشتراك شهر محرم" /></Field>
              <button disabled={saving} type="submit" className="flex w-full items-center justify-center gap-2 rounded-xl bg-[var(--primary)] px-4 py-3 text-sm font-black text-white disabled:opacity-50">{saving && <Loader2 className="h-4 w-4 animate-spin" />} حفظ العملية</button>
            </form>
          </div>
        </div>
      )}

      <style jsx>{`
        .field { width: 100%; border: 1px solid var(--border); border-radius: 0.85rem; background: var(--background); padding: 0.75rem 0.9rem; font-size: 0.875rem; font-weight: 700; outline: none; }
        .field:focus { border-color: var(--primary); box-shadow: 0 0 0 3px color-mix(in srgb, var(--primary) 12%, transparent); }
      `}</style>
    </div>
  );
}

function Field({ label, children }: { label: string; children: ReactNode }) {
  return <label className="block"><span className="mb-1.5 block text-xs font-black text-[var(--muted)]">{label}</span>{children}</label>;
}

function StatCard({ icon, label, value, suffix }: { icon: ReactNode; label: string; value: number; suffix: string }) {
  return <article className="rounded-2xl border border-[var(--border)] bg-[var(--surface)] p-4"><div className="flex items-center gap-2 text-[var(--primary)]">{icon}<span className="text-xs font-black text-[var(--muted)]">{label}</span></div><p className="mt-3 text-xl font-black">{value.toLocaleString()} <span className="text-xs font-bold text-[var(--muted)]">{suffix}</span></p></article>;
}
