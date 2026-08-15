"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useParams, useRouter, useSearchParams } from "next/navigation";
import { useShallow } from "zustand/react/shallow";
import {
  ArrowRight,
  BarChart3,
  BookOpen,
  Building2,
  CalendarDays,
  Loader2,
  RefreshCw,
  Trophy,
  UserRound,
  Users,
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { localDateKey } from "@/utils/dateUtils";
import {
  fetchSupervisionCenterDetail,
  fetchSupervisionHealth,
  supervisionErrorMessage,
  type SupervisionCenterDetail,
} from "@/services/supervisionService";
import { logOperationalError } from "@/lib/operationalLog";

function defaultMonthStart() {
  return `${localDateKey().slice(0, 7)}-01`;
}

export default function SupervisionCenterDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const searchParams = useSearchParams();
  const { currentSupervisor, user, fetchProfile } = useStore(
    useShallow((state) => ({
      currentSupervisor: state.currentSupervisor,
      user: state.user,
      fetchProfile: state.fetchProfile,
    })),
  );
  const centerId = params.id;
  const [startDate, setStartDate] = useState(searchParams.get("start") || defaultMonthStart());
  const [endDate, setEndDate] = useState(searchParams.get("end") || localDateKey());
  const [detail, setDetail] = useState<SupervisionCenterDetail | null>(null);
  const [loading, setLoading] = useState(true);
  const [errorMessage, setErrorMessage] = useState("");
  const [query, setQuery] = useState("");
  const [halaqaId, setHalaqaId] = useState("");

  const load = useCallback(async () => {
    if (!currentSupervisor || !centerId) return;
    setLoading(true);
    setErrorMessage("");
    const { data, error } = await fetchSupervisionCenterDetail({
      supervisorId: currentSupervisor.id,
      centerId,
      startDate,
      endDate,
    });
    if (error) {
      const health = await fetchSupervisionHealth();
      logOperationalError("supervision.center_detail", error);
      setErrorMessage(supervisionErrorMessage(error, health));
      setDetail(null);
    } else {
      setDetail(data as SupervisionCenterDetail);
    }
    setLoading(false);
  }, [centerId, currentSupervisor, endDate, startDate]);

  useEffect(() => {
    if (user && !currentSupervisor) void fetchProfile();
  }, [currentSupervisor, fetchProfile, user]);

  useEffect(() => {
    if (currentSupervisor) void load();
    else if (!user) setLoading(false);
  }, [currentSupervisor, load, user]);

  const visibleStudents = useMemo(() => {
    if (!detail) return [];
    const normalized = query.trim().toLocaleLowerCase("ar");
    return detail.students.filter((student) => {
      if (halaqaId && student.halaqa_id !== halaqaId) return false;
      if (!normalized) return true;
      return `${student.name} ${student.halaqa_name ?? ""}`.toLocaleLowerCase("ar").includes(normalized);
    });
  }, [detail, halaqaId, query]);

  if (!user) {
    return <main className="mx-auto max-w-5xl p-6 text-center text-sm font-bold text-gray-500">سجل الدخول أولًا لعرض بيانات الجهة الإشرافية.</main>;
  }

  return (
    <main className="min-h-screen bg-[var(--background)] px-4 py-6 text-[var(--foreground)] sm:px-6 lg:px-8" dir="rtl">
      <div className="mx-auto max-w-7xl space-y-6">
        <header className="rounded-[2rem] bg-gradient-to-l from-[#175e52] to-[#238776] p-6 text-white shadow-lg sm:p-8">
          <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <button type="button" onClick={() => router.push("/supervision")} className="mb-4 inline-flex items-center gap-2 rounded-xl bg-white/10 px-3 py-2 text-xs font-black hover:bg-white/20">
                <ArrowRight className="h-4 w-4" /> العودة للجهة
              </button>
              <h1 className="flex items-center gap-3 text-2xl font-black sm:text-3xl"><Building2 className="h-8 w-8" /> {detail?.center.name || "تفاصيل المركز"}</h1>
              <p className="mt-2 text-sm text-white/80">متابعة إشرافية من المركز إلى الحلقة ثم أداء كل طالب، دون منح صلاحيات إدارة المركز للمحلل.</p>
            </div>
            <button type="button" onClick={() => void load()} disabled={loading} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-white px-4 py-3 text-sm font-black text-teal-800 disabled:opacity-60">
              {loading ? <Loader2 className="h-4 w-4 animate-spin" /> : <RefreshCw className="h-4 w-4" />} تحديث
            </button>
          </div>
        </header>

        <section className="grid gap-3 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-4 sm:grid-cols-[1fr_1fr_auto] sm:items-end">
          <label className="text-xs font-black text-gray-500">من<input type="date" value={startDate} onChange={(event) => setStartDate(event.target.value)} className="mt-2 w-full rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 py-2 text-sm" /></label>
          <label className="text-xs font-black text-gray-500">إلى<input type="date" value={endDate} onChange={(event) => setEndDate(event.target.value)} className="mt-2 w-full rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 py-2 text-sm" /></label>
          <button type="button" onClick={() => void load()} className="rounded-xl bg-teal-700 px-5 py-2.5 text-sm font-black text-white">تطبيق الفترة</button>
        </section>

        {errorMessage && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm font-bold text-rose-700 dark:border-rose-800 dark:bg-rose-900/20 dark:text-rose-200">{errorMessage}</div>}
        {loading && !detail ? <div className="flex min-h-64 items-center justify-center"><Loader2 className="h-8 w-8 animate-spin text-teal-600" /></div> : null}

        {detail && (
          <>
            <section className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {[
                { label: "الحلقات", value: detail.halaqat.length, icon: Users },
                { label: "الطلاب", value: detail.students.length, icon: UserRound },
                { label: "آيات الحفظ", value: detail.halaqat.reduce((sum, item) => sum + item.new_ayahs, 0), icon: BookOpen },
                { label: "آيات المراجعة", value: detail.halaqat.reduce((sum, item) => sum + item.review_ayahs, 0), icon: BarChart3 },
              ].map((card) => {
                const Icon = card.icon;
                return (
                  <article key={card.label} className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-sm">
                    <Icon className="h-6 w-6 text-teal-600" />
                    <p className="mt-3 text-2xl font-black">{card.value}</p>
                    <p className="mt-1 text-xs font-bold text-gray-500">{card.label}</p>
                  </article>
                );
              })}
            </section>

            <section className="rounded-[2rem] border border-[var(--border)] bg-[var(--surface)] p-5 sm:p-7">
              <h2 className="flex items-center gap-2 text-xl font-black"><Users className="h-6 w-6 text-teal-600" /> الحلقات</h2>
              <div className="mt-5 grid gap-4 lg:grid-cols-2">
                {detail.halaqat.map((halaqa) => (
                  <button key={halaqa.id} type="button" onClick={() => setHalaqaId((current) => current === halaqa.id ? "" : halaqa.id)} className={`rounded-3xl border p-5 text-right transition ${halaqaId === halaqa.id ? "border-teal-500 bg-teal-50 dark:bg-teal-900/20" : "border-[var(--border)] bg-[var(--background)]"}`}>
                    <div className="flex items-center justify-between gap-3"><div><h3 className="font-black">{halaqa.name}</h3><p className="mt-1 text-xs text-gray-500">{halaqa.teacher_name || "المعلم غير مسجل"}</p></div><span className="rounded-full bg-teal-100 px-3 py-1 text-xs font-black text-teal-800 dark:bg-teal-900/40 dark:text-teal-200">{halaqa.active_students} طالب</span></div>
                    <div className="mt-4 grid grid-cols-3 gap-2 text-center text-xs font-bold"><span className="rounded-xl bg-[var(--surface)] p-2">حضور {halaqa.attendance_rate}%</span><span className="rounded-xl bg-[var(--surface)] p-2">حفظ {halaqa.new_ayahs}</span><span className="rounded-xl bg-[var(--surface)] p-2">مراجعة {halaqa.review_ayahs}</span></div>
                  </button>
                ))}
              </div>
            </section>

            <section className="rounded-[2rem] border border-[var(--border)] bg-[var(--surface)] p-5 sm:p-7">
              <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
                <div><h2 className="flex items-center gap-2 text-xl font-black"><Trophy className="h-6 w-6 text-amber-500" /> أداء الطلاب</h2><p className="mt-2 text-xs text-gray-500">اضغط على حلقة أعلاه لتصفية الطلاب، أو ابحث بالاسم.</p></div>
                <div className="flex flex-wrap gap-2"><input value={query} onChange={(event) => setQuery(event.target.value)} placeholder="بحث باسم الطالب" className="rounded-xl border border-[var(--border)] bg-[var(--background)] px-4 py-2 text-sm" />{halaqaId && <button type="button" onClick={() => setHalaqaId("")} className="rounded-xl border border-[var(--border)] px-3 py-2 text-xs font-black">كل الحلقات</button>}</div>
              </div>
              <div className="mt-5 overflow-x-auto">
                <table className="w-full min-w-[780px] text-right text-sm">
                  <thead><tr className="border-b border-[var(--border)] text-xs text-gray-500"><th className="p-3">الطالب</th><th className="p-3">الحلقة</th><th className="p-3">الحضور</th><th className="p-3">الحفظ</th><th className="p-3">المراجعة</th><th className="p-3">إجمالي المحفوظ</th><th className="p-3">رصيد النقاط</th></tr></thead>
                  <tbody>{visibleStudents.map((student) => <tr key={student.id} className="border-b border-[var(--border)]/70"><td className="p-3 font-black">{student.name}</td><td className="p-3 text-gray-500">{student.halaqa_name || "—"}</td><td className="p-3">{student.attendance_rate}%</td><td className="p-3">{student.new_ayahs} آية</td><td className="p-3">{student.review_ayahs} آية</td><td className="p-3">{student.total_memorized}</td><td className={`p-3 font-black ${student.points_balance >= 0 ? "text-emerald-600" : "text-rose-600"}`}>{student.points_balance > 0 ? "+" : ""}{student.points_balance}</td></tr>)}</tbody>
                </table>
              </div>
              {visibleStudents.length === 0 && <div className="p-10 text-center text-sm font-bold text-gray-400">لا توجد نتائج مطابقة.</div>}
            </section>

            <footer className="flex items-center gap-2 text-xs font-bold text-gray-500"><CalendarDays className="h-4 w-4" /> الفترة: {detail.period.start_date} — {detail.period.end_date}</footer>
          </>
        )}
      </div>
    </main>
  );
}
