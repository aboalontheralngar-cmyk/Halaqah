"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { AlertTriangle, CheckCircle2, History, Loader2, RefreshCw, ShieldCheck } from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useStore } from "@/store/useStore";

type AuditEventRow = {
  id: string;
  event_type: string;
  entity_type: string;
  entity_id: string | null;
  outcome: "success" | "failure" | "denied";
  metadata: Record<string, unknown> | null;
  created_at: string;
};

const eventLabels: Record<string, string> = {
  "backup.cloud_uploaded": "رفع نسخة مشفرة إلى السحابة",
  "backup.cloud_downloaded": "تنزيل نسخة مشفرة من السحابة",
  "backup.cloud_deleted": "حذف نسخة سحابية",
  "backup.cloud_pruned": "تنظيف النسخ السحابية القديمة",
  "students.insert": "إضافة طالب",
  "students.update": "تعديل بيانات طالب",
  "students.delete": "حذف طالب",
  "attendance.insert": "تسجيل حضور",
  "attendance.update": "تعديل حضور",
  "memorization.insert": "إضافة سجل تسميع",
  "memorization.update": "تعديل سجل تسميع",
  "memorization.delete": "حذف سجل تسميع",
  "points.insert": "إضافة نقاط",
  "points.update": "تعديل نقاط",
  "points.delete": "حذف نقاط",
};

export default function AuditLogPage() {
  const currentCenter = useStore((state) => state.currentCenter);
  const [events, setEvents] = useState<AuditEventRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [outcome, setOutcome] = useState<"all" | AuditEventRow["outcome"]>("all");

  const loadEvents = useCallback(async () => {
    if (!supabase || !currentCenter) {
      setError("إعداد Supabase أو المركز الحالي غير متاح");
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    let query = supabase
      .from("audit_events")
      .select("id,event_type,entity_type,entity_id,outcome,metadata,created_at")
      .eq("center_id", currentCenter.id)
      .order("created_at", { ascending: false })
      .limit(300);
    if (currentCenter.activeHalaqa?.id) {
      query = query.or(`halaqa_id.eq.${currentCenter.activeHalaqa.id},halaqa_id.is.null`);
    }
    const { data, error: queryError } = await query;
    if (queryError) {
      setError("تعذر تحميل السجل. تأكد من تنفيذ migration الخاص بمرحلة P6.2.");
      setEvents([]);
    } else {
      setEvents((data ?? []) as AuditEventRow[]);
    }
    setLoading(false);
  }, [currentCenter]);

  useEffect(() => {
    const timer = window.setTimeout(() => void loadEvents(), 0);
    return () => window.clearTimeout(timer);
  }, [loadEvents]);

  const filteredEvents = useMemo(
    () => events.filter((event) => outcome === "all" || event.outcome === outcome),
    [events, outcome],
  );

  return (
    <main className="max-w-6xl mx-auto space-y-6 pb-20" dir="rtl">
      <header className="flex flex-col md:flex-row md:items-center justify-between gap-4 rounded-[2.5rem] bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-7 shadow-sm">
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-2xl bg-teal-50 dark:bg-teal-900/20 flex items-center justify-center">
            <ShieldCheck className="w-8 h-8 text-teal-600" />
          </div>
          <div>
            <h1 className="text-2xl font-black text-gray-900 dark:text-white">سجل التدقيق</h1>
            <p className="text-sm text-gray-500 mt-1">أحداث حساسة بلا كلمات مرور أو بيانات اتصال أو محتوى نسخ.</p>
          </div>
        </div>
        <button onClick={() => void loadEvents()} disabled={loading} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-teal-600 text-white px-5 py-3 font-bold disabled:opacity-50">
          <RefreshCw className="w-4 h-4" /> تحديث
        </button>
      </header>

      <div className="flex gap-2 overflow-x-auto pb-1">
        {(["all", "success", "failure", "denied"] as const).map((value) => (
          <button key={value} onClick={() => setOutcome(value)} className={`px-5 py-2.5 rounded-xl text-xs font-black whitespace-nowrap ${outcome === value ? "bg-teal-600 text-white" : "bg-white dark:bg-gray-900 text-gray-500 border border-gray-100 dark:border-gray-800"}`}>
            {{ all: "الكل", success: "ناجح", failure: "فشل", denied: "مرفوض" }[value]}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="min-h-64 flex items-center justify-center"><Loader2 className="w-9 h-9 text-teal-600 animate-spin" /></div>
      ) : error ? (
        <div className="rounded-3xl border border-rose-200 bg-rose-50 dark:bg-rose-950/20 p-7 text-rose-800 dark:text-rose-200 flex gap-3"><AlertTriangle className="w-6 h-6 shrink-0" /><p>{error}</p></div>
      ) : filteredEvents.length === 0 ? (
        <div className="min-h-64 rounded-3xl border border-dashed border-gray-200 dark:border-gray-800 flex flex-col items-center justify-center text-gray-400"><History className="w-10 h-10 mb-3" /><p>لا توجد أحداث مطابقة</p></div>
      ) : (
        <section className="space-y-3">
          {filteredEvents.map((event) => {
            const failed = event.outcome !== "success";
            const changedFields = Array.isArray(event.metadata?.changed_fields)
              ? (event.metadata?.changed_fields as string[]).join("، ")
              : null;
            return (
              <article key={event.id} className="rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-5 flex items-start gap-4 shadow-sm">
                <div className={`w-11 h-11 rounded-2xl flex items-center justify-center shrink-0 ${failed ? "bg-rose-50 dark:bg-rose-900/20" : "bg-emerald-50 dark:bg-emerald-900/20"}`}>
                  {failed ? <AlertTriangle className="w-5 h-5 text-rose-600" /> : <CheckCircle2 className="w-5 h-5 text-emerald-600" />}
                </div>
                <div className="min-w-0 flex-1">
                  <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                    <h2 className="font-black text-gray-900 dark:text-white">{eventLabels[event.event_type] ?? event.event_type}</h2>
                    <time className="text-xs text-gray-400" dateTime={event.created_at}>{new Date(event.created_at).toLocaleString("ar")}</time>
                  </div>
                  <p className="text-xs text-gray-500 mt-2">الكيان: {event.entity_type}{event.entity_id ? ` • ${event.entity_id}` : ""}</p>
                  {changedFields && <p className="text-xs text-gray-400 mt-2 truncate">الحقول المعدلة: {changedFields}</p>}
                </div>
              </article>
            );
          })}
        </section>
      )}
    </main>
  );
}
