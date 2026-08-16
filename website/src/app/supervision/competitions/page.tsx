"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight, CheckCircle2, Loader2, Plus, RefreshCw, Send, Trophy, Users } from "lucide-react";
import { useShallow } from "zustand/react/shallow";

import { supabase } from "@/lib/supabase";
import { logOperationalError } from "@/lib/operationalLog";
import { useStore } from "@/store/useStore";
import {
  scoreSupervisorCompetitionEntry,
  submitSupervisorCompetitionEntry,
  withdrawSupervisorCompetitionEntry,
  type SupervisorCompetition,
  type SupervisorCompetitionCategory,
  type SupervisorCompetitionEntry,
} from "@/services/supervisionService";

const thisYear = new Date().getFullYear();

type CenterStudent = { id: string; name: string };

type CenterMeta = { supervisor_id?: string | null };

export default function SupervisorCompetitionsPage() {
  const router = useRouter();
  const { currentSupervisor, currentCenter } = useStore(
    useShallow((state) => ({
      currentSupervisor: state.currentSupervisor,
      currentCenter: state.currentCenter,
    })),
  );
  const [competitions, setCompetitions] = useState<SupervisorCompetition[]>([]);
  const [categories, setCategories] = useState<SupervisorCompetitionCategory[]>([]);
  const [entries, setEntries] = useState<SupervisorCompetitionEntry[]>([]);
  const [students, setStudents] = useState<CenterStudent[]>([]);
  const [centerSupervisorId, setCenterSupervisorId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [title, setTitle] = useState(`مسابقة القرآن ${thisYear}`);
  const [seasonYear, setSeasonYear] = useState(thisYear);
  const [categoryName, setCategoryName] = useState("فئة القرآن الكريم");
  const [categoryFromSurah, setCategoryFromSurah] = useState<number | "">("");
  const [categoryToSurah, setCategoryToSurah] = useState<number | "">("");
  const [selectedCompetitionId, setSelectedCompetitionId] = useState("");
  const [selectedCategoryId, setSelectedCategoryId] = useState("");
  const [selectedStudentId, setSelectedStudentId] = useState("");

  const isSupervisorMode = Boolean(currentSupervisor);
  const supervisorId = currentSupervisor?.id ?? centerSupervisorId;
  const canManage = currentSupervisor?.role === "owner" || currentSupervisor?.role === "admin";

  const load = useCallback(async () => {
    if (!supabase) return;
    setLoading(true);
    setErrorMessage("");
    try {
      let resolvedSupervisorId = currentSupervisor?.id ?? null;
      if (!resolvedSupervisorId && currentCenter) {
        const { data: centerData, error: centerError } = await supabase
          .from("centers")
          .select("supervisor_id")
          .eq("id", currentCenter.id)
          .maybeSingle();
        if (centerError) throw centerError;
        resolvedSupervisorId = (centerData as CenterMeta | null)?.supervisor_id ?? null;
        setCenterSupervisorId(resolvedSupervisorId);
        const { data: studentRows, error: studentError } = await supabase
          .from("students")
          .select("id,name")
          .eq("center_id", currentCenter.id)
          .eq("status", "active")
          .order("name");
        if (studentError) throw studentError;
        setStudents((studentRows ?? []) as CenterStudent[]);
      }
      if (!resolvedSupervisorId) {
        setCompetitions([]);
        setCategories([]);
        setEntries([]);
        setLoading(false);
        return;
      }

      const competitionQuery = supabase
        .from("supervisor_competitions")
        .select("id,supervisor_id,title,season_year,description,starts_on,ends_on,status,created_at")
        .eq("supervisor_id", resolvedSupervisorId)
        .order("season_year", { ascending: false })
        .order("created_at", { ascending: false });
      const { data: competitionRows, error: competitionError } = await competitionQuery;
      if (competitionError) throw competitionError;
      const nextCompetitions = (competitionRows ?? []) as SupervisorCompetition[];
      setCompetitions(nextCompetitions);
      const ids = nextCompetitions.map((item) => item.id);
      if (ids.length === 0) {
        setCategories([]);
        setEntries([]);
        setLoading(false);
        return;
      }
      const [{ data: categoryRows, error: categoryError }, { data: entryRows, error: entryError }] = await Promise.all([
        supabase
          .from("supervisor_competition_categories")
          .select("id,competition_id,name,from_surah,to_surah,maximum_score,sort_order")
          .in("competition_id", ids)
          .order("sort_order"),
        supabase
          .from("supervisor_competition_entries")
          .select("id,competition_id,category_id,center_id,student_id,student_name_snapshot,status,submitted_at,center:centers(name),category:supervisor_competition_categories(name,maximum_score),score:supervisor_competition_scores(score,obvious_errors,subtle_errors,prompt_count,stop_count,tajweed_errors,notes)")
          .in("competition_id", ids)
          .order("submitted_at", { ascending: false }),
      ]);
      if (categoryError) throw categoryError;
      if (entryError) throw entryError;
      setCategories((categoryRows ?? []) as SupervisorCompetitionCategory[]);
      setEntries((entryRows ?? []) as unknown as SupervisorCompetitionEntry[]);
    } catch (error) {
      logOperationalError("supervision.competitions.load", error);
      setErrorMessage("تعذر تحميل مسابقات الجهة. تأكد من تنفيذ SQL الخاص بـ Build 78 ثم أعد المحاولة.");
    } finally {
      setLoading(false);
    }
  }, [currentCenter, currentSupervisor]);

  useEffect(() => { void load(); }, [load]);

  const openCompetitions = useMemo(
    () => competitions.filter((item) => item.status === "open"),
    [competitions],
  );
  const selectedCategories = useMemo(
    () => categories.filter((item) => item.competition_id === selectedCompetitionId),
    [categories, selectedCompetitionId],
  );

  const createCompetition = async () => {
    if (!supabase || !currentSupervisor || !canManage || !title.trim()) return;
    setBusy(true);
    const { error } = await supabase.from("supervisor_competitions").insert({
      supervisor_id: currentSupervisor.id,
      title: title.trim(),
      season_year: seasonYear,
      status: "draft",
    });
    setBusy(false);
    if (error) {
      logOperationalError("supervision.competitions.create", error);
      setErrorMessage("تعذر إنشاء المسابقة.");
      return;
    }
    await load();
  };

  const addCategory = async (competitionId: string) => {
    if (!supabase || !canManage || !categoryName.trim()) return;
    setBusy(true);
    const { error } = await supabase.from("supervisor_competition_categories").insert({
      competition_id: competitionId,
      name: categoryName.trim(),
      from_surah: categoryFromSurah === "" ? null : categoryFromSurah,
      to_surah: categoryToSurah === "" ? null : categoryToSurah,
      maximum_score: 100,
      sort_order: categories.filter((item) => item.competition_id === competitionId).length,
    });
    setBusy(false);
    if (error) {
      logOperationalError("supervision.competitions.category", error);
      setErrorMessage("تعذر إضافة الفئة.");
      return;
    }
    setCategoryFromSurah("");
    setCategoryToSurah("");
    await load();
  };

  const setStatus = async (competition: SupervisorCompetition, status: SupervisorCompetition["status"]) => {
    if (!supabase || !canManage) return;
    setBusy(true);
    const { error } = await supabase.from("supervisor_competitions").update({ status, updated_at: new Date().toISOString() }).eq("id", competition.id);
    setBusy(false);
    if (error) {
      setErrorMessage("تعذر تحديث حالة المسابقة.");
      return;
    }
    await load();
  };

  const nominate = async () => {
    if (!selectedCompetitionId || !selectedCategoryId || !selectedStudentId) return;
    setBusy(true);
    const { error } = await submitSupervisorCompetitionEntry({
      competitionId: selectedCompetitionId,
      categoryId: selectedCategoryId,
      studentId: selectedStudentId,
    });
    setBusy(false);
    if (error) {
      logOperationalError("supervision.competition.nominate", error);
      setErrorMessage("تعذر ترشيح الطالب. تأكد أن المسابقة مفتوحة وأن المركز مرتبط بهذه الجهة.");
      return;
    }
    setSelectedStudentId("");
    await load();
  };

  const scoreEntry = async (entry: SupervisorCompetitionEntry) => {
    const maximum = Number(entry.category?.maximum_score ?? 100);
    const existing = entry.score?.[0];
    const askNumber = (label: string, initial: number) => {
      const raw = window.prompt(label, String(initial));
      if (raw === null) return null;
      const value = Number(raw);
      return Number.isFinite(value) && value >= 0 ? value : Number.NaN;
    };

    const score = askNumber(
      `درجة ${entry.student_name_snapshot} من ${maximum}:`,
      Number(existing?.score ?? maximum),
    );
    if (score === null) return;
    if (!Number.isFinite(score) || score > maximum) {
      setErrorMessage(`الدرجة يجب أن تكون بين 0 و${maximum}.`);
      return;
    }
    const obviousErrors = askNumber("عدد الأخطاء الجلية:", existing?.obvious_errors ?? 0);
    if (obviousErrors === null) return;
    const subtleErrors = askNumber("عدد الأخطاء الخفية:", existing?.subtle_errors ?? 0);
    if (subtleErrors === null) return;
    const promptCount = askNumber("مرات الفتح/التلقين:", existing?.prompt_count ?? 0);
    if (promptCount === null) return;
    const stopCount = askNumber("مرات التوقف:", existing?.stop_count ?? 0);
    if (stopCount === null) return;
    const tajweedErrors = askNumber("أخطاء التجويد:", existing?.tajweed_errors ?? 0);
    if (tajweedErrors === null) return;
    if ([obviousErrors, subtleErrors, promptCount, stopCount, tajweedErrors].some((value) => !Number.isFinite(value))) {
      setErrorMessage("أعداد الأخطاء والتلقين والتوقف يجب أن تكون أرقامًا صحيحة غير سالبة.");
      return;
    }
    const notes = window.prompt("ملاحظات التحكيم (اختياري):", existing?.notes ?? "") ?? "";
    setBusy(true);
    const { error } = await scoreSupervisorCompetitionEntry({
      entryId: entry.id,
      score,
      obviousErrors: Math.trunc(obviousErrors),
      subtleErrors: Math.trunc(subtleErrors),
      promptCount: Math.trunc(promptCount),
      stopCount: Math.trunc(stopCount),
      tajweedErrors: Math.trunc(tajweedErrors),
      notes,
    });
    setBusy(false);
    if (error) {
      logOperationalError("supervision.competition.score", error);
      setErrorMessage("تعذر حفظ نتيجة التحكيم.");
      return;
    }
    await load();
  };

  return (
    <main dir="rtl" className="min-h-screen bg-[var(--background)] p-4 text-[var(--foreground)] sm:p-8">
      <div className="mx-auto max-w-6xl space-y-6">
        <header className="rounded-[2rem] bg-gradient-to-l from-teal-800 to-emerald-700 p-6 text-white shadow-xl sm:p-8">
          <button type="button" onClick={() => router.back()} className="mb-5 inline-flex items-center gap-2 rounded-xl bg-white/10 px-3 py-2 text-xs font-black hover:bg-white/20">
            <ArrowRight className="h-4 w-4" /> رجوع
          </button>
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div>
              <p className="text-xs font-black text-emerald-100">Build 78 · مسابقات الجهة الإشرافية</p>
              <h1 className="mt-2 text-3xl font-black">المسابقة السنوية</h1>
              <p className="mt-2 max-w-2xl text-sm font-semibold text-emerald-50/90">الجهة تنشئ الفئات، والمراكز المرتبطة ترشح طلابها من النظام، ثم تظهر النتائج والتصحيحات في مكان واحد.</p>
            </div>
            <button onClick={() => void load()} className="rounded-2xl bg-white/10 p-3 hover:bg-white/20" aria-label="تحديث"><RefreshCw className="h-5 w-5" /></button>
          </div>
        </header>

        {errorMessage && <div className="rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm font-bold text-rose-700 dark:border-rose-900 dark:bg-rose-950/30 dark:text-rose-200">{errorMessage}</div>}

        {loading ? (
          <div className="flex min-h-64 items-center justify-center"><Loader2 className="h-9 w-9 animate-spin text-teal-600" /></div>
        ) : !supervisorId ? (
          <section className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-8 text-center">
            <Trophy className="mx-auto h-10 w-10 text-amber-500" />
            <h2 className="mt-4 text-xl font-black">المركز غير مرتبط بجهة إشرافية</h2>
            <p className="mt-2 text-sm text-[var(--muted)]">اربط المركز أولًا من الإعدادات حتى تظهر مسابقات الجهة المفتوحة.</p>
          </section>
        ) : (
          <>
            {isSupervisorMode && canManage && (
              <section className="grid gap-4 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 lg:grid-cols-[2fr_140px_auto]">
                <input value={title} onChange={(event) => setTitle(event.target.value)} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 font-bold" placeholder="اسم المسابقة" />
                <input type="number" value={seasonYear} onChange={(event) => setSeasonYear(Number(event.target.value) || thisYear)} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 font-bold" />
                <button disabled={busy} onClick={createCompetition} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-teal-700 px-5 py-3 font-black text-white disabled:opacity-50"><Plus className="h-4 w-4" /> إنشاء</button>
              </section>
            )}

            {!isSupervisorMode && (
              <section className="rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5">
                <h2 className="text-xl font-black">ترشيح طالب للمسابقة</h2>
                <p className="mt-1 text-xs text-[var(--muted)]">تظهر هنا المسابقات المفتوحة للجهة التي تشرف على مركزك.</p>
                <div className="mt-4 grid gap-3 md:grid-cols-3">
                  <select value={selectedCompetitionId} onChange={(event) => { setSelectedCompetitionId(event.target.value); setSelectedCategoryId(""); }} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 font-bold">
                    <option value="">اختر المسابقة</option>
                    {openCompetitions.map((item) => <option key={item.id} value={item.id}>{item.title}</option>)}
                  </select>
                  <select value={selectedCategoryId} onChange={(event) => setSelectedCategoryId(event.target.value)} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 font-bold">
                    <option value="">اختر الفئة</option>
                    {selectedCategories.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                  </select>
                  <select value={selectedStudentId} onChange={(event) => setSelectedStudentId(event.target.value)} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 font-bold">
                    <option value="">اختر الطالب</option>
                    {students.map((item) => <option key={item.id} value={item.id}>{item.name}</option>)}
                  </select>
                </div>
                <button disabled={busy || !selectedStudentId || !selectedCategoryId} onClick={nominate} className="mt-4 inline-flex items-center gap-2 rounded-2xl bg-emerald-700 px-5 py-3 font-black text-white disabled:opacity-50"><Send className="h-4 w-4" /> إرسال الترشيح للجهة</button>
              </section>
            )}

            <section className="space-y-4">
              {competitions.length === 0 ? (
                <div className="rounded-3xl border border-dashed border-[var(--border)] bg-[var(--surface)] p-10 text-center text-sm font-bold text-[var(--muted)]">لا توجد مسابقات بعد.</div>
              ) : competitions.map((competition) => {
                const competitionCategories = categories.filter((item) => item.competition_id === competition.id);
                const competitionEntries = entries.filter((item) => item.competition_id === competition.id && item.status !== "withdrawn");
                const ranked = [...competitionEntries].sort((a, b) => Number(b.score?.[0]?.score ?? -1) - Number(a.score?.[0]?.score ?? -1));
                return (
                  <article key={competition.id} className="overflow-hidden rounded-3xl border border-[var(--border)] bg-[var(--surface)] shadow-sm">
                    <div className="flex flex-wrap items-center justify-between gap-4 border-b border-[var(--border)] p-5">
                      <div>
                        <div className="flex items-center gap-2"><Trophy className="h-5 w-5 text-amber-500" /><h2 className="text-xl font-black">{competition.title}</h2></div>
                        <p className="mt-1 text-xs font-bold text-[var(--muted)]">موسم {competition.season_year} · الحالة: {competition.status} · {competitionEntries.length} متسابق</p>
                      </div>
                      {canManage && (
                        <div className="flex flex-wrap gap-2">
                          {competition.status === "draft" && <button disabled={busy} onClick={() => setStatus(competition, "open")} className="rounded-xl bg-emerald-600 px-3 py-2 text-xs font-black text-white">فتح الترشيح</button>}
                          {competition.status === "open" && <button disabled={busy} onClick={() => setStatus(competition, "judging")} className="rounded-xl bg-amber-500 px-3 py-2 text-xs font-black text-white">بدء التحكيم</button>}
                          {competition.status === "judging" && <button disabled={busy} onClick={() => setStatus(competition, "published")} className="rounded-xl bg-teal-700 px-3 py-2 text-xs font-black text-white">نشر النتائج</button>}
                        </div>
                      )}
                    </div>

                    {canManage && (
                      <div className="grid gap-2 bg-[var(--background)] p-4 md:grid-cols-[2fr_120px_120px_auto]">
                        <input value={categoryName} onChange={(event) => setCategoryName(event.target.value)} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-bold" placeholder="اسم الفئة" />
                        <input type="number" min={1} max={114} value={categoryFromSurah} onChange={(event) => setCategoryFromSurah(event.target.value === "" ? "" : Number(event.target.value))} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-bold" placeholder="من سورة" />
                        <input type="number" min={1} max={114} value={categoryToSurah} onChange={(event) => setCategoryToSurah(event.target.value === "" ? "" : Number(event.target.value))} className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-bold" placeholder="إلى سورة" />
                        <button disabled={busy} onClick={() => addCategory(competition.id)} className="rounded-xl border border-teal-700 px-4 py-2 text-xs font-black text-teal-700"><Plus className="ml-1 inline h-4 w-4" /> إضافة فئة</button>
                      </div>
                    )}

                    <div className="grid gap-3 p-5 md:grid-cols-2">
                      <div className="rounded-2xl bg-[var(--background)] p-4">
                        <p className="mb-3 flex items-center gap-2 text-sm font-black"><Users className="h-4 w-4" /> الفئات</p>
                        {competitionCategories.length === 0 ? <p className="text-xs text-[var(--muted)]">لم تضف فئات بعد.</p> : competitionCategories.map((category) => <div key={category.id} className="mb-2 rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-sm font-bold">{category.name} <span className="text-xs text-[var(--muted)]">/ {category.maximum_score}{category.from_surah && category.to_surah ? ` · السور ${category.from_surah}–${category.to_surah}` : ""}</span></div>)}
                      </div>
                      <div className="rounded-2xl bg-[var(--background)] p-4">
                        <p className="mb-3 flex items-center gap-2 text-sm font-black"><CheckCircle2 className="h-4 w-4" /> المتسابقون والنتائج</p>
                        {ranked.length === 0 ? <p className="text-xs text-[var(--muted)]">لا توجد ترشيحات حتى الآن.</p> : ranked.map((entry, index) => (
                          <div key={entry.id} className="mb-2 flex items-center gap-3 rounded-xl border border-[var(--border)] bg-[var(--surface)] p-3">
                            <span className="w-7 text-center text-sm font-black">{entry.score?.[0] ? index + 1 : "—"}</span>
                            <div className="min-w-0 flex-1"><p className="truncate text-sm font-black">{entry.student_name_snapshot}</p><p className="text-[10px] font-bold text-[var(--muted)]">{entry.center?.name ?? "المركز"} · {entry.category?.name ?? "الفئة"}</p>{entry.score?.[0] && <p className="mt-1 text-[10px] text-[var(--muted)]">جلي {entry.score[0].obvious_errors} · خفي {entry.score[0].subtle_errors} · فتح {entry.score[0].prompt_count} · توقف {entry.score[0].stop_count} · تجويد {entry.score[0].tajweed_errors}</p>}</div>
                            <span className="text-sm font-black text-teal-700">{entry.score?.[0]?.score ?? "بانتظار التحكيم"}</span>
                            {canManage && <button disabled={busy} onClick={() => scoreEntry(entry)} className="rounded-lg border border-[var(--border)] px-2 py-1 text-[10px] font-black">تحكيم</button>}
                            {!isSupervisorMode && entry.center_id === currentCenter?.id && entry.status === "submitted" && <button disabled={busy} onClick={async () => { setBusy(true); await withdrawSupervisorCompetitionEntry(entry.id); setBusy(false); await load(); }} className="text-[10px] font-black text-rose-600">سحب</button>}
                          </div>
                        ))}
                      </div>
                    </div>
                  </article>
                );
              })}
            </section>
          </>
        )}
      </div>
    </main>
  );
}
