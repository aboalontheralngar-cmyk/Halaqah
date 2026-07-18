"use client";

import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowRight,
  BarChart3,
  BookOpen,
  Building2,
  Check,
  ClipboardCheck,
  Copy,
  Link2,
  Loader2,
  Printer,
  RefreshCw,
  ShieldCheck,
  TrendingUp,
  Unlink,
  UserPlus,
  Users,
} from "lucide-react";
import { supabase } from "@/lib/supabase";
import { useStore } from "@/store/useStore";

type SupervisorRole = "owner" | "admin" | "analyst";

type SupervisionCenter = {
  id: string;
  name: string;
  type: "men" | "women" | "mixed";
  address?: string | null;
  halaqat_count: number;
  active_students: number;
  attendance_records: number;
  attended_records: number;
  attendance_rate: number;
  absent_records: number;
  excused_records: number;
  new_sessions: number;
  new_ayahs: number;
  review_sessions: number;
  review_ayahs: number;
  positive_points: number;
  negative_points: number;
};

type SupervisionTotals = Omit<SupervisionCenter, "id" | "name" | "type" | "address"> & {
  centers_count: number;
  halaqat_count: number;
  active_students: number;
};

type SupervisionDashboard = {
  supervisor: { id: string; name: string; role: SupervisorRole };
  period: { start_date: string; end_date: string };
  totals: SupervisionTotals;
  centers: SupervisionCenter[];
};

type SupervisorMember = {
  user_id: string;
  full_name: string;
  email?: string | null;
  role: SupervisorRole;
  status: "active" | "revoked";
  joined_at: string;
};

const roleLabels: Record<SupervisorRole, string> = {
  owner: "مالك الجهة",
  admin: "مدير إشرافي",
  analyst: "محلل للقراءة فقط",
};

function todayKey() {
  return new Date().toISOString().slice(0, 10);
}

function monthStartKey() {
  return `${todayKey().slice(0, 7)}-01`;
}

function invitationError(error: unknown) {
  const message = error instanceof Error ? error.message : String(error ?? "");
  if (message.includes("supervisor_manager_required")) return "هذه العملية متاحة لمالك الجهة أو المدير الإشرافي فقط.";
  if (message.includes("center_already_linked")) return "المركز مرتبط بجهة إشرافية أخرى. افصل الربط القديم أولًا.";
  if (message.includes("invalid_or_expired")) return "الدعوة غير صحيحة أو انتهت صلاحيتها أو استُخدمت من قبل.";
  if (message.includes("center_owner_required")) return "لا يستطيع ربط المركز إلا مالكه.";
  return "تعذر إتمام العملية. تأكد من تنفيذ SQL المرحلة P7.3 ومن صلاحيات الحساب.";
}

export default function SupervisionPage() {
  const router = useRouter();
  const {
    user,
    currentSupervisor,
    fetchProfile,
    acceptSupervisorMemberInvitation,
  } = useStore();
  const [startDate, setStartDate] = useState(monthStartKey);
  const [endDate, setEndDate] = useState(todayKey);
  const [dashboard, setDashboard] = useState<SupervisionDashboard | null>(null);
  const [members, setMembers] = useState<SupervisorMember[]>([]);
  const [loading, setLoading] = useState(true);
  const [actionLoading, setActionLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState("");
  const [centerInvite, setCenterInvite] = useState("");
  const [centerInviteExpiry, setCenterInviteExpiry] = useState("");
  const [centerInviteUses, setCenterInviteUses] = useState(1);
  const [memberEmail, setMemberEmail] = useState("");
  const [memberRole, setMemberRole] = useState<"admin" | "analyst">("analyst");
  const [memberInvite, setMemberInvite] = useState("");
  const [joinCode, setJoinCode] = useState("");
  const [copied, setCopied] = useState<"center" | "member" | null>(null);

  const canManage = currentSupervisor?.role === "owner" || currentSupervisor?.role === "admin";

  const fetchMembers = useCallback(async () => {
    if (!supabase || !currentSupervisor || !canManage) {
      setMembers([]);
      return;
    }
    const { data, error } = await supabase.rpc("get_supervisor_members", {
      p_supervisor_id: currentSupervisor.id,
    });
    if (error) throw error;
    setMembers(Array.isArray(data) ? data as SupervisorMember[] : []);
  }, [currentSupervisor, canManage]);

  const fetchDashboard = useCallback(async () => {
    if (!supabase || !currentSupervisor) return;
    setLoading(true);
    setErrorMessage("");
    const { data, error } = await supabase.rpc("get_supervisor_dashboard", {
      p_supervisor_id: currentSupervisor.id,
      p_start_date: startDate,
      p_end_date: endDate,
    });
    if (error) {
      setErrorMessage(invitationError(error));
      setLoading(false);
      return;
    }
    setDashboard(data as SupervisionDashboard);
    try {
      await fetchMembers();
    } catch (memberError) {
      console.error("Unable to fetch supervisor members", memberError);
    }
    setLoading(false);
  }, [currentSupervisor, startDate, endDate, fetchMembers]);

  useEffect(() => {
    if (user && !currentSupervisor) {
      fetchProfile();
    }
  }, [user, currentSupervisor, fetchProfile]);

  useEffect(() => {
    const timer = window.setTimeout(() => {
      if (currentSupervisor) {
        void fetchDashboard();
      } else if (user) {
        setLoading(false);
      }
    }, 0);
    return () => window.clearTimeout(timer);
  }, [currentSupervisor, fetchDashboard, user]);

  const sortedCenters = useMemo(
    () => [...(dashboard?.centers ?? [])].sort((a, b) =>
      b.attendance_rate - a.attendance_rate || b.new_ayahs - a.new_ayahs || a.name.localeCompare(b.name, "ar")
    ),
    [dashboard],
  );

  const copyCode = async (kind: "center" | "member", value: string) => {
    await navigator.clipboard.writeText(value);
    setCopied(kind);
    window.setTimeout(() => setCopied(null), 1800);
  };

  const createCenterInvitation = async () => {
    if (!supabase || !currentSupervisor || !canManage) return;
    setActionLoading(true);
    setErrorMessage("");
    const { data, error } = await supabase.rpc("create_supervisor_center_invitation", {
      p_supervisor_id: currentSupervisor.id,
      p_expires_hours: 72,
      p_max_uses: centerInviteUses,
    });
    setActionLoading(false);
    if (error) {
      setErrorMessage(invitationError(error));
      return;
    }
    const invitation = data as { code: string; expires_at: string };
    setCenterInvite(invitation.code);
    setCenterInviteExpiry(invitation.expires_at);
  };

  const createMemberInvitation = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!supabase || !currentSupervisor || !canManage) return;
    setActionLoading(true);
    setErrorMessage("");
    const { data, error } = await supabase.rpc("create_supervisor_member_invitation", {
      p_supervisor_id: currentSupervisor.id,
      p_email: memberEmail.trim().toLowerCase(),
      p_role: memberRole,
      p_expires_hours: 72,
    });
    setActionLoading(false);
    if (error) {
      setErrorMessage(invitationError(error));
      return;
    }
    setMemberInvite((data as { code: string }).code);
  };

  const acceptTeamInvitation = async (event: React.FormEvent) => {
    event.preventDefault();
    setActionLoading(true);
    const success = await acceptSupervisorMemberInvitation(joinCode);
    setActionLoading(false);
    if (!success) {
      setErrorMessage("تعذر قبول الدعوة. يجب أن يطابق بريد الحساب البريد الذي حدده مدير الجهة.");
      return;
    }
    setJoinCode("");
    await fetchProfile();
  };

  const updateMember = async (member: SupervisorMember, status: "active" | "revoked", role = member.role) => {
    if (!supabase || !currentSupervisor || member.role === "owner" || role === "owner") return;
    setActionLoading(true);
    const { error } = await supabase.rpc("update_supervisor_member", {
      p_supervisor_id: currentSupervisor.id,
      p_user_id: member.user_id,
      p_role: role,
      p_status: status,
    });
    setActionLoading(false);
    if (error) {
      setErrorMessage(invitationError(error));
      return;
    }
    await fetchMembers();
  };

  const unlinkCenter = async (center: SupervisionCenter) => {
    if (!supabase || !canManage) return;
    const reason = window.prompt(`سبب فصل مركز «${center.name}» عن الجهة:`);
    if (reason === null) return;
    if (!window.confirm("سيُخفى المركز من تقارير الجهة فورًا. هل تريد المتابعة؟")) return;
    setActionLoading(true);
    const { error } = await supabase.rpc("unlink_center_from_supervisor", {
      p_center_id: center.id,
      p_reason: reason,
    });
    setActionLoading(false);
    if (error) {
      setErrorMessage(invitationError(error));
      return;
    }
    await fetchDashboard();
  };

  if (!user || (loading && !currentSupervisor)) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-[var(--background)]" dir="rtl">
        <Loader2 className="h-10 w-10 animate-spin text-teal-600" />
      </div>
    );
  }

  if (!currentSupervisor) {
    return (
      <main className="min-h-screen bg-[var(--background)] px-4 py-10 text-[var(--foreground)]" dir="rtl">
        <section className="mx-auto max-w-xl rounded-[2.5rem] border border-[var(--border)] bg-[var(--surface)] p-8 shadow-sm sm:p-12">
          <button onClick={() => router.push("/select-center")} className="mb-8 inline-flex items-center gap-2 text-sm font-bold text-gray-500">
            <ArrowRight className="h-5 w-5" /> العودة
          </button>
          <div className="flex h-16 w-16 items-center justify-center rounded-3xl bg-amber-50 text-amber-600 dark:bg-amber-900/20">
            <ShieldCheck className="h-8 w-8" />
          </div>
          <h1 className="mt-6 text-3xl font-black">قبول دعوة جهة إشرافية</h1>
          <p className="mt-3 leading-8 text-gray-500 dark:text-gray-400">ألصق الدعوة التي أرسلها مدير الجهة. الدعوة مرتبطة ببريد حسابك وتعمل مرة واحدة فقط.</p>
          {errorMessage && <p className="mt-5 rounded-2xl bg-rose-50 p-4 text-sm font-bold text-rose-700 dark:bg-rose-900/20 dark:text-rose-300">{errorMessage}</p>}
          <form onSubmit={acceptTeamInvitation} className="mt-8 space-y-4">
            <input
              value={joinCode}
              onChange={(event) => setJoinCode(event.target.value.toUpperCase())}
              placeholder="HAL-TEAM-..."
              className="w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-5 py-4 font-mono text-sm font-bold outline-none focus:border-amber-500"
            />
            <button disabled={actionLoading || !joinCode.trim()} className="w-full rounded-2xl bg-amber-500 px-5 py-4 font-black text-white disabled:opacity-50">
              {actionLoading ? "جارٍ التحقق..." : "قبول الدعوة"}
            </button>
          </form>
        </section>
      </main>
    );
  }

  const totals = dashboard?.totals;
  const statCards = [
    { label: "المراكز", value: totals?.centers_count ?? 0, icon: Building2, tone: "teal" },
    { label: "الحلقات", value: totals?.halaqat_count ?? 0, icon: BookOpen, tone: "sky" },
    { label: "الطلاب النشطون", value: totals?.active_students ?? 0, icon: Users, tone: "amber" },
    { label: "نسبة الحضور", value: `${totals?.attendance_rate ?? 0}%`, icon: ClipboardCheck, tone: "emerald" },
    { label: "آيات الحفظ", value: totals?.new_ayahs ?? 0, icon: TrendingUp, tone: "violet" },
    { label: "آيات المراجعة", value: totals?.review_ayahs ?? 0, icon: RefreshCw, tone: "rose" },
  ] as const;

  return (
    <main className="min-h-screen bg-[var(--background)] px-4 py-6 text-[var(--foreground)] sm:px-6 lg:px-10 print:bg-white print:p-0" dir="rtl">
      <style>{`@media print { .supervision-no-print { display: none !important; } .supervision-print-card { break-inside: avoid; box-shadow: none !important; } }`}</style>
      <div className="mx-auto max-w-7xl space-y-7">
        <header className="supervision-print-card overflow-hidden rounded-[2.25rem] bg-gradient-to-l from-[#175e52] to-[#238776] p-7 text-white shadow-xl sm:p-10">
          <div className="flex flex-col gap-7 lg:flex-row lg:items-center lg:justify-between">
            <div>
              <div className="mb-4 flex items-center gap-3 text-sm font-bold text-teal-100">
                <ShieldCheck className="h-5 w-5" /> لوحة الجهة الإشرافية
              </div>
              <h1 className="text-3xl font-black sm:text-4xl">{currentSupervisor.name}</h1>
              <p className="mt-3 text-sm font-medium text-teal-100">{roleLabels[currentSupervisor.role]} · تقرير عربي مجمّع من اليمين إلى اليسار</p>
            </div>
            <div className="supervision-no-print flex flex-wrap gap-3">
              <button onClick={() => window.print()} className="inline-flex items-center gap-2 rounded-2xl bg-white/15 px-5 py-3 text-sm font-black backdrop-blur hover:bg-white/25">
                <Printer className="h-5 w-5" /> طباعة / PDF
              </button>
              <button onClick={() => router.push("/select-center")} className="inline-flex items-center gap-2 rounded-2xl bg-white px-5 py-3 text-sm font-black text-teal-800">
                <ArrowRight className="h-5 w-5" /> المراكز
              </button>
            </div>
          </div>
        </header>

        <section className="supervision-no-print flex flex-col gap-4 rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 sm:flex-row sm:items-end">
          <label className="flex-1 text-xs font-black text-gray-500">
            من تاريخ
            <input type="date" value={startDate} max={endDate} onChange={(event) => setStartDate(event.target.value)} className="mt-2 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-sm font-bold" />
          </label>
          <label className="flex-1 text-xs font-black text-gray-500">
            إلى تاريخ
            <input type="date" value={endDate} min={startDate} onChange={(event) => setEndDate(event.target.value)} className="mt-2 w-full rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-sm font-bold" />
          </label>
          <button onClick={fetchDashboard} disabled={loading || endDate < startDate} className="inline-flex items-center justify-center gap-2 rounded-2xl bg-teal-600 px-6 py-3.5 text-sm font-black text-white disabled:opacity-50">
            {loading ? <Loader2 className="h-5 w-5 animate-spin" /> : <RefreshCw className="h-5 w-5" />} تحديث التقرير
          </button>
        </section>

        {errorMessage && (
          <div className="supervision-no-print rounded-2xl border border-rose-200 bg-rose-50 p-4 text-sm font-bold text-rose-700 dark:border-rose-800 dark:bg-rose-900/20 dark:text-rose-300">{errorMessage}</div>
        )}

        <section className="grid grid-cols-2 gap-3 lg:grid-cols-6">
          {statCards.map((card) => (
            <article key={card.label} className="supervision-print-card rounded-3xl border border-[var(--border)] bg-[var(--surface)] p-5 shadow-sm">
              <card.icon className="h-6 w-6 text-teal-600 dark:text-teal-300" />
              <p className="mt-5 text-2xl font-black">{card.value}</p>
              <p className="mt-1 text-xs font-bold text-gray-500">{card.label}</p>
            </article>
          ))}
        </section>

        {canManage && (
          <section className="supervision-no-print grid gap-5 lg:grid-cols-2">
            <article className="rounded-[2rem] border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8">
              <div className="flex items-start justify-between gap-4">
                <div>
                  <h2 className="flex items-center gap-2 text-xl font-black"><Link2 className="h-6 w-6 text-teal-600" /> دعوة مركز</h2>
                  <p className="mt-2 text-sm leading-7 text-gray-500">صالحة 72 ساعة، ولا نخزن نص الدعوة في القاعدة.</p>
                </div>
                <label className="text-xs font-bold text-gray-500">
                  الاستخدامات
                  <select value={centerInviteUses} onChange={(event) => setCenterInviteUses(Number(event.target.value))} className="mt-1 block rounded-xl border border-[var(--border)] bg-[var(--background)] px-3 py-2">
                    {[1, 2, 5, 10].map((count) => <option key={count} value={count}>{count}</option>)}
                  </select>
                </label>
              </div>
              <button onClick={createCenterInvitation} disabled={actionLoading} className="mt-5 w-full rounded-2xl bg-teal-600 px-5 py-3.5 text-sm font-black text-white disabled:opacity-50">إنشاء دعوة ربط</button>
              {centerInvite && (
                <div className="mt-4 rounded-2xl bg-teal-50 p-4 dark:bg-teal-900/20">
                  <div className="flex items-center gap-2">
                    <code className="min-w-0 flex-1 break-all text-xs font-black text-teal-800 dark:text-teal-200">{centerInvite}</code>
                    <button onClick={() => copyCode("center", centerInvite)} className="rounded-xl bg-white p-2 text-teal-700 dark:bg-gray-800">
                      {copied === "center" ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                    </button>
                  </div>
                  <p className="mt-2 text-[11px] font-bold text-teal-700 dark:text-teal-300">تنتهي: {new Date(centerInviteExpiry).toLocaleString("ar")}</p>
                </div>
              )}
            </article>

            <article className="rounded-[2rem] border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8">
              <h2 className="flex items-center gap-2 text-xl font-black"><UserPlus className="h-6 w-6 text-amber-600" /> دعوة عضو إشرافي</h2>
              <p className="mt-2 text-sm leading-7 text-gray-500">الدعوة مرتبطة بالبريد وتعمل مرة واحدة خلال 72 ساعة.</p>
              <form onSubmit={createMemberInvitation} className="mt-5 grid gap-3 sm:grid-cols-[1fr_auto_auto]">
                <input type="email" required value={memberEmail} onChange={(event) => setMemberEmail(event.target.value)} placeholder="member@example.com" className="min-w-0 rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-sm" />
                <select value={memberRole} onChange={(event) => setMemberRole(event.target.value as "admin" | "analyst")} className="rounded-2xl border border-[var(--border)] bg-[var(--background)] px-4 py-3 text-sm font-bold">
                  <option value="analyst">محلل</option>
                  <option value="admin">مدير</option>
                </select>
                <button disabled={actionLoading} className="rounded-2xl bg-amber-500 px-5 py-3 text-sm font-black text-white disabled:opacity-50">إنشاء</button>
              </form>
              {memberInvite && (
                <div className="mt-4 flex items-center gap-2 rounded-2xl bg-amber-50 p-4 dark:bg-amber-900/20">
                  <code className="min-w-0 flex-1 break-all text-xs font-black text-amber-800 dark:text-amber-200">{memberInvite}</code>
                  <button onClick={() => copyCode("member", memberInvite)} className="rounded-xl bg-white p-2 text-amber-700 dark:bg-gray-800">
                    {copied === "member" ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                  </button>
                </div>
              )}
            </article>
          </section>
        )}

        <section className="supervision-print-card overflow-hidden rounded-[2rem] border border-[var(--border)] bg-[var(--surface)]">
          <div className="flex items-center justify-between border-b border-[var(--border)] p-6 sm:p-8">
            <div>
              <h2 className="flex items-center gap-2 text-2xl font-black"><BarChart3 className="h-7 w-7 text-teal-600" /> أداء المراكز</h2>
              <p className="mt-2 text-sm text-gray-500">{startDate} — {endDate}</p>
            </div>
            <span className="rounded-full bg-teal-50 px-4 py-2 text-xs font-black text-teal-700 dark:bg-teal-900/20 dark:text-teal-300">{sortedCenters.length} مركز</span>
          </div>

          {sortedCenters.length === 0 ? (
            <div className="p-16 text-center text-sm font-bold text-gray-400">لا توجد مراكز مرتبطة بعد. أنشئ دعوة وأرسلها لمالك المركز.</div>
          ) : (
            <div className="grid gap-4 p-5 lg:grid-cols-2 sm:p-7">
              {sortedCenters.map((center, index) => (
                <article key={center.id} className="supervision-print-card rounded-3xl border border-[var(--border)] bg-[var(--background)] p-5 sm:p-6">
                  <div className="flex items-start justify-between gap-4">
                    <div className="flex min-w-0 items-center gap-4">
                      <span className="flex h-11 w-11 shrink-0 items-center justify-center rounded-2xl bg-teal-100 text-sm font-black text-teal-700 dark:bg-teal-900/30 dark:text-teal-200">{index + 1}</span>
                      <div className="min-w-0">
                        <h3 className="truncate text-lg font-black">{center.name}</h3>
                        <p className="mt-1 truncate text-xs text-gray-500">{center.address || "العنوان غير مسجل"}</p>
                      </div>
                    </div>
                    {canManage && (
                      <button onClick={() => unlinkCenter(center)} disabled={actionLoading} title="فصل المركز عن الجهة" className="supervision-no-print rounded-xl p-2 text-gray-400 hover:bg-rose-50 hover:text-rose-600 disabled:opacity-50">
                        <Unlink className="h-5 w-5" />
                      </button>
                    )}
                  </div>
                  <div className="mt-6 grid grid-cols-3 gap-3 text-center">
                    <div className="rounded-2xl bg-[var(--surface)] p-3"><p className="text-lg font-black">{center.halaqat_count}</p><p className="text-[10px] font-bold text-gray-500">حلقة</p></div>
                    <div className="rounded-2xl bg-[var(--surface)] p-3"><p className="text-lg font-black">{center.active_students}</p><p className="text-[10px] font-bold text-gray-500">طالب</p></div>
                    <div className="rounded-2xl bg-[var(--surface)] p-3"><p className="text-lg font-black text-teal-600">{center.attendance_rate}%</p><p className="text-[10px] font-bold text-gray-500">حضور</p></div>
                  </div>
                  <div className="mt-4 grid grid-cols-2 gap-3 text-xs font-bold text-gray-600 dark:text-gray-300">
                    <p className="rounded-xl bg-emerald-50 p-3 dark:bg-emerald-900/20">الحفظ: {center.new_ayahs} آية</p>
                    <p className="rounded-xl bg-sky-50 p-3 dark:bg-sky-900/20">المراجعة: {center.review_ayahs} آية</p>
                    <p className="rounded-xl bg-rose-50 p-3 dark:bg-rose-900/20">الغياب: {center.absent_records}</p>
                    <p className="rounded-xl bg-amber-50 p-3 dark:bg-amber-900/20">النقاط: +{center.positive_points} / -{center.negative_points}</p>
                  </div>
                </article>
              ))}
            </div>
          )}
        </section>

        {canManage && (
          <section className="supervision-no-print rounded-[2rem] border border-[var(--border)] bg-[var(--surface)] p-6 sm:p-8">
            <div className="flex items-center justify-between gap-4">
              <div>
                <h2 className="text-2xl font-black">فريق الإشراف</h2>
                <p className="mt-2 text-sm text-gray-500">المدير يستطيع الإدارة، والمحلل يرى التقرير التجميعي فقط.</p>
              </div>
              <span className="rounded-full bg-gray-100 px-4 py-2 text-xs font-black text-gray-600 dark:bg-gray-800 dark:text-gray-300">{members.length} عضو</span>
            </div>
            <div className="mt-6 grid gap-3">
              {members.map((member) => (
                <article key={member.user_id} className="flex flex-col gap-4 rounded-2xl border border-[var(--border)] bg-[var(--background)] p-5 sm:flex-row sm:items-center sm:justify-between">
                  <div className="min-w-0">
                    <p className="truncate font-black">{member.full_name}</p>
                    <p className="mt-1 truncate text-xs text-gray-500">{member.email || "البريد غير ظاهر"} · {roleLabels[member.role]}</p>
                  </div>
                  {member.role === "owner" ? (
                    <span className="rounded-full bg-amber-50 px-4 py-2 text-xs font-black text-amber-700 dark:bg-amber-900/20 dark:text-amber-300">المالك</span>
                  ) : (
                    <div className="flex flex-wrap gap-2">
                      <select
                        value={member.role}
                        disabled={actionLoading || member.status === "revoked"}
                        onChange={(event) => updateMember(member, member.status, event.target.value as "admin" | "analyst")}
                        className="rounded-xl border border-[var(--border)] bg-[var(--surface)] px-3 py-2 text-xs font-bold"
                      >
                        <option value="admin">مدير</option>
                        <option value="analyst">محلل</option>
                      </select>
                      <button
                        disabled={actionLoading}
                        onClick={() => updateMember(member, member.status === "active" ? "revoked" : "active")}
                        className={`rounded-xl px-4 py-2 text-xs font-black ${member.status === "active" ? "bg-rose-50 text-rose-700 dark:bg-rose-900/20" : "bg-emerald-50 text-emerald-700 dark:bg-emerald-900/20"}`}
                      >
                        {member.status === "active" ? "إيقاف" : "إعادة تفعيل"}
                      </button>
                    </div>
                  )}
                </article>
              ))}
            </div>
          </section>
        )}
      </div>
    </main>
  );
}
