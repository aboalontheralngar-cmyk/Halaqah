"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useShallow } from "zustand/react/shallow";
import Link from "next/link";
import {
  AlertTriangle,
  BookOpen,
  CalendarDays,
  CheckCircle2,
  CircleHelp,
  ClipboardCheck,
  Loader2,
  LockKeyhole,
  PersonStanding,
  RefreshCw,
  ShieldCheck,
  UserX,
} from "lucide-react";

import { MetricCard, PageHeader, Surface } from "@/components/ui/AppDesign";
import {
  evaluateDailyClosing,
  isWeeklyHoliday,
  type DailyClosingReceipt,
  type DailyClosingState,
  type DailyClosingStatus,
} from "@/lib/dailyClosing";
import { useStore } from "@/store/useStore";
import { localDateKey } from "@/utils/dateUtils";

const STATE_VIEW: Record<DailyClosingState, { label: string; className: string }> = {
  completed: { label: "مكتمل", className: "bg-green-100 text-green-800 dark:bg-green-950 dark:text-green-200" },
  absent: { label: "غائب", className: "bg-red-100 text-red-800 dark:bg-red-950 dark:text-red-200" },
  no_recitation: { label: "لم يسمّع", className: "bg-orange-100 text-orange-800 dark:bg-orange-950 dark:text-orange-200" },
  unrecorded: { label: "بلا تسجيل", className: "bg-amber-100 text-amber-800 dark:bg-amber-950 dark:text-amber-200" },
  excused: { label: "مستثنى", className: "bg-teal-100 text-teal-800 dark:bg-teal-950 dark:text-teal-200" },
  held: { label: "توقف مؤقت", className: "bg-slate-100 text-slate-800 dark:bg-slate-900 dark:text-slate-200" },
  activity: { label: "نشاط", className: "bg-purple-100 text-purple-800 dark:bg-purple-950 dark:text-purple-200" },
  talaqqin: { label: "تلقين", className: "bg-cyan-100 text-cyan-800 dark:bg-cyan-950 dark:text-cyan-200" },
  holiday: { label: "إجازة", className: "bg-blue-100 text-blue-800 dark:bg-blue-950 dark:text-blue-200" },
};

const BLOCKER_LABEL: Record<NonNullable<DailyClosingStatus["blocker"]>, string> = {
  halaqa_required: "اختر الحلقة أولًا حتى يبقى الإغلاق محصورًا بطلابها.",
  future_date: "لا يمكن إغلاق تاريخ مستقبلي.",
  before_end_time: "لم ينتهِ دوام الحلقة بعد.",
  study_suspended: "اليوم إجازة أو الدراسة معلقة؛ لا غياب ولا نقاط سلبية.",
  already_closed: "تم إغلاق هذا اليوم وحفظ إيصال العملية.",
};

function todayKey(): string {
  return localDateKey();
}

export default function DailyClosingPage() {
  const {
    students,
    attendance,
    memorization,
    homeworkGrades,
    vacations,
    studentHolds,
    suspendedDates,
    studySuspensions,
    weeklyHolidayDays,
    currentCenter,
    fetchCenterData,
    getDailyClosingStatus,
    closeDailyOperations
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      attendance: state.attendance,
      memorization: state.memorization,
      homeworkGrades: state.homeworkGrades,
      vacations: state.vacations,
      studentHolds: state.studentHolds,
      suspendedDates: state.suspendedDates,
      studySuspensions: state.studySuspensions,
      weeklyHolidayDays: state.weeklyHolidayDays,
      currentCenter: state.currentCenter,
      fetchCenterData: state.fetchCenterData,
      getDailyClosingStatus: state.getDailyClosingStatus,
      closeDailyOperations: state.closeDailyOperations,
    })),
  );
  const [date, setDate] = useState(todayKey());
  const [filter, setFilter] = useState<"all" | "action" | "completed" | "exempt">("all");
  const [status, setStatus] = useState<DailyClosingStatus | null>(null);
  const [receipt, setReceipt] = useState<DailyClosingReceipt | null>(null);
  const [loadingStatus, setLoadingStatus] = useState(false);
  const [closing, setClosing] = useState(false);
  const [statusError, setStatusError] = useState<string | null>(null);

  const explicitSuspension = studySuspensions.find((item) => item.date === date);
  const weeklyDayOff = isWeeklyHoliday(date, weeklyHolidayDays);
  const isHoliday = suspendedDates.includes(date) || weeklyDayOff;
  const summary = useMemo(
    () =>
      evaluateDailyClosing({
        students,
        attendance,
        memorization,
        homeworkGrades,
        vacations,
        studentHolds,
        date,
        isHoliday,
      }),
    [attendance, date, homeworkGrades, isHoliday, memorization, studentHolds, students, vacations],
  );

  const refreshStatus = useCallback(async () => {
    if (!currentCenter) return;
    setLoadingStatus(true);
    setStatusError(null);
    try {
      setStatus(await getDailyClosingStatus(date));
    } catch (error) {
      setStatus(null);
      setStatusError(error instanceof Error ? error.message : "تعذر قراءة حالة إغلاق اليوم");
    } finally {
      setLoadingStatus(false);
    }
  }, [currentCenter, date, getDailyClosingStatus]);

  useEffect(() => {
    void fetchCenterData();
  }, [fetchCenterData]);

  useEffect(() => {
    if (!currentCenter) return;
    let cancelled = false;
    void getDailyClosingStatus(date)
      .then((result) => {
        if (cancelled) return;
        setStatus(result);
        setStatusError(null);
      })
      .catch((error: unknown) => {
        if (cancelled) return;
        setStatus(null);
        setStatusError(error instanceof Error ? error.message : "تعذر قراءة حالة إغلاق اليوم");
      })
      .finally(() => {
        if (!cancelled) setLoadingStatus(false);
      });
    return () => {
      cancelled = true;
    };
  }, [currentCenter, date, getDailyClosingStatus]);

  const visibleItems = useMemo(() => {
    if (filter === "action") {
      return summary.items.filter((item) =>
        ["absent", "no_recitation", "unrecorded"].includes(item.state),
      );
    }
    if (filter === "completed") {
      return summary.items.filter((item) => item.state === "completed");
    }
    if (filter === "exempt") {
      return summary.items.filter((item) => ["excused", "holiday"].includes(item.state));
    }
    return summary.items;
  }, [filter, summary.items]);

  const handleClose = async () => {
    if (!status?.canClose || closing) return;
    const warning = summary.actionRequired > 0
      ? `سيحوّل النظام ${summary.unrecorded} طالبًا بلا حضور إلى غياب، ويضيف النقاط السلبية المستحقة بعد استثناء الإجازات والتوقيفات. هل تعتمد الإغلاق؟`
      : "كل السجلات مكتملة. هل تريد اعتماد إغلاق اليوم؟";
    if (!window.confirm(warning)) return;
    setClosing(true);
    setStatusError(null);
    try {
      const result = await closeDailyOperations(date);
      setReceipt(result);
      await refreshStatus();
    } catch (error) {
      setStatusError(error instanceof Error ? error.message : "تعذر إغلاق اليوم");
    } finally {
      setClosing(false);
    }
  };

  return (
    <div className="space-y-7 pb-20">
      <PageHeader
        title="مركز إغلاق اليوم"
        description="مراجعة عمليات اليوم واعتماد ذري للحضور والتسميع والإجازات والنقاط؛ إما تُحفظ العملية كاملة أو لا يُحفظ منها شيء."
        icon={ClipboardCheck}
        actions={
          <label className="flex items-center gap-2 rounded-2xl border border-[var(--border)] bg-[var(--surface)] px-4 py-3 text-sm font-bold">
            <CalendarDays className="h-5 w-5 text-teal-700" aria-hidden="true" />
            <span className="sr-only">تاريخ المراجعة</span>
            <input
              type="date"
              value={date}
              max={todayKey()}
              onChange={(event) => {
                setReceipt(null);
                setStatus(null);
                setStatusError(null);
                setLoadingStatus(true);
                setDate(event.target.value);
              }}
              className="bg-transparent outline-none"
            />
          </label>
        }
      />

      {(isHoliday || status?.isSuspended) && (
        <Surface className="border-blue-200 bg-blue-50 p-5 text-blue-900 dark:border-blue-900 dark:bg-blue-950/40 dark:text-blue-100">
          <div className="flex items-start gap-3">
            <ShieldCheck className="mt-0.5 h-6 w-6 shrink-0" aria-hidden="true" />
            <div>
              <p className="font-extrabold">الدراسة معلقة في هذا اليوم</p>
              <p className="mt-1 text-sm leading-6 opacity-80">
                {weeklyDayOff || status?.isWeeklyHoliday
                  ? "إجازة أسبوعية معتمدة."
                  : explicitSuspension?.reason || status?.suspensionReason || "تعليق دراسة معتمد."} لا يُحتسب غياب أو عدم تسميع.
              </p>
            </div>
          </div>
        </Surface>
      )}

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <MetricCard label="مكتمل" value={summary.completed} icon={CheckCircle2} tone="green" />
        <MetricCard label="بلا حضور" value={summary.unrecorded} icon={CircleHelp} tone="amber" />
        <MetricCard label="غائب" value={summary.absent} icon={UserX} tone="red" />
        <MetricCard label="لم يسمّع" value={summary.noRecitation} icon={BookOpen} tone="amber" />
        <MetricCard label="مستثنى" value={summary.excused} icon={ShieldCheck} tone="teal" />
      </div>

      <Surface className="p-5 md:p-6">
        <div className="flex flex-col gap-5 xl:flex-row xl:items-center xl:justify-between">
          <div className="min-w-0">
            <div className="flex items-center gap-3">
              <span className={`flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl ${status?.isClosed ? "bg-green-100 text-green-700" : "bg-teal-100 text-teal-700"}`}>
                {loadingStatus ? <Loader2 className="h-5 w-5 animate-spin" /> : status?.isClosed ? <CheckCircle2 className="h-5 w-5" /> : <LockKeyhole className="h-5 w-5" />}
              </span>
              <div>
                <p className="font-extrabold text-[var(--foreground)]">
                  {status?.isClosed ? "اليوم مغلق ومعتمد" : "جاهزية الإغلاق السحابي"}
                </p>
                <p className="mt-1 text-xs font-medium text-gray-500">
                  {status?.blocker
                    ? BLOCKER_LABEL[status.blocker]
                    : `يمكن الإغلاق بعد ${status?.sessionEndTime || "وقت انتهاء الدوام"} (${status?.timezoneName || "توقيت المركز"}).`}
                </p>
              </div>
            </div>
            {statusError && (
              <p className="mt-4 flex items-start gap-2 rounded-2xl bg-red-50 p-3 text-xs font-bold leading-5 text-red-700 dark:bg-red-950/30 dark:text-red-200">
                <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0" />
                {statusError}
              </p>
            )}
          </div>
          <div className="flex flex-wrap gap-2">
            <button
              type="button"
              onClick={() => void refreshStatus()}
              disabled={loadingStatus || closing}
              className="inline-flex items-center gap-2 rounded-xl border border-[var(--border)] px-4 py-2.5 text-sm font-bold disabled:opacity-50"
            >
              <RefreshCw className={`h-4 w-4 ${loadingStatus ? "animate-spin" : ""}`} />
              تحديث
            </button>
            <button
              type="button"
              onClick={() => void handleClose()}
              disabled={!status?.canClose || closing || loadingStatus}
              className="inline-flex items-center gap-2 rounded-xl bg-[#1f6b5d] px-5 py-2.5 text-sm font-extrabold text-white shadow-sm disabled:cursor-not-allowed disabled:opacity-45"
            >
              {closing ? <Loader2 className="h-4 w-4 animate-spin" /> : <LockKeyhole className="h-4 w-4" />}
              {closing ? "جارٍ الإغلاق..." : "اعتماد إغلاق اليوم"}
            </button>
          </div>
        </div>
      </Surface>

      {receipt && (
        <Surface className="border-green-200 bg-green-50 p-5 dark:border-green-900 dark:bg-green-950/30">
          <div className="flex items-start gap-3 text-green-900 dark:text-green-100">
            <CheckCircle2 className="mt-0.5 h-6 w-6 shrink-0" />
            <div>
              <p className="font-extrabold">تم إغلاق اليوم بنجاح</p>
              <p className="mt-2 text-sm leading-7">
                أُنشئ {receipt.recordsCreated} سجل حضور، وصُحح {receipt.recordsExcused} سجل إجازة، وأضيفت {receipt.absencePointsAdded} عقوبة غياب و{receipt.noRecitationPointsAdded} عقوبة عدم تسميع.
              </p>
              <p className="mt-1 text-xs opacity-70">رقم الإيصال: {receipt.closingId}</p>
            </div>
          </div>
        </Surface>
      )}

      <Surface className="p-4 md:p-6">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-center lg:justify-between">
          <div className="flex max-w-full gap-2 overflow-x-auto pb-1">
            {([
              ["all", `الكل ${summary.items.length}`],
              ["action", `يحتاج إجراء ${summary.actionRequired}`],
              ["completed", `مكتمل ${summary.completed}`],
              ["exempt", `مستثنى ${summary.excused}`],
            ] as const).map(([value, label]) => (
              <button
                key={value}
                type="button"
                onClick={() => setFilter(value)}
                className={`whitespace-nowrap rounded-full px-4 py-2 text-sm font-bold transition ${filter === value ? "bg-[#1f6b5d] text-white" : "bg-[var(--surface-soft)] text-gray-600 dark:text-gray-300"}`}
              >
                {label}
              </button>
            ))}
          </div>
          <div className="flex flex-wrap gap-2">
            <Link href="/attendance" className="rounded-xl bg-[#1f6b5d] px-4 py-2.5 text-sm font-bold text-white">استكمال الحضور</Link>
            <Link href="/memorization" className="rounded-xl border border-[var(--border)] px-4 py-2.5 text-sm font-bold">استكمال التسميع</Link>
          </div>
        </div>
      </Surface>

      <Surface className="overflow-hidden">
        <div className="divide-y divide-[var(--border)]">
          {visibleItems.length === 0 ? (
            <div className="p-12 text-center text-sm font-bold text-gray-500">لا توجد حالات ضمن هذا المرشح.</div>
          ) : (
            visibleItems.map((item) => {
              const view = STATE_VIEW[item.state];
              return (
                <div key={item.student.id} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between md:p-5">
                  <div className="flex min-w-0 items-center gap-3">
                    <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-2xl bg-[var(--surface-soft)] text-[#1f6b5d]">
                      <PersonStanding className="h-5 w-5" aria-hidden="true" />
                    </span>
                    <div className="min-w-0">
                      <p className="truncate font-extrabold text-[var(--foreground)]">{item.student.name}</p>
                      <p className="mt-1 text-xs font-medium text-[var(--muted)]">{item.detail}</p>
                    </div>
                  </div>
                  <span className={`w-fit shrink-0 rounded-full px-3 py-1.5 text-xs font-extrabold ${view.className}`}>{view.label}</span>
                </div>
              );
            })
          )}
        </div>
      </Surface>
    </div>
  );
}
