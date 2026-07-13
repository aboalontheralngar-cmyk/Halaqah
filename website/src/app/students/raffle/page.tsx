"use client";

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  BookOpen,
  CheckCircle2,
  ClipboardList,
  Dices,
  ListOrdered,
  RotateCcw,
  ShieldCheck,
  Star,
  UserX,
  Users,
} from "lucide-react";
import { useStore } from "@/store/useStore";

interface RaffleSession {
  version: 2;
  excludedIds: string[];
  drawnIds: string[];
  selectedId: string | null;
  batchOrder: string[];
  excludeAbsent: boolean;
  drawTargetId: string | null;
  drawEndsAt: number | null;
}

const emptySession = (): RaffleSession => ({
  version: 2,
  excludedIds: [],
  drawnIds: [],
  selectedId: null,
  batchOrder: [],
  excludeAbsent: true,
  drawTargetId: null,
  drawEndsAt: null,
});

const localDateKey = () => {
  const now = new Date();
  const offset = now.getTimezoneOffset() * 60_000;
  return new Date(now.getTime() - offset).toISOString().slice(0, 10);
};

const shuffle = (ids: string[]) => {
  const result = [...ids];
  for (let index = result.length - 1; index > 0; index -= 1) {
    const swapIndex = Math.floor(Math.random() * (index + 1));
    [result[index], result[swapIndex]] = [result[swapIndex], result[index]];
  }
  return result;
};

export default function StudentRafflePage() {
  const router = useRouter();
  const {
    students = [],
    attendance = [],
    currentCenter,
    fetchStudents,
    fetchAttendance,
  } = useStore();
  const [session, setSession] = useState<RaffleSession>(emptySession);
  const [animationStudentId, setAnimationStudentId] = useState<string | null>(null);
  const [hydrated, setHydrated] = useState(false);
  const [loadedStorageKey, setLoadedStorageKey] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const intervalRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const timeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  const scopeId = currentCenter?.activeHalaqa?.id ?? currentCenter?.id ?? "local";
  const storageKey = `halaqah_raffle_v2_${scopeId}`;

  const activeStudents = useMemo(
    () => students
      .filter(student => student.status === "active")
      .sort((a, b) => a.name.localeCompare(b.name, "ar")),
    [students],
  );
  const studentsById = useMemo(
    () => new Map(activeStudents.map(student => [student.id, student])),
    [activeStudents],
  );
  const today = localDateKey();
  const absentIds = useMemo(
    () => new Set(
      attendance
        .filter(record =>
          record.date === today &&
          (record.status === "absent" || record.status === "excused")
        )
        .map(record => record.studentId),
    ),
    [attendance, today],
  );

  const eligibleIds = useMemo(
    () => activeStudents
      .map(student => student.id)
      .filter(id => !session.excludedIds.includes(id))
      .filter(id => !session.excludeAbsent || !absentIds.has(id)),
    [activeStudents, absentIds, session.excludeAbsent, session.excludedIds],
  );
  const availableIds = useMemo(
    () => eligibleIds.filter(id => !session.drawnIds.includes(id)),
    [eligibleIds, session.drawnIds],
  );

  const settleDraw = useCallback((targetId: string) => {
    setSession(current => ({
      ...current,
      selectedId: targetId,
      drawnIds: current.drawnIds.includes(targetId)
        ? current.drawnIds
        : [...current.drawnIds, targetId],
      drawTargetId: null,
      drawEndsAt: null,
    }));
    setAnimationStudentId(null);
    if (typeof navigator !== "undefined" && navigator.vibrate) {
      navigator.vibrate([100, 50, 100]);
    }
  }, []);

  useEffect(() => {
    const load = async () => {
      await Promise.all([fetchStudents(), fetchAttendance()]);
      setLoading(false);
    };
    load();
  }, [fetchAttendance, fetchStudents]);

  useEffect(() => {
    setHydrated(false);
    try {
      const raw = localStorage.getItem(storageKey);
      if (raw) {
        const saved = JSON.parse(raw) as Partial<RaffleSession>;
        setSession({ ...emptySession(), ...saved, version: 2 });
      } else {
        setSession(emptySession());
      }
    } catch {
      setSession(emptySession());
    }
    setLoadedStorageKey(storageKey);
    setHydrated(true);
  }, [storageKey]);

  useEffect(() => {
    if (!hydrated || loadedStorageKey !== storageKey) return;
    localStorage.setItem(storageKey, JSON.stringify(session));
  }, [hydrated, loadedStorageKey, session, storageKey]);

  useEffect(() => {
    if (!hydrated || activeStudents.length === 0) return;
    const valid = new Set(activeStudents.map(student => student.id));
    setSession(current => ({
      ...current,
      excludedIds: current.excludedIds.filter(id => valid.has(id)),
      drawnIds: current.drawnIds.filter(id => valid.has(id)),
      batchOrder: current.batchOrder.filter(id => valid.has(id)),
      selectedId: current.selectedId && valid.has(current.selectedId)
        ? current.selectedId
        : null,
      drawTargetId: current.drawTargetId && valid.has(current.drawTargetId)
        ? current.drawTargetId
        : null,
    }));
  }, [activeStudents, hydrated]);

  useEffect(() => {
    if (intervalRef.current) clearInterval(intervalRef.current);
    if (timeoutRef.current) clearTimeout(timeoutRef.current);
    const targetId = session.drawTargetId;
    if (!targetId || !session.drawEndsAt) return;
    const remaining = session.drawEndsAt - Date.now();
    if (remaining <= 0) {
      settleDraw(targetId);
      return;
    }
    const animationPool = eligibleIds.length > 0 ? eligibleIds : [targetId];
    intervalRef.current = setInterval(() => {
      const id = animationPool[Math.floor(Math.random() * animationPool.length)];
      setAnimationStudentId(id);
      if (typeof navigator !== "undefined" && navigator.vibrate) {
        navigator.vibrate(15);
      }
    }, 90);
    timeoutRef.current = setTimeout(() => settleDraw(targetId), remaining);
    return () => {
      if (intervalRef.current) clearInterval(intervalRef.current);
      if (timeoutRef.current) clearTimeout(timeoutRef.current);
    };
  }, [eligibleIds, session.drawEndsAt, session.drawTargetId, settleDraw]);

  const startDraw = () => {
    if (session.drawTargetId) return;
    if (availableIds.length === 0) {
      alert(
        eligibleIds.length === 0
          ? "لا يوجد طلاب مؤهلون للسحب وفق خيارات الاستبعاد الحالية."
          : "اكتملت القرعة؛ أعد ضبط المسحوبين لبدء دورة جديدة.",
      );
      return;
    }
    const batchTarget = session.batchOrder.find(id => availableIds.includes(id));
    const targetId = batchTarget ?? availableIds[Math.floor(Math.random() * availableIds.length)];
    setSession(current => ({
      ...current,
      selectedId: null,
      drawTargetId: targetId,
      drawEndsAt: Date.now() + 2600,
    }));
  };

  const createBatchOrder = () => {
    if (eligibleIds.length === 0) {
      alert("لا يوجد طلاب مؤهلون لإنشاء ترتيب القرعة.");
      return;
    }
    setSession(current => ({
      ...current,
      batchOrder: shuffle(eligibleIds),
      drawnIds: [],
      selectedId: null,
      drawTargetId: null,
      drawEndsAt: null,
    }));
  };

  const resetRaffle = () => {
    if (!confirm("هل تريد تصفير القرعة وإعادة إدراج جميع الطلاب؟")) return;
    setSession(emptySession());
    setAnimationStudentId(null);
  };

  const selectedStudent = studentsById.get(
    session.drawTargetId ? animationStudentId ?? session.drawTargetId : session.selectedId ?? "",
  );
  const isDrawing = Boolean(session.drawTargetId);

  const openRecitation = () => {
    if (!session.selectedId) return;
    localStorage.setItem("memorization_prefill_student_id", session.selectedId);
    router.push("/memorization");
  };

  if (loading || !hydrated) {
    return (
      <div className="min-h-[60vh] flex items-center justify-center">
        <div className="w-12 h-12 border-4 border-teal-500 border-t-transparent rounded-full animate-spin" />
      </div>
    );
  }

  return (
    <div className="max-w-5xl mx-auto space-y-7 pb-16 animate-in fade-in duration-500">
      <header className="flex flex-col lg:flex-row lg:items-center justify-between gap-4 border-b border-gray-100 dark:border-gray-800 pb-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white flex items-center gap-3">
            <Dices className="w-8 h-8 text-teal-600" />
            قرعة الطلاب المستمرة
          </h1>
          <p className="text-sm text-gray-500 mt-2">
            تحفظ الدورة لكل حلقة، وتستأنف تلقائيًا بعد مغادرة الشاشة.
          </p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={resetRaffle} className="px-4 py-3 rounded-xl bg-rose-50 text-rose-700 text-xs font-black flex items-center gap-2">
            <RotateCcw className="w-4 h-4" /> تصفير الدورة
          </button>
          <button onClick={() => router.push("/")} className="px-4 py-3 rounded-xl bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 text-xs font-black flex items-center gap-2">
            <ArrowLeft className="w-4 h-4" /> الرئيسية
          </button>
        </div>
      </header>

      <div className="grid sm:grid-cols-3 gap-3">
        <div className="rounded-2xl bg-teal-50 dark:bg-teal-950/20 p-4 text-teal-800 dark:text-teal-300 font-black text-sm flex items-center gap-2">
          <Users className="w-5 h-5" /> المتاحون: {availableIds.length}
        </div>
        <div className="rounded-2xl bg-blue-50 dark:bg-blue-950/20 p-4 text-blue-800 dark:text-blue-300 font-black text-sm flex items-center gap-2">
          <CheckCircle2 className="w-5 h-5" /> تم سحبهم: {session.drawnIds.length}
        </div>
        <div className="rounded-2xl bg-orange-50 dark:bg-orange-950/20 p-4 text-orange-800 dark:text-orange-300 font-black text-sm flex items-center gap-2">
          <UserX className="w-5 h-5" /> مستبعدون: {activeStudents.length - eligibleIds.length}
        </div>
      </div>

      <label className="flex items-center justify-between gap-4 rounded-2xl border border-gray-200 dark:border-gray-800 bg-white dark:bg-gray-900 p-5 cursor-pointer">
        <span className="flex items-center gap-3">
          <ShieldCheck className="w-5 h-5 text-teal-600" />
          <span>
            <strong className="block text-sm text-gray-900 dark:text-white">استبعاد الغائبين والمستأذنين اليوم</strong>
            <small className="text-gray-500">الخيار قابل للإلغاء عند الحاجة إلى إدخالهم في القرعة.</small>
          </span>
        </span>
        <input
          type="checkbox"
          checked={session.excludeAbsent}
          onChange={event => setSession(current => ({ ...current, excludeAbsent: event.target.checked }))}
          className="w-5 h-5 accent-teal-600"
        />
      </label>

      <section className="min-h-[330px] rounded-[2.5rem] border border-gray-100 dark:border-gray-800 bg-white dark:bg-gray-900 shadow-xl flex items-center justify-center p-8">
        {selectedStudent ? (
          <div className="text-center space-y-5 animate-in zoom-in-95 duration-200">
            {!isDrawing && (
              <span className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-amber-500 text-white text-xs font-black">
                <Star className="w-4 h-4 fill-white" /> الطالب التالي
              </span>
            )}
            <div className={`w-24 h-24 mx-auto rounded-full flex items-center justify-center text-3xl font-black text-white ${isDrawing ? "bg-teal-600" : "bg-amber-500"}`}>
              {selectedStudent.name.charAt(0)}
            </div>
            <h2 className="text-4xl font-black text-gray-900 dark:text-white">{selectedStudent.name}</h2>
            <p className="text-sm text-gray-500">{isDrawing ? "جاري خلط الأسماء…" : `الترتيب ${session.drawnIds.length} في هذه الدورة`}</p>
          </div>
        ) : (
          <div className="text-center space-y-3">
            <Dices className="w-20 h-20 text-teal-200 mx-auto" />
            <h2 className="text-2xl font-black text-gray-800 dark:text-white">ابدأ السحب أو أنشئ ترتيبًا كاملًا</h2>
            <p className="text-sm text-gray-500">لن يتكرر الطالب حتى تصفير الدورة أو إعادته يدويًا.</p>
          </div>
        )}
      </section>

      {session.selectedId && !isDrawing && (
        <div className="grid md:grid-cols-3 gap-3">
          <button onClick={openRecitation} className="p-4 rounded-2xl bg-teal-600 text-white font-black text-sm flex items-center justify-center gap-2">
            <BookOpen className="w-5 h-5" /> فتح تسميع الطالب
          </button>
          <button onClick={() => router.push("/students")} className="p-4 rounded-2xl bg-gray-900 dark:bg-white text-white dark:text-gray-900 font-black text-sm flex items-center justify-center gap-2">
            <ClipboardList className="w-5 h-5" /> ملف الطالب
          </button>
          <button
            onClick={() => setSession(current => ({
              ...current,
              excludedIds: current.selectedId && !current.excludedIds.includes(current.selectedId)
                ? [...current.excludedIds, current.selectedId]
                : current.excludedIds,
              selectedId: null,
            }))}
            className="p-4 rounded-2xl bg-orange-50 text-orange-700 font-black text-sm flex items-center justify-center gap-2"
          >
            <UserX className="w-5 h-5" /> استبعاد بقية الدورة
          </button>
        </div>
      )}

      <div className="grid md:grid-cols-2 gap-3">
        <button
          onClick={startDraw}
          disabled={isDrawing || availableIds.length === 0}
          className="py-5 rounded-2xl bg-teal-600 disabled:bg-gray-300 text-white font-black flex items-center justify-center gap-3"
        >
          <Dices className="w-5 h-5" />
          {isDrawing ? "جاري السحب…" : session.batchOrder.length > 0 ? "سحب التالي من الترتيب" : "سحب طالب عشوائي"}
        </button>
        <button
          onClick={createBatchOrder}
          disabled={isDrawing || eligibleIds.length === 0}
          className="py-5 rounded-2xl border-2 border-teal-600 text-teal-700 dark:text-teal-300 disabled:opacity-40 font-black flex items-center justify-center gap-3"
        >
          <ListOrdered className="w-5 h-5" /> قرعة دفعة واحدة
        </button>
      </div>

      {session.batchOrder.length > 0 && (
        <section className="rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-6 space-y-4">
          <h3 className="font-black text-gray-900 dark:text-white flex items-center gap-2">
            <ListOrdered className="w-5 h-5 text-teal-600" /> ترتيب التسميع الكامل
          </h3>
          <ol className="grid sm:grid-cols-2 lg:grid-cols-3 gap-2">
            {session.batchOrder.map((id, index) => {
              const student = studentsById.get(id);
              if (!student) return null;
              const drawn = session.drawnIds.includes(id);
              return (
                <li key={id} className={`rounded-xl px-4 py-3 text-sm font-bold flex items-center gap-3 ${drawn ? "bg-teal-50 text-teal-800 dark:bg-teal-950/20 dark:text-teal-300" : "bg-gray-50 dark:bg-gray-800 text-gray-700 dark:text-gray-200"}`}>
                  <span className="w-7 h-7 rounded-full bg-white dark:bg-gray-900 flex items-center justify-center text-xs">{index + 1}</span>
                  <span className="flex-1">{student.name}</span>
                  {drawn && <CheckCircle2 className="w-4 h-4" />}
                </li>
              );
            })}
          </ol>
        </section>
      )}

      {(session.excludedIds.length > 0 || session.drawnIds.length > 0) && (
        <section className="rounded-3xl bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 p-6 space-y-4">
          <h3 className="font-black text-gray-900 dark:text-white">إدارة المستبعدين والمسحوبين</h3>
          <div className="flex flex-wrap gap-2">
            {Array.from(new Set([...session.excludedIds, ...session.drawnIds])).map(id => {
              const student = studentsById.get(id);
              if (!student) return null;
              return (
                <button
                  key={id}
                  onClick={() => setSession(current => ({
                    ...current,
                    excludedIds: current.excludedIds.filter(item => item !== id),
                    drawnIds: current.drawnIds.filter(item => item !== id),
                    selectedId: current.selectedId === id ? null : current.selectedId,
                  }))}
                  className="px-4 py-2 rounded-xl bg-gray-100 dark:bg-gray-800 text-xs font-bold text-gray-700 dark:text-gray-200 hover:bg-teal-50"
                >
                  {student.name} × إعادة للسحب
                </button>
              );
            })}
          </div>
        </section>
      )}
    </div>
  );
}
