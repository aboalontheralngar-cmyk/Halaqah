"use client";

import { useMemo, useSyncExternalStore } from "react";
import { useRouter } from "next/navigation";
import {
  Activity,
  Award,
  BarChart3,
  Bell,
  BookOpen,
  CheckCircle2,
  ClipboardCheck,
  ListChecks,
  Loader2,
  Target,
  UserPlus,
  Users,
  X,
} from "lucide-react";
import { useShallow } from "zustand/react/shallow";
import { useStore } from "@/store/useStore";
import {
  ActionLinkCard,
  MetricCard,
  PageHeader,
  PageStack,
  ProgressPanel,
  SectionHeading,
  Surface,
} from "@/components/ui/AppDesign";
import { getHijriDate, localDateKey } from "@/utils/dateUtils";

const subscribeToClient = () => () => undefined;
const getClientSnapshot = () => true;
const getServerSnapshot = () => false;


export default function Dashboard() {
  const router = useRouter();
  const mounted = useSyncExternalStore(
    subscribeToClient,
    getClientSnapshot,
    getServerSnapshot,
  );
  const {
    students,
    attendance,
    centerType,
    activities,
    loading,
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      attendance: state.attendance,
      centerType: state.centerType,
      activities: state.activities,
      loading: state.loading,
    })),
  );

  const safeStudents = useMemo(
    () => (Array.isArray(students) ? students : []),
    [students],
  );
  const safeAttendance = useMemo(
    () => (Array.isArray(attendance) ? attendance : []),
    [attendance],
  );
  const isMen = centerType === "men";
  const labels = {
    students: isMen ? "الطلاب" : "الطالبات",
    addStudent: isMen ? "إضافة طالب" : "إضافة طالبة",
  };

  const dashboardState = useMemo(() => {
    const today = localDateKey();
    const todayAttendance = safeAttendance.filter(
      (record) => record?.date === today,
    );
    const presentToday = todayAttendance.filter(
      (record) => record.status === "present" || record.status === "late",
    ).length;
    const absentToday = todayAttendance.filter(
      (record) => record.status === "absent",
    ).length;
    const recordedToday = new Set(
      todayAttendance.map((record) => record.studentId),
    ).size;
    const pendingToday = Math.max(0, safeStudents.length - recordedToday);
    const attendanceRate = safeStudents.length
      ? Math.round((recordedToday / safeStudents.length) * 100)
      : 0;
    return {
      presentToday,
      absentToday,
      pendingToday,
      attendanceRate,
    };
  }, [safeAttendance, safeStudents.length]);

  if (!mounted) return null;

  if (loading && safeStudents.length === 0) {
    return (
      <div className="flex min-h-[60vh] items-center justify-center">
        <Loader2 className="h-9 w-9 animate-spin text-[var(--primary)]" />
      </div>
    );
  }

  const hijriDate = getHijriDate()?.full ?? "";
  const dailyActions = [
    {
      title: "تسجيل الحضور",
      description: dashboardState.pendingToday
        ? `${dashboardState.pendingToday} لم يُرصد بعد`
        : "اكتمل رصد اليوم",
      icon: ClipboardCheck,
      tone: "teal" as const,
      href: "/attendance",
    },
    {
      title: "الحفظ والمراجعة",
      description: "تسجيل مباشر أو جلسة تسميع",
      icon: BookOpen,
      tone: "blue" as const,
      href: "/memorization",
    },
    {
      title: "مراجعة اليوم",
      description: "تحقق من السجلات ثم اعتمد الإغلاق",
      icon: ListChecks,
      tone: "amber" as const,
      href: "/daily-closing",
    },
    {
      title: "الخطط الذكية",
      description: "المقرر والتقدم الفعلي",
      icon: Target,
      tone: "purple" as const,
      href: "/plans",
    },
    {
      title: "التقارير",
      description: "الأداء والتصدير والطباعة",
      icon: BarChart3,
      tone: "green" as const,
      href: "/reports",
    },
    {
      title: labels.addStudent,
      description: `إدارة ملفات ${labels.students}`,
      icon: UserPlus,
      tone: "teal" as const,
      href: "/students",
    },
    {
      title: "السلوك والنقاط",
      description: "تعزيز ومتابعة موثقة",
      icon: Award,
      tone: "amber" as const,
      href: "/points",
    },
  ];

  return (
    <PageStack>
      <PageHeader
        title="مساحة عمل الحلقة"
        description={`${hijriDate} · ابدأ بما يحتاج إجراءً اليوم، ثم انتقل إلى المتابعة والتقارير.`}
        actions={
          <button
            type="button"
            aria-label="فتح الإشعارات"
            onClick={() => router.push("/notifications")}
            className="flex h-11 w-11 items-center justify-center rounded-xl border border-[var(--border)] bg-[var(--surface)] text-[var(--muted)] shadow-[var(--shadow-soft)] hover:text-[var(--primary)]"
          >
            <Bell className="h-5 w-5" />
          </button>
        }
      />

      <ProgressPanel
        eyebrow="متابعة اليوم"
        title={
          dashboardState.pendingToday
            ? `تبقّى رصد ${dashboardState.pendingToday} من ${labels.students}`
            : "تم رصد حضور الجميع"
        }
        description={
          dashboardState.pendingToday
            ? "ابدأ بالحضور؛ بعده يصبح التسميع وإغلاق اليوم أكثر دقة."
            : "يمكنك الانتقال مباشرةً إلى الحفظ والمراجعة."
        }
        progress={dashboardState.attendanceRate}
        action={
          <button
            type="button"
            onClick={() =>
              router.push(
                dashboardState.pendingToday ? "/attendance" : "/memorization",
              )
            }
            className="rounded-xl bg-[var(--primary)] px-5 py-3 text-sm font-extrabold text-white transition hover:bg-[var(--primary-hover)] dark:text-[#00382d]"
          >
            {dashboardState.pendingToday ? "فتح الحضور" : "فتح التسميع"}
          </button>
        }
      />

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-3">
        <MetricCard
          label={`إجمالي ${labels.students}`}
          value={safeStudents.length}
          icon={Users}
          tone="blue"
        />
        <MetricCard
          label="حاضر أو متأخر"
          value={dashboardState.presentToday}
          icon={CheckCircle2}
          tone="green"
        />
        <MetricCard
          label="غائب اليوم"
          value={dashboardState.absentToday}
          icon={X}
          tone="red"
        />
      </div>

      <section className="space-y-3">
        <SectionHeading
          title="المهام اليومية"
          description="أهم إجراءات المعلم في مكان واحد وبالترتيب الطبيعي للعمل."
        />
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {dailyActions.map((action) => (
            <ActionLinkCard
              key={action.href}
              title={action.title}
              description={action.description}
              icon={action.icon}
              tone={action.tone}
              onClick={() => router.push(action.href)}
            />
          ))}
        </div>
      </section>

      <section className="space-y-3">
        <SectionHeading
          title="آخر النشاطات"
          description="أحدث ما تغيّر في الحلقة دون ازدحام بلوحات ثانوية."
          action={
            <button
              type="button"
              onClick={() => router.push("/notifications")}
              className="text-sm font-extrabold text-[var(--primary)]"
            >
              عرض السجل
            </button>
          }
        />
        <Surface className="p-4">
          {activities.length > 0 ? (
            <div className="divide-y divide-[var(--border)]">
              {activities.slice(0, 4).map((activity) => (
                <div
                  key={activity.id}
                  className="flex items-start gap-3 py-3 first:pt-0 last:pb-0"
                >
                  <span className="mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-xl bg-[var(--primary-soft)] text-[var(--primary)]">
                    <Activity className="h-4 w-4" />
                  </span>
                  <p className="text-sm font-bold leading-6 text-[var(--foreground)]">
                    {activity.description}
                  </p>
                </div>
              ))}
            </div>
          ) : (
            <p className="py-8 text-center text-sm font-bold text-[var(--muted)]">
              لا توجد نشاطات جديدة حاليًا.
            </p>
          )}
        </Surface>
      </section>
    </PageStack>
  );
}
