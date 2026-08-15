"use client";

import { useEffect, useMemo, useState } from "react";
import { useShallow } from "zustand/react/shallow";
import Link from "next/link";
import { useParams, useRouter } from "next/navigation";
import {
  ArrowRight,
  BookOpen,
  CalendarCheck,
  CalendarDays,
  CheckCircle2,
  Clock3,
  Map,
  MessageCircle,
  QrCode,
  Save,
  Sparkles,
  Target,
  Trophy,
  UserRound,
} from "lucide-react";
import { QRCodeSVG } from "qrcode.react";
import { useStore, type HomeworkGrade } from "@/store/useStore";
import { encodeStudentQr } from "@/lib/studentQr";
import { quranService, type Surah } from "@/services/quranService";
import {
  EmptyState,
  MetricCard,
  PageHeader,
  Surface,
} from "@/components/ui/AppDesign";
import { localDateKey } from "@/utils/dateUtils";

const unitLabel = {
  ayahs: "آيات",
  pages: "صفحات",
  lines: "أسطر",
  hizbs: "أحزاب",
} as const;

const gradeLabel: Record<HomeworkGrade["gradeMark"], string> = {
  excellent: "ممتاز",
  very_good: "جيد جدًا",
  good: "جيد",
  needs_work: "يحتاج متابعة",
  absent: "غائب",
};

const statusLabel = {
  active: "نشط",
  inactive: "طالب سابق",
  suspended: "موقوف",
  expelled: "مفصول",
  graduated: "خاتم / متخرج",
} as const;

export default function StudentDetailPage() {
  const params = useParams<{ id: string }>();
  const router = useRouter();
  const {
    students,
    attendance,
    homeworkGrades,
    points,
    plans,
    vacations,
    loading,
    fetchCenterData,
    updateStudent
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      attendance: state.attendance,
      homeworkGrades: state.homeworkGrades,
      points: state.points,
      plans: state.plans,
      vacations: state.vacations,
      loading: state.loading,
      fetchCenterData: state.fetchCenterData,
      updateStudent: state.updateStudent,
    })),
  );
  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [planAmount, setPlanAmount] = useState<number | null>(null);
  const [reviewPlanAmount, setReviewPlanAmount] = useState<number | null>(null);
  const [savingPlan, setSavingPlan] = useState(false);
  const [savedMessage, setSavedMessage] = useState("");

  const student = students.find(item => item.id === params.id);

  useEffect(() => {
    fetchCenterData();
    quranService.initialize().then(() => setSurahs(quranService.getSurahs()));
  }, [fetchCenterData]);

  const studentGrades = useMemo(
    () => homeworkGrades
      .filter(grade => grade.studentId === params.id)
      .sort((left, right) =>
        right.date.localeCompare(left.date) ||
        (right.createdAt ?? "").localeCompare(left.createdAt ?? ""),
      ),
    [homeworkGrades, params.id],
  );

  const summary = useMemo(() => {
    const heard = studentGrades.filter(grade => grade.gradeMark !== "absent");
    const newMemorization = heard.filter(grade => !grade.isRevision);
    const revision = heard.filter(grade => grade.isRevision);
    const studentAttendance = attendance.filter(record => record.studentId === params.id);
    const present = studentAttendance.filter(record =>
      record.status === "present" || record.status === "late",
    ).length;
    const absent = studentAttendance.filter(record => record.status === "absent").length;
    const pointBalance = points
      .filter(point => point.studentId === params.id)
      .reduce(
        (sum, point) => sum + (point.type === "positive" ? point.amount : -point.amount),
        0,
      );
    return {
      ayahs: newMemorization.reduce(
        (sum, grade) => sum + Math.max(0, grade.toAyah - grade.fromAyah + 1),
        0,
      ),
      revisionAyahs: revision.reduce(
        (sum, grade) => sum + Math.max(0, grade.toAyah - grade.fromAyah + 1),
        0,
      ),
      present,
      absent,
      pointBalance,
    };
  }, [attendance, params.id, points, studentGrades]);

  const activePlan = plans
    .filter(plan => plan.studentId === params.id && plan.status === "active")
    .sort((left, right) => right.startDate.localeCompare(left.startDate))[0];
  const currentVacation = vacations.find(vacation => {
    const today = localDateKey();
    return vacation.studentId === params.id && vacation.approved &&
      vacation.startDate <= today && vacation.endDate >= today;
  });
  const lastMemorization = studentGrades.find(
    grade => !grade.isRevision && grade.gradeMark !== "absent",
  );
  const lastRevision = studentGrades.find(
    grade => grade.isRevision && grade.gradeMark !== "absent",
  );

  const surahName = (number?: number) =>
    number ? surahs.find(surah => surah.number === number)?.name ?? `رقم ${number}` : "—";

  const openRecitation = () => {
    if (!student) return;
    localStorage.setItem("memorization_prefill_student_id", student.id);
    router.push("/memorization");
  };

  const saveDailyPlan = async () => {
    if (!student) return;
    const nextPlanAmount = planAmount ?? student.planAmount;
    const nextReviewPlanAmount = reviewPlanAmount ?? student.reviewPlanAmount;
    if (nextPlanAmount < 1 || nextReviewPlanAmount < 1) return;
    setSavingPlan(true);
    await updateStudent(student.id, {
      planAmount: nextPlanAmount,
      reviewPlanAmount: nextReviewPlanAmount,
    });
    setSavingPlan(false);
    setSavedMessage("تم تحديث المقرر اليومي للحفظ والمراجعة");
    window.setTimeout(() => setSavedMessage(""), 3000);
  };

  if (!student && loading) {
    return <div className="py-24 text-center font-black text-gray-400">جاري تحميل ملف الطالب…</div>;
  }

  if (!student) {
    return (
      <Surface>
        <EmptyState
          icon={UserRound}
          title="تعذر العثور على الطالب"
          description="قد يكون الطالب خارج الحلقة الحالية أو نُقل إلى الأرشيف."
          action={<Link href="/students" className="font-black text-teal-700">العودة إلى الطلاب</Link>}
        />
      </Surface>
    );
  }

  return (
    <div className="page-enter space-y-7 pb-20">
      <PageHeader
        title={`ملف الطالب: ${student.name}`}
        description="صفحة موحّدة للمحفوظ، المراجعة، الحضور، النقاط، والخطة اليومية."
        icon={UserRound}
        actions={(
          <div className="flex flex-wrap gap-2">
            <button onClick={openRecitation} className="rounded-2xl bg-teal-600 px-5 py-3 text-xs font-black text-white">
              تسجيل تسميع
            </button>
            <Link href="/students" className="flex items-center gap-2 rounded-2xl bg-gray-100 px-5 py-3 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200">
              <ArrowRight className="h-4 w-4" /> الطلاب
            </Link>
          </div>
        )}
      />

      <Surface className="overflow-hidden">
        <div className="grid gap-6 p-6 lg:grid-cols-[1fr_auto] lg:items-center lg:p-8">
          <div className="flex min-w-0 flex-col gap-5 sm:flex-row sm:items-center">
            <div className="flex h-20 w-20 shrink-0 items-center justify-center rounded-3xl bg-gradient-to-br from-teal-500 to-teal-700 text-3xl font-black text-white">
              {student.name.slice(0, 1)}
            </div>
            <div className="min-w-0">
              <div className="flex flex-wrap items-center gap-2">
                <h2 className="text-2xl font-black text-[var(--foreground)]">{student.name}</h2>
                <span className="rounded-full bg-teal-50 px-3 py-1 text-[10px] font-black text-teal-700 dark:bg-teal-950/30 dark:text-teal-300">
                  {statusLabel[student.status]}
                </span>
                {currentVacation && (
                  <span className="rounded-full bg-blue-50 px-3 py-1 text-[10px] font-black text-blue-700 dark:bg-blue-950/30 dark:text-blue-300">
                    في إجازة حتى {currentVacation.endDate}
                  </span>
                )}
              </div>
              <div className="mt-3 flex flex-wrap gap-x-5 gap-y-2 text-xs font-bold text-gray-500">
                <span>الكود: <b dir="ltr" className="text-[var(--foreground)]">{student.studentCode ?? "غير مولّد"}</b></span>
                <span>المستوى: {student.level}</span>
                <span>الانضمام: {student.joinDate}</span>
                <span>ولي الأمر: {student.parentPhone || "غير مسجل"}</span>
              </div>
            </div>
          </div>
          <div className="justify-self-center rounded-2xl bg-white p-3 shadow-sm ring-1 ring-gray-100">
            <QRCodeSVG value={encodeStudentQr(student.qrCode || student.id)} size={116} />
            <p className="mt-2 text-center text-[9px] font-black text-gray-500">QR الحضور والبوابة</p>
          </div>
        </div>
      </Surface>

      <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-5">
        <MetricCard icon={BookOpen} label="آيات الحفظ المسجلة" value={summary.ayahs} />
        <MetricCard icon={Sparkles} label="آيات المراجعة" value={summary.revisionAyahs} tone="purple" />
        <MetricCard icon={CalendarCheck} label="أيام الحضور" value={summary.present} tone="green" />
        <MetricCard icon={CalendarDays} label="أيام الغياب" value={summary.absent} tone="red" />
        <MetricCard icon={Trophy} label="رصيد النقاط" value={summary.pointBalance} tone="amber" />
      </div>

      <div className="grid gap-6 xl:grid-cols-3">
        <Surface className="p-6 xl:col-span-2">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <h2 className="text-lg font-black text-[var(--foreground)]">المحفوظ والمسار الحالي</h2>
              <p className="mt-1 text-xs text-gray-500">يجمع محفوظ الملف مع آخر تسميع مسجل.</p>
            </div>
            <Link href="/plans" className="rounded-xl bg-gray-100 px-4 py-2 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200">
              إدارة الخطط
            </Link>
          </div>
          <div className="mt-5 grid gap-4 sm:grid-cols-2">
            <div className="rounded-2xl bg-amber-50 p-5 dark:bg-amber-950/20">
              <p className="text-xs font-black text-amber-700 dark:text-amber-300">المحفوظ المثبت في ملف الطالب</p>
              <p className="mt-2 text-sm font-black text-[var(--foreground)]">
                {student.preMemorizedStartSurah
                  ? `من ${surahName(student.preMemorizedStartSurah)} آية ${student.preMemorizedStartAyah ?? 1} إلى ${surahName(student.preMemorizedEndSurah)} آية ${student.preMemorizedEndAyah ?? 1}`
                  : "لم يُسجل نطاق محفوظ سابق بعد"}
              </p>
            </div>
            <div className="rounded-2xl bg-teal-50 p-5 dark:bg-teal-950/20">
              <p className="text-xs font-black text-teal-700 dark:text-teal-300">آخر حفظ جديد</p>
              <p className="mt-2 text-sm font-black text-[var(--foreground)]">
                {lastMemorization
                  ? `${lastMemorization.surah} (${lastMemorization.fromAyah}–${lastMemorization.toAyah}) · ${lastMemorization.date}`
                  : "لا يوجد تسميع حفظ مسجل"}
              </p>
            </div>
            <div className="rounded-2xl bg-purple-50 p-5 dark:bg-purple-950/20">
              <p className="text-xs font-black text-purple-700 dark:text-purple-300">آخر مراجعة</p>
              <p className="mt-2 text-sm font-black text-[var(--foreground)]">
                {lastRevision
                  ? `${lastRevision.surah} (${lastRevision.fromAyah}–${lastRevision.toAyah}) · ${lastRevision.date}`
                  : "لا توجد مراجعة مسجلة"}
              </p>
            </div>
            <div className="rounded-2xl bg-blue-50 p-5 dark:bg-blue-950/20">
              <p className="text-xs font-black text-blue-700 dark:text-blue-300">الخطة النشطة</p>
              <p className="mt-2 text-sm font-black text-[var(--foreground)]">
                {activePlan
                  ? `${activePlan.period === "weekly" ? "أسبوعية" : "شهرية"} حتى ${activePlan.endDate} · اختبار التجاوز: ${activePlan.testStatus}`
                  : "لا توجد خطة نشطة"}
              </p>
            </div>
          </div>
        </Surface>

        <Surface className="p-6">
          <div className="flex items-center gap-3">
            <Target className="h-5 w-5 text-teal-600" />
            <div>
              <h2 className="text-lg font-black text-[var(--foreground)]">المقرر اليومي</h2>
              <p className="text-xs text-gray-500">تعديل سريع من ملف الطالب.</p>
            </div>
          </div>
          <div className="mt-5 space-y-4">
            <label className="block text-xs font-black text-gray-500">
              مقدار الحفظ ({unitLabel[student.planType]})
              <input type="number" min={1} value={planAmount ?? student.planAmount} onChange={event => setPlanAmount(Math.max(1, Number(event.target.value) || 1))} className="mt-2 w-full rounded-2xl bg-gray-50 px-4 py-3 text-sm font-black outline-none dark:bg-gray-800" />
            </label>
            <label className="block text-xs font-black text-gray-500">
              مقدار المراجعة ({unitLabel[student.planType]})
              <input type="number" min={1} value={reviewPlanAmount ?? student.reviewPlanAmount} onChange={event => setReviewPlanAmount(Math.max(1, Number(event.target.value) || 1))} className="mt-2 w-full rounded-2xl bg-gray-50 px-4 py-3 text-sm font-black outline-none dark:bg-gray-800" />
            </label>
            <button onClick={saveDailyPlan} disabled={savingPlan} className="flex w-full items-center justify-center gap-2 rounded-2xl bg-teal-600 py-4 text-xs font-black text-white disabled:opacity-50">
              <Save className="h-4 w-4" /> {savingPlan ? "جاري الحفظ…" : "حفظ المقرر"}
            </button>
            {savedMessage && <p className="text-center text-xs font-black text-emerald-600">{savedMessage}</p>}
          </div>
        </Surface>
      </div>

      <Surface className="overflow-hidden">
        <div className="flex flex-wrap items-center justify-between gap-3 border-b border-[var(--border)] p-6">
          <div>
            <h2 className="text-lg font-black text-[var(--foreground)]">آخر سجلات الحفظ والمراجعة</h2>
            <p className="mt-1 text-xs text-gray-500">يمكن تعديل السجل أو حذفه من شاشة التسميع.</p>
          </div>
          <Link href="/memorization" className="rounded-xl bg-teal-50 px-4 py-2 text-xs font-black text-teal-700 dark:bg-teal-950/30 dark:text-teal-300">
            فتح سجل التسميع
          </Link>
        </div>
        {studentGrades.length === 0 ? (
          <EmptyState icon={BookOpen} title="لا توجد سجلات بعد" description="ابدأ بأول جلسة حفظ أو مراجعة لهذا الطالب." />
        ) : (
          <div className="divide-y divide-[var(--border)]">
            {studentGrades.slice(0, 12).map(grade => (
              <div key={grade.id} className="grid gap-3 p-5 sm:grid-cols-[1fr_auto] sm:items-center">
                <div>
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-black text-[var(--foreground)]">{grade.isRevision ? "مراجعة" : "حفظ"} سورة {grade.surah}</span>
                    <span className="rounded-full bg-gray-100 px-2.5 py-1 text-[10px] font-black text-gray-600 dark:bg-gray-800 dark:text-gray-300">{gradeLabel[grade.gradeMark]}</span>
                  </div>
                  <p className="mt-1 text-xs font-bold text-gray-500">الآيات {grade.fromAyah}–{grade.toAyah} · {grade.date} · الأخطاء {grade.mistakesCount}</p>
                </div>
                <div className="flex items-center gap-2 text-xs font-black text-gray-400">
                  {grade.gradeMark === "absent" ? <Clock3 className="h-4 w-4 text-rose-500" /> : <CheckCircle2 className="h-4 w-4 text-emerald-500" />}
                  {grade.remark || "بلا ملاحظة"}
                </div>
              </div>
            ))}
          </div>
        )}
      </Surface>

      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <Link href="/reports" className="flex items-center justify-center gap-2 rounded-2xl bg-gray-100 px-5 py-4 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200"><MessageCircle className="h-4 w-4" /> التقارير</Link>
        <Link href="/vacations" className="flex items-center justify-center gap-2 rounded-2xl bg-gray-100 px-5 py-4 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200"><CalendarDays className="h-4 w-4" /> الإجازات</Link>
        <Link href="/students" className="flex items-center justify-center gap-2 rounded-2xl bg-gray-100 px-5 py-4 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200"><Map className="h-4 w-4" /> خريطة المصحف من قائمة الطلاب</Link>
        <div className="flex items-center justify-center gap-2 rounded-2xl bg-gray-100 px-5 py-4 text-xs font-black text-gray-700 dark:bg-gray-800 dark:text-gray-200"><QrCode className="h-4 w-4" /> الكود جاهز للطباعة</div>
      </div>
    </div>
  );
}
