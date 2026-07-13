"use client";

import { useEffect, useMemo, useState } from "react";
import {
  Sparkles,
  CalendarDays,
  Plus,
  Gift,
  Award,
  X,
  ChevronRight,
  ChevronLeft,
} from "lucide-react";
import {
  DailyAchievement,
  DailyAchievementInput,
  MemorizationRecord,
  Student,
  useStore,
} from "@/store/useStore";
import { quranService } from "@/services/quranService";

type Entry = {
  student: Student;
  input: DailyAchievementInput;
  stored?: DailyAchievement;
};

const dateKey = (date: Date) => date.toISOString().split("T")[0];

function calculateActual(
  student: Student,
  records: MemorizationRecord[]
): number {
  const unique = new Map<string, { page: number; lines: number }>();
  for (const record of records) {
    const surah = quranService.getSurahs().find(item => item.name === record.surah);
    if (!surah) continue;
    for (const ayah of quranService.getAyahRange(
      surah.number,
      record.fromAyah,
      record.toAyah
    )) {
      unique.set(`${surah.number}:${ayah.number}`, {
        page: ayah.page,
        lines: ayah.lines || 0,
      });
    }
  }
  if (student.planType === "pages") {
    return new Set([...unique.values()].map(item => item.page)).size;
  }
  if (student.planType === "lines") {
    return [...unique.values()].reduce((sum, item) => sum + item.lines, 0);
  }
  return unique.size;
}

const unitLabel = (unit: Student["planType"]) =>
  unit === "pages" ? "صفحة" : unit === "lines" ? "سطرًا" : "آية";

const rewardLabel = (type?: DailyAchievement["rewardType"]) => {
  if (type === "points") return "نقاط مكافأة";
  if (type === "certificate") return "شهادة شكر";
  if (type === "gift") return "هدية";
  if (type === "meal") return "وجبة/عشاء جماعي";
  return "تكريم آخر";
};

export default function DailyExcellencePage() {
  const {
    students,
    memorization,
    dailyAchievements,
    saveDailyAchievement,
    awardDailyAchievement,
  } = useStore();
  const [selectedDate, setSelectedDate] = useState(new Date());
  const [filter, setFilter] = useState<"all" | "automatic" | "manual" | "rewarded">("all");
  const [quranReady, setQuranReady] = useState(false);
  const [manualOpen, setManualOpen] = useState(false);
  const [manualStudentId, setManualStudentId] = useState("");
  const [manualReason, setManualReason] = useState("");
  const [rewardEntry, setRewardEntry] = useState<Entry | null>(null);
  const [rewardType, setRewardType] = useState<NonNullable<DailyAchievement["rewardType"]>>("points");
  const [rewardDetails, setRewardDetails] = useState("");
  const [rewardPoints, setRewardPoints] = useState(5);

  useEffect(() => {
    quranService.initialize().then(() => setQuranReady(true));
  }, []);

  const activeStudents = useMemo(
    () => students
      .filter(student => student.status === "active")
      .sort((a, b) => a.name.localeCompare(b.name, "ar", { sensitivity: "base" })),
    [students]
  );

  const entries = useMemo<Entry[]>(() => {
    if (!quranReady) return [];
    const key = dateKey(selectedDate);
    const saved = dailyAchievements.filter(item => item.date === key);
    const savedByStudent = new Map(saved.map(item => [item.studentId, item]));
    const result: Entry[] = [];
    for (const student of activeStudents) {
      const actual = calculateActual(
        student,
        memorization.filter(record =>
          record.studentId === student.id &&
          record.date === key &&
          !record.isRevision
        )
      );
      const stored = savedByStudent.get(student.id);
      savedByStudent.delete(student.id);
      if (actual > student.planAmount + 0.001) {
        result.push({
          student,
          stored,
          input: {
            studentId: student.id,
            date: key,
            source: "automatic",
            reason: stored?.reason || "تجاوز المقرر اليومي",
            actualAmount: actual,
            planAmount: student.planAmount,
            unit: student.planType,
            notes: stored?.notes,
          },
        });
      } else if (stored) {
        result.push({
          student,
          stored,
          input: {
            studentId: student.id,
            date: key,
            source: stored.source,
            reason: stored.reason,
            actualAmount: stored.actualAmount,
            planAmount: stored.planAmount,
            unit: stored.unit,
            notes: stored.notes,
          },
        });
      }
    }
    return result.sort((a, b) =>
      (b.input.actualAmount - b.input.planAmount) -
      (a.input.actualAmount - a.input.planAmount)
    );
  }, [quranReady, selectedDate, activeStudents, memorization, dailyAchievements]);

  const visibleEntries = entries.filter(entry => {
    if (filter === "automatic") return entry.input.source === "automatic";
    if (filter === "manual") return entry.input.source === "manual";
    if (filter === "rewarded") return Boolean(entry.stored?.rewardType);
    return true;
  });

  const moveDate = (days: number) => {
    const next = new Date(selectedDate);
    next.setDate(next.getDate() + days);
    if (next > new Date()) return;
    setSelectedDate(next);
  };

  const addManual = async () => {
    const student = activeStudents.find(item => item.id === manualStudentId);
    if (!student || !manualReason.trim()) return;
    await saveDailyAchievement({
      studentId: student.id,
      date: dateKey(selectedDate),
      source: "manual",
      reason: manualReason.trim(),
      actualAmount: 0,
      planAmount: student.planAmount,
      unit: student.planType,
    });
    setManualOpen(false);
    setManualStudentId("");
    setManualReason("");
  };

  const openReward = (entry: Entry) => {
    setRewardEntry(entry);
    setRewardType(entry.stored?.rewardType || "points");
    setRewardDetails(entry.stored?.rewardDetails || "");
    setRewardPoints(entry.stored?.rewardPoints || 5);
  };

  const submitReward = async () => {
    if (!rewardEntry || (rewardType === "points" && rewardPoints < 1)) return;
    await awardDailyAchievement(
      rewardEntry.input,
      rewardType,
      rewardDetails.trim() || undefined,
      rewardType === "points" ? rewardPoints : 0
    );
    setRewardEntry(null);
  };

  const automaticCount = entries.filter(item => item.input.source === "automatic").length;
  const rewardedCount = entries.filter(item => item.stored?.rewardType).length;

  return (
    <div className="space-y-8 pb-20 animate-in fade-in slide-in-from-bottom-4 duration-500">
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-5">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white flex items-center gap-3">
            <Sparkles className="w-8 h-8 text-amber-500" /> متميزو اليوم
          </h1>
          <p className="text-gray-500 mt-2 font-medium">واجهة يومية مستقلة لمن تجاوز المقرر ومن يضيفه المعلم تقديرًا لاجتهاده.</p>
        </div>
        <button onClick={() => setManualOpen(true)} className="bg-teal-600 text-white px-6 py-4 rounded-2xl font-black flex items-center gap-2">
          <Plus className="w-5 h-5" /> إضافة متميز
        </button>
      </div>

      <div className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-5 flex items-center justify-between">
        <button onClick={() => moveDate(-1)} className="p-3 rounded-xl bg-gray-50 dark:bg-gray-800"><ChevronRight /></button>
        <div className="text-center">
          <CalendarDays className="w-5 h-5 text-teal-600 mx-auto mb-2" />
          <div className="font-black text-gray-900 dark:text-white">{dateKey(selectedDate)}</div>
        </div>
        <button onClick={() => moveDate(1)} disabled={dateKey(selectedDate) === dateKey(new Date())} className="p-3 rounded-xl bg-gray-50 dark:bg-gray-800 disabled:opacity-30"><ChevronLeft /></button>
      </div>

      <div className="grid grid-cols-3 gap-4">
        {[
          ["تلقائي", automaticCount, "text-teal-600"],
          ["الإجمالي", entries.length, "text-amber-600"],
          ["تم تكريمهم", rewardedCount, "text-purple-600"],
        ].map(([label, value, color]) => (
          <div key={String(label)} className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl p-5 text-center">
            <div className={`text-3xl font-black ${color}`}>{value}</div>
            <div className="text-xs font-bold text-gray-500 mt-1">{label}</div>
          </div>
        ))}
      </div>

      <div className="flex flex-wrap gap-2">
        {([
          ["all", "الكل"],
          ["automatic", "تجاوزوا المقرر"],
          ["manual", "إضافة المعلم"],
          ["rewarded", "تم تكريمهم"],
        ] as const).map(([value, label]) => (
          <button key={value} onClick={() => setFilter(value)} className={`px-5 py-3 rounded-full text-sm font-black ${filter === value ? "bg-teal-600 text-white" : "bg-white dark:bg-gray-900 text-gray-500 border border-gray-200 dark:border-gray-800"}`}>{label}</button>
        ))}
      </div>

      {!quranReady ? (
        <div className="py-20 text-center font-bold text-gray-400">جاري تجهيز بيانات المصحف...</div>
      ) : visibleEntries.length === 0 ? (
        <div className="py-20 text-center bg-white dark:bg-gray-900 rounded-3xl border-2 border-dashed border-gray-200 dark:border-gray-800">
          <Award className="w-14 h-14 text-gray-300 mx-auto mb-4" />
          <p className="font-bold text-gray-500">لا يوجد متميزون مسجلون في هذا اليوم</p>
        </div>
      ) : (
        <div className="grid md:grid-cols-2 gap-5">
          {visibleEntries.map(entry => {
            const extra = Math.max(0, entry.input.actualAmount - entry.input.planAmount);
            return (
              <div key={entry.student.id} className="bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-3xl p-6">
                <div className="flex items-start gap-4">
                  <div className="w-12 h-12 bg-amber-50 text-amber-600 rounded-2xl flex items-center justify-center text-xl font-black">{entry.student.name[0]}</div>
                  <div className="flex-1">
                    <h3 className="font-black text-lg text-gray-900 dark:text-white">{entry.student.name}</h3>
                    <p className="text-xs font-bold text-gray-500 mt-1">{entry.input.reason}</p>
                  </div>
                  {entry.input.source === "automatic" && <span className="text-[10px] font-black bg-teal-50 text-teal-700 px-3 py-1 rounded-full">تلقائي</span>}
                </div>
                {entry.input.source === "automatic" && (
                  <div className="mt-5 bg-teal-50/60 dark:bg-teal-950/20 rounded-2xl p-4 text-sm font-bold text-teal-800 dark:text-teal-300">
                    أنجز {entry.input.actualAmount.toFixed(entry.input.actualAmount % 1 ? 1 : 0)} {unitLabel(entry.input.unit)} من مقرر {entry.input.planAmount} — زيادة {extra.toFixed(extra % 1 ? 1 : 0)}
                  </div>
                )}
                {entry.stored?.rewardType && (
                  <div className="mt-4 bg-purple-50 dark:bg-purple-950/20 rounded-2xl p-4 text-sm font-bold text-purple-700 dark:text-purple-300">
                    🎁 {rewardLabel(entry.stored.rewardType)}{entry.stored.rewardPoints ? ` (${entry.stored.rewardPoints} نقطة)` : ""}{entry.stored.rewardDetails ? ` — ${entry.stored.rewardDetails}` : ""}
                  </div>
                )}
                <button onClick={() => openReward(entry)} className="mt-5 w-full py-3 rounded-2xl bg-amber-500 text-white font-black flex items-center justify-center gap-2">
                  <Gift className="w-4 h-4" /> {entry.stored?.rewardType ? "تعديل التكريم" : "تكريم الطالب"}
                </button>
              </div>
            );
          })}
        </div>
      )}

      {manualOpen && (
        <div className="fixed inset-0 bg-gray-950/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md">
            <div className="flex justify-between mb-6"><h3 className="text-xl font-black">إضافة متميز يدويًا</h3><button onClick={() => setManualOpen(false)}><X /></button></div>
            <div className="space-y-4">
              <select value={manualStudentId} onChange={event => setManualStudentId(event.target.value)} className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl p-4 font-bold">
                <option value="">اختر الطالب</option>
                {activeStudents.map(student => <option key={student.id} value={student.id}>{student.name}</option>)}
              </select>
              <textarea value={manualReason} onChange={event => setManualReason(event.target.value)} rows={3} placeholder="سبب التميز (إلزامي)" className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl p-4 font-bold resize-none" />
              <button disabled={!manualStudentId || !manualReason.trim()} onClick={addManual} className="w-full py-4 bg-teal-600 text-white rounded-2xl font-black disabled:opacity-40">إضافة إلى متميزو اليوم</button>
            </div>
          </div>
        </div>
      )}

      {rewardEntry && (
        <div className="fixed inset-0 bg-gray-950/60 backdrop-blur-sm z-50 flex items-center justify-center p-4">
          <div className="bg-white dark:bg-gray-900 rounded-3xl p-8 w-full max-w-md">
            <div className="flex justify-between mb-6"><div><h3 className="text-xl font-black">تكريم الطالب</h3><p className="text-sm text-gray-500 mt-1">{rewardEntry.student.name}</p></div><button onClick={() => setRewardEntry(null)}><X /></button></div>
            <div className="space-y-4">
              <select value={rewardType} onChange={event => setRewardType(event.target.value as NonNullable<DailyAchievement["rewardType"]>)} className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl p-4 font-bold">
                <option value="points">نقاط مكافأة</option><option value="certificate">شهادة شكر</option><option value="gift">هدية</option><option value="meal">وجبة/عشاء جماعي</option><option value="other">تكريم آخر</option>
              </select>
              {rewardType === "points" && <input type="number" min={1} value={rewardPoints} onChange={event => setRewardPoints(Number(event.target.value))} className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl p-4 font-bold" />}
              <textarea value={rewardDetails} onChange={event => setRewardDetails(event.target.value)} rows={3} placeholder="تفاصيل التكريم، مثل موعد العشاء أو نوع الهدية" className="w-full bg-gray-50 dark:bg-gray-800 rounded-2xl p-4 font-bold resize-none" />
              <button disabled={rewardType === "points" && rewardPoints < 1} onClick={submitReward} className="w-full py-4 bg-amber-500 text-white rounded-2xl font-black disabled:opacity-40">اعتماد التكريم</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
