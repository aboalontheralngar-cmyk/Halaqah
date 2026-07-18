"use client";

import { FormEvent, useCallback, useEffect, useMemo, useState } from "react";
import {
  BookOpen,
  CalendarCheck,
  Clock3,
  Eye,
  EyeOff,
  FileDown,
  GraduationCap,
  Loader2,
  LogOut,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Star,
} from "lucide-react";
import {
  FamilyPortalDashboard,
  StudentPortalDashboard,
  StudentPortalError,
  loadFamilyPortalDashboard,
  loadStudentPortalDashboard,
  loginToFamilyPortal,
  loginToStudentPortal,
  logoutFamilyPortal,
  logoutStudentPortal,
} from "@/lib/studentPortal";

const SESSION_KEY = "halaqah_student_portal_session";
type PortalKind = "student" | "family";

function parseStoredSession(value: string | null): { kind: PortalKind; token: string } | null {
  if (!value) return null;
  try {
    const parsed = JSON.parse(value) as { kind?: unknown; token?: unknown };
    if (
      (parsed.kind === "student" || parsed.kind === "family") &&
      typeof parsed.token === "string"
    ) {
      return { kind: parsed.kind, token: parsed.token };
    }
  } catch {
    // P7.2 stored the student token directly. Keep those sessions working.
  }
  return /^[a-f0-9]{64}$/i.test(value) ? { kind: "student", token: value } : null;
}

function saveStoredSession(kind: PortalKind, token: string) {
  sessionStorage.setItem(SESSION_KEY, JSON.stringify({ kind, token }));
}

const unitLabel = (unit: string) => ({
  ayahs: "آيات",
  pages: "صفحات",
  lines: "أسطر",
}[unit] || unit);

const attendanceLabel = (status: string) => ({
  present: "حاضر",
  late: "متأخر",
  absent: "غائب",
  excused: "مستأذن",
}[status] || status);

const attendanceStyle = (status: string) => ({
  present: "bg-emerald-50 text-emerald-700 border-emerald-100",
  late: "bg-amber-50 text-amber-700 border-amber-100",
  absent: "bg-rose-50 text-rose-700 border-rose-100",
  excused: "bg-sky-50 text-sky-700 border-sky-100",
}[status] || "bg-gray-50 text-gray-700 border-gray-100");

function formatStudentCode(code: string): string {
  const normalized = code.replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 20);
  return `HAL-${normalized.match(/.{1,5}/g)?.join("-") || normalized}`;
}

function formatFamilyCode(code: string): string {
  const normalized = code.replace(/[^A-Za-z0-9]/g, "").toUpperCase().slice(0, 20);
  return `FAM-${normalized.match(/.{1,5}/g)?.join("-") || normalized}`;
}

function formatDate(value: string): string {
  const date = new Date(`${value.slice(0, 10)}T12:00:00`);
  if (Number.isNaN(date.getTime())) return value;
  const hijri = new Intl.DateTimeFormat("ar-SA-u-ca-islamic", {
    day: "numeric",
    month: "long",
    year: "numeric",
  }).format(date);
  const gregorian = new Intl.DateTimeFormat("ar", {
    day: "numeric",
    month: "short",
    year: "numeric",
  }).format(date);
  return `${hijri} · ${gregorian}`;
}

function errorMessage(error: unknown): string {
  const code = error instanceof StudentPortalError ? error.code : "portal_unavailable";
  if (code === "invalid_credentials") return "كود الدخول أو الرقم السري غير صحيح.";
  if (code === "rate_limited") return "تكررت المحاولات. انتظر 15 دقيقة ثم حاول مجددًا.";
  if (code === "invalid_session") return "انتهت الجلسة. سجل الدخول مرة أخرى.";
  if (code === "portal_not_configured") return "البوابة لم تُفعّل على الخادم بعد.";
  return "تعذر الاتصال بالبوابة الآن. حاول لاحقًا.";
}

export default function StudentPortalPage() {
  const [loginMode, setLoginMode] = useState<PortalKind>("student");
  const [accessCode, setAccessCode] = useState("");
  const [pin, setPin] = useState("");
  const [showPin, setShowPin] = useState(false);
  const [sessionToken, setSessionToken] = useState<string | null>(null);
  const [sessionKind, setSessionKind] = useState<PortalKind>("student");
  const [dashboard, setDashboard] = useState<StudentPortalDashboard | null>(null);
  const [familyDashboard, setFamilyDashboard] = useState<FamilyPortalDashboard | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [periodDays, setPeriodDays] = useState(30);

  const loadDashboard = useCallback(async (
    token: string,
    kind: PortalKind,
    days: number,
    studentId?: string,
  ) => {
    setLoading(true);
    setMessage(null);
    try {
      if (kind === "family") {
        const data = await loadFamilyPortalDashboard(token, days, studentId);
        setFamilyDashboard(data);
        setDashboard(data.student_dashboard);
      } else {
        const data = await loadStudentPortalDashboard(token, days);
        setFamilyDashboard(null);
        setDashboard(data);
      }
      setSessionToken(token);
      setSessionKind(kind);
    } catch (error) {
      sessionStorage.removeItem(SESSION_KEY);
      setDashboard(null);
      setFamilyDashboard(null);
      setSessionToken(null);
      setMessage(errorMessage(error));
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    const stored = parseStoredSession(sessionStorage.getItem(SESSION_KEY));
    const timer = window.setTimeout(() => {
      if (stored) void loadDashboard(stored.token, stored.kind, 30);
      else setLoading(false);
    }, 0);
    return () => window.clearTimeout(timer);
  }, [loadDashboard]);

  const handleLogin = async (event: FormEvent) => {
    event.preventDefault();
    setSubmitting(true);
    setMessage(null);
    try {
      const result = loginMode === "family"
        ? await loginToFamilyPortal(accessCode, pin)
        : await loginToStudentPortal(accessCode, pin);
      saveStoredSession(loginMode, result.sessionToken);
      setPin("");
      await loadDashboard(result.sessionToken, loginMode, periodDays);
    } catch (error) {
      setMessage(errorMessage(error));
    } finally {
      setSubmitting(false);
    }
  };

  const handleLogout = async () => {
    const token = sessionToken;
    sessionStorage.removeItem(SESSION_KEY);
    setDashboard(null);
    setFamilyDashboard(null);
    setSessionToken(null);
    if (token) {
      const logout = sessionKind === "family" ? logoutFamilyPortal : logoutStudentPortal;
      await logout(token).catch(() => undefined);
    }
  };

  const handlePeriodChange = (days: number) => {
    setPeriodDays(days);
    if (sessionToken) {
      void loadDashboard(
        sessionToken,
        sessionKind,
        days,
        familyDashboard?.selected_student_id,
      );
    }
  };

  const handleStudentChange = (studentId: string) => {
    if (sessionToken && sessionKind === "family") {
      void loadDashboard(sessionToken, "family", periodDays, studentId);
    }
  };

  const attendanceTotal = useMemo(() => {
    if (!dashboard) return 0;
    return Object.values(dashboard.summary.attendance).reduce((total, count) => total + Number(count), 0);
  }, [dashboard]);

  if (loading) {
    return (
      <main className="min-h-screen bg-[#f7f4ed] flex items-center justify-center" dir="rtl">
        <Loader2 className="w-10 h-10 text-[#1f6b5d] animate-spin" />
      </main>
    );
  }

  if (!dashboard) {
    return (
      <main className="min-h-screen bg-[#f7f4ed] px-4 py-10 sm:py-16" dir="rtl">
        <div className="mx-auto max-w-md">
          <div className="text-center mb-8">
            <div className="w-16 h-16 mx-auto rounded-3xl bg-[#1f6b5d] text-white grid place-items-center shadow-lg shadow-emerald-900/10">
              <BookOpen className="w-8 h-8" />
            </div>
            <h1 className="mt-5 text-3xl font-extrabold text-[#173e36]">بوابة الطالب وولي الأمر</h1>
            <p className="mt-2 text-sm text-gray-500 leading-7">تابع الخطة والحضور والحفظ والمراجعة في مساحة خاصة وآمنة.</p>
          </div>

          <form onSubmit={handleLogin} className="bg-white rounded-[2rem] border border-[#e3ded2] p-6 sm:p-8 shadow-sm space-y-5">
            <div className="grid grid-cols-2 rounded-2xl bg-[#f1eee6] p-1" role="tablist" aria-label="نوع الدخول">
              <button
                type="button"
                role="tab"
                aria-selected={loginMode === "student"}
                onClick={() => {
                  setLoginMode("student");
                  setAccessCode("");
                  setMessage(null);
                }}
                className={`rounded-xl px-3 py-3 text-sm font-extrabold transition ${
                  loginMode === "student" ? "bg-white text-[#1f6b5d] shadow-sm" : "text-gray-500"
                }`}
              >
                دخول الطالب
              </button>
              <button
                type="button"
                role="tab"
                aria-selected={loginMode === "family"}
                onClick={() => {
                  setLoginMode("family");
                  setAccessCode("");
                  setMessage(null);
                }}
                className={`rounded-xl px-3 py-3 text-sm font-extrabold transition ${
                  loginMode === "family" ? "bg-white text-[#1f6b5d] shadow-sm" : "text-gray-500"
                }`}
              >
                دخول ولي الأمر
              </button>
            </div>
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2">
                {loginMode === "family" ? "كود العائلة" : "كود الطالب"}
              </label>
              <input
                value={accessCode}
                onChange={(event) => setAccessCode(event.target.value.toUpperCase())}
                placeholder={loginMode === "family" ? "FAM-XXXXX-XXXXX-XXXXX-XXXXX" : "HAL-XXXXX-XXXXX-XXXXX-XXXXX"}
                autoComplete="username"
                required
                className="w-full rounded-2xl border border-[#ded8cb] bg-[#fbfaf6] px-4 py-4 text-left font-bold tracking-wide outline-none focus:ring-2 focus:ring-[#1f6b5d]/20"
                dir="ltr"
              />
            </div>
            <div>
              <label className="block text-sm font-bold text-gray-700 mb-2">الرقم السري المكون من 6 أرقام</label>
              <div className="relative">
                <input
                  value={pin}
                  onChange={(event) => setPin(event.target.value.replace(/\D/g, "").slice(0, 6))}
                  type={showPin ? "text" : "password"}
                  inputMode="numeric"
                  autoComplete="current-password"
                  pattern="[0-9]{6}"
                  required
                  className="w-full rounded-2xl border border-[#ded8cb] bg-[#fbfaf6] px-14 py-4 text-center text-xl font-extrabold tracking-[0.35em] outline-none focus:ring-2 focus:ring-[#1f6b5d]/20"
                  dir="ltr"
                />
                <button type="button" onClick={() => setShowPin((value) => !value)} aria-label="إظهار الرقم السري" className="absolute left-4 top-1/2 -translate-y-1/2 text-gray-400">
                  {showPin ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                </button>
              </div>
            </div>
            {message && <p role="alert" className="rounded-2xl bg-rose-50 border border-rose-100 px-4 py-3 text-sm font-bold text-rose-700">{message}</p>}
            <button disabled={submitting} className="w-full rounded-2xl bg-[#1f6b5d] text-white py-4 font-extrabold flex items-center justify-center gap-2 disabled:opacity-60">
              {submitting ? <Loader2 className="w-5 h-5 animate-spin" /> : <ShieldCheck className="w-5 h-5" />}
              دخول آمن
            </button>
            <p className="text-xs text-center text-gray-400 leading-6">
              {loginMode === "family"
                ? "حساب العائلة يعرض الأبناء النشطين المرتبطين بها فقط. لا تشارك الرقم السري."
                : "لا تشارك الرقم السري. رمز QR مخصص للتعريف والحضور وليس كلمة مرور."}
            </p>
          </form>
        </div>
      </main>
    );
  }

  return (
    <main className="portal-print min-h-screen bg-[#f7f4ed] text-[#173e36]" dir="rtl">
      <header className="bg-[#174f45] text-white print:bg-white print:text-[#173e36]">
        <div className="max-w-6xl mx-auto px-4 sm:px-6 py-6 flex flex-wrap items-center justify-between gap-4">
          <div>
            <p className="text-emerald-100 print:text-gray-500 text-sm">{dashboard.organization.center_name} · {dashboard.organization.halaqa_name}</p>
            <h1 className="text-2xl sm:text-3xl font-extrabold mt-1">مرحبًا، {dashboard.student.name}</h1>
            <div className="mt-2 flex flex-wrap items-center gap-x-3 gap-y-1 text-xs font-bold text-emerald-100 print:text-gray-600">
              <span dir="ltr">{formatStudentCode(dashboard.student.student_code)}</span>
              {familyDashboard && (
                <span dir="ltr">{formatFamilyCode(familyDashboard.family.family_code)}</span>
              )}
            </div>
          </div>
          <div className="print:hidden flex flex-wrap items-center gap-2">
            {familyDashboard && familyDashboard.students.length > 1 && (
              <select
                value={familyDashboard.selected_student_id}
                onChange={(event) => handleStudentChange(event.target.value)}
                aria-label="اختيار الابن"
                className="rounded-xl bg-white/10 px-3 py-3 font-bold outline-none"
              >
                {familyDashboard.students.map((student) => (
                  <option className="text-gray-900" key={student.id} value={student.id}>
                    {student.name}
                  </option>
                ))}
              </select>
            )}
            <select value={periodDays} onChange={(event) => handlePeriodChange(Number(event.target.value))} className="rounded-xl bg-white/10 px-3 py-3 font-bold outline-none">
              <option className="text-gray-900" value={7}>7 أيام</option>
              <option className="text-gray-900" value={30}>30 يومًا</option>
              <option className="text-gray-900" value={90}>3 أشهر</option>
              <option className="text-gray-900" value={180}>6 أشهر</option>
              <option className="text-gray-900" value={366}>سنة</option>
            </select>
            <button
              onClick={() => sessionToken && loadDashboard(
                sessionToken,
                sessionKind,
                periodDays,
                familyDashboard?.selected_student_id,
              )}
              className="p-3 rounded-xl bg-white/10"
              aria-label="تحديث"
            ><RefreshCw className="w-5 h-5" /></button>
            <button onClick={() => window.print()} className="px-4 py-3 rounded-xl bg-white/10 flex items-center gap-2 font-bold"><FileDown className="w-5 h-5" /> حفظ PDF</button>
            <button onClick={handleLogout} className="p-3 rounded-xl bg-rose-500/20 text-rose-50" aria-label="تسجيل الخروج"><LogOut className="w-5 h-5" /></button>
          </div>
        </div>
      </header>

      <div className="max-w-6xl mx-auto px-4 sm:px-6 py-7 space-y-7">
        {familyDashboard && (
          <section className="print:hidden rounded-3xl border border-[#d9d2c4] bg-[#fffdf8] p-4 sm:p-5 flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="font-extrabold text-[#173e36]">{familyDashboard.family.name}</p>
              <p className="mt-1 text-xs text-gray-500">
                حساب ولي الأمر · {familyDashboard.students.length} من الأبناء النشطين
                {familyDashboard.family.primary_guardian_name
                  ? ` · جهة التواصل: ${familyDashboard.family.primary_guardian_name}`
                  : ""}
              </p>
            </div>
            <p className="text-xs font-bold text-[#1f6b5d]">يمكنك التبديل بين الأبناء من أعلى الصفحة.</p>
          </section>
        )}
        <section className="grid grid-cols-2 lg:grid-cols-4 gap-3">
          <SummaryCard icon={BookOpen} label="مقرر الحفظ" value={`${dashboard.student.plan_amount} ${unitLabel(dashboard.student.plan_type)}`} />
          <SummaryCard icon={RefreshCw} label="مقرر المراجعة" value={`${dashboard.student.review_plan_amount} ${unitLabel(dashboard.student.plan_type)}`} />
          <SummaryCard icon={Star} label="رصيد النقاط" value={`${dashboard.summary.points_balance}`} />
          <SummaryCard icon={CalendarCheck} label="أيام الرصد" value={`${attendanceTotal} يومًا`} />
        </section>

        <section className="grid lg:grid-cols-3 gap-5">
          <article className="lg:col-span-2 bg-white rounded-3xl border border-[#e3ded2] p-5 sm:p-6">
            <div className="flex items-center gap-3 mb-5"><GraduationCap className="w-6 h-6 text-[#1f6b5d]" /><h2 className="text-xl font-extrabold">الخطة الحالية</h2></div>
            {dashboard.active_plan ? (
              <div className="grid sm:grid-cols-2 gap-4">
                <PlanLine label="الفترة" value={`${formatDate(dashboard.active_plan.start_date)} — ${formatDate(dashboard.active_plan.end_date)}`} />
                <PlanLine label="النوع" value={dashboard.active_plan.period === "weekly" ? "خطة أسبوعية" : "خطة شهرية"} />
                <PlanLine label="الحفظ اليومي" value={`${dashboard.active_plan.new_amount} ${unitLabel(dashboard.active_plan.unit)}`} />
                <PlanLine label="المراجعة اليومية" value={`${dashboard.active_plan.review_amount} ${unitLabel(dashboard.active_plan.unit)}`} />
                {dashboard.active_plan.notes && <div className="sm:col-span-2"><PlanLine label="ملاحظة المعلم" value={dashboard.active_plan.notes} /></div>}
              </div>
            ) : (
              <p className="rounded-2xl bg-[#fbfaf6] p-5 text-gray-500">لا توجد خطة نشطة منشورة حاليًا.</p>
            )}
          </article>

          <article className="bg-white rounded-3xl border border-[#e3ded2] p-5 sm:p-6">
            <div className="flex items-center gap-3 mb-5"><CalendarCheck className="w-6 h-6 text-[#1f6b5d]" /><h2 className="text-xl font-extrabold">آخر {dashboard.period_days} يومًا</h2></div>
            <div className="grid grid-cols-2 gap-3 text-center">
              {Object.entries(dashboard.summary.attendance).map(([status, count]) => (
                <div key={status} className={`rounded-2xl border p-3 ${attendanceStyle(status)}`}>
                  <div className="text-2xl font-extrabold">{count}</div><div className="text-xs font-bold mt-1">{attendanceLabel(status)}</div>
                </div>
              ))}
            </div>
          </article>
        </section>

        <section className="grid lg:grid-cols-2 gap-5">
          <article className="bg-white rounded-3xl border border-[#e3ded2] p-5 sm:p-6 break-inside-avoid">
            <div className="flex items-center gap-3 mb-5"><Sparkles className="w-6 h-6 text-[#1f6b5d]" /><h2 className="text-xl font-extrabold">آخر الحفظ والمراجعة</h2></div>
            <div className="space-y-3">
              {dashboard.recent_memorization.length === 0 && <p className="text-gray-500">لا يوجد تسميع منشور.</p>}
              {dashboard.recent_memorization.map((entry, index) => (
                <div key={`${entry.date}-${entry.surah}-${index}`} className="rounded-2xl bg-[#fbfaf6] border border-[#eee9df] p-4 flex items-start justify-between gap-4">
                  <div><p className="font-extrabold">{entry.session_type === "review" ? "مراجعة" : "حفظ"} سورة {entry.surah}</p><p className="text-sm text-gray-500 mt-1">من الآية {entry.from_ayah} إلى {entry.to_ayah}</p></div>
                  <div className="text-left shrink-0"><p className="text-xs text-gray-500">{formatDate(entry.date)}</p>{entry.degree && <p className="text-xs font-bold text-[#1f6b5d] mt-2">التقييم {entry.degree}/5</p>}</div>
                </div>
              ))}
            </div>
          </article>

          <article className="bg-white rounded-3xl border border-[#e3ded2] p-5 sm:p-6 break-inside-avoid">
            <div className="flex items-center gap-3 mb-5"><Clock3 className="w-6 h-6 text-[#1f6b5d]" /><h2 className="text-xl font-extrabold">سجل الحضور الأخير</h2></div>
            <div className="space-y-3">
              {dashboard.recent_attendance.length === 0 && <p className="text-gray-500">لا يوجد حضور منشور.</p>}
              {dashboard.recent_attendance.map((entry) => (
                <div key={entry.date} className="rounded-2xl bg-[#fbfaf6] border border-[#eee9df] p-4 flex items-center justify-between gap-4">
                  <div><p className="font-bold">{formatDate(entry.date)}</p>{entry.notes && <p className="text-xs text-gray-500 mt-1">{entry.notes}</p>}</div>
                  <span className={`rounded-full border px-3 py-1 text-xs font-extrabold ${attendanceStyle(entry.status)}`}>{attendanceLabel(entry.status)}</span>
                </div>
              ))}
            </div>
          </article>
        </section>

        <footer className="text-center text-xs text-gray-500 pb-8">من أجل الحرص على ابنكم ومتابعة تقدمه، ننتظر ملاحظاتكم وتعاونكم.</footer>
      </div>
    </main>
  );
}

function SummaryCard({ icon: Icon, label, value }: { icon: typeof BookOpen; label: string; value: string }) {
  return <div className="bg-white rounded-3xl border border-[#e3ded2] p-4 sm:p-5"><Icon className="w-5 h-5 text-[#1f6b5d]" /><p className="text-xs text-gray-500 mt-3">{label}</p><p className="font-extrabold mt-1 text-base sm:text-lg">{value}</p></div>;
}

function PlanLine({ label, value }: { label: string; value: string }) {
  return <div className="rounded-2xl bg-[#fbfaf6] border border-[#eee9df] p-4"><p className="text-xs text-gray-500">{label}</p><p className="font-bold mt-1 leading-7">{value}</p></div>;
}
