"use client";

import { useState, useMemo } from "react";
import { useShallow } from "zustand/react/shallow";
import { Palmtree, Plus, Trash2, CheckCircle, Clock, X, CalendarRange, Pencil, Search, SlidersHorizontal } from "lucide-react";
import { useStore, type Vacation } from "@/store/useStore";
import { supabase } from "@/lib/supabase";
import { getHijriDate, localDateKey } from "@/utils/dateUtils";

export default function VacationsPage() {
  const {
    students,
    vacations,
    addVacation,
    deleteVacation,
    fetchVacations,
    fetchAttendance
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      vacations: state.vacations,
      addVacation: state.addVacation,
      deleteVacation: state.deleteVacation,
      fetchVacations: state.fetchVacations,
      fetchAttendance: state.fetchAttendance,
    })),
  );
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({ studentId: "", startDate: "", endDate: "", reason: "" });
  const [periodFilter, setPeriodFilter] = useState<"all" | "week" | "month" | "custom">("all");
  const [statusFilter, setStatusFilter] = useState<"all" | "active" | "upcoming" | "expired" | "pending" | "approved">("all");
  const [studentFilter, setStudentFilter] = useState("");
  const [reasonFilter, setReasonFilter] = useState("");
  const [customFrom, setCustomFrom] = useState("");
  const [customTo, setCustomTo] = useState("");

  const today = localDateKey();

  const sortedStudents = useMemo(
    () => [...students].sort((left, right) =>
      left.name.localeCompare(right.name, "ar", { sensitivity: "base" }),
    ),
    [students],
  );

  const filteredVacations = useMemo(() => {
    const dateToInput = (date: Date) => {
      const year = date.getFullYear();
      const month = String(date.getMonth() + 1).padStart(2, "0");
      const day = String(date.getDate()).padStart(2, "0");
      return `${year}-${month}-${day}`;
    };
    const now = new Date();
    const saturdayOffset = (now.getDay() + 1) % 7;
    const weekStartDate = new Date(now);
    weekStartDate.setDate(now.getDate() - saturdayOffset);
    const weekEndDate = new Date(weekStartDate);
    weekEndDate.setDate(weekStartDate.getDate() + 6);
    const monthStart = `${today.slice(0, 7)}-01`;
    const monthEndDate = new Date(now.getFullYear(), now.getMonth() + 1, 0);

    let rangeStart = "";
    let rangeEnd = "";
    if (periodFilter === "week") {
      rangeStart = dateToInput(weekStartDate);
      rangeEnd = dateToInput(weekEndDate);
    } else if (periodFilter === "month") {
      rangeStart = monthStart;
      rangeEnd = dateToInput(monthEndDate);
    } else if (periodFilter === "custom") {
      rangeStart = customFrom;
      rangeEnd = customTo;
    }

    const normalizedReason = reasonFilter.trim().toLocaleLowerCase("ar");
    return [...vacations]
      .filter(vacation => !studentFilter || vacation.studentId === studentFilter)
      .filter(vacation =>
        !normalizedReason || vacation.reason.toLocaleLowerCase("ar").includes(normalizedReason),
      )
      .filter(vacation => {
        if (statusFilter === "active") return vacation.approved && vacation.startDate <= today && vacation.endDate >= today;
        if (statusFilter === "upcoming") return vacation.approved && vacation.startDate > today;
        if (statusFilter === "expired") return vacation.endDate < today;
        if (statusFilter === "pending") return !vacation.approved;
        if (statusFilter === "approved") return vacation.approved;
        return true;
      })
      .filter(vacation => {
        if (!rangeStart && !rangeEnd) return true;
        if (rangeStart && vacation.endDate < rangeStart) return false;
        if (rangeEnd && vacation.startDate > rangeEnd) return false;
        return true;
      })
      .sort((left, right) => right.startDate.localeCompare(left.startDate));
  }, [customFrom, customTo, periodFilter, reasonFilter, statusFilter, studentFilter, today, vacations]);

  const stats = useMemo(() => {
    const active = vacations.filter((v) => today >= v.startDate && today <= v.endDate);
    const pending = vacations.filter((v) => !v.approved);
    return { total: vacations.length, active: active.length, pending: pending.length };
  }, [vacations, today]);

  const studentName = (id: string) => students.find((s) => s.id === id)?.name || "غير معروف";

  const handleSubmit = async () => {
    if (!form.studentId || !form.startDate || !form.endDate) return;
    if (form.endDate < form.startDate) {
      alert("تاريخ النهاية يجب أن يكون بعد تاريخ البداية");
      return;
    }
    
    if (editingId) {
      if (supabase) {
        await supabase
          .from("vacations")
          .update({
            student_id: form.studentId,
            start_date: form.startDate,
            end_date: form.endDate,
            reason: form.reason
          })
          .eq("id", editingId);
      }
      await fetchVacations();
    } else {
      await addVacation({ ...form, approved: true });
    }

    // Auto-update attendance records (Component 7)
    if (supabase) {
      const { data: absentRecords } = await supabase
        .from("attendance")
        .select("id")
        .eq("student_id", form.studentId)
        .gte("date", form.startDate)
        .lte("date", form.endDate)
        .eq("status", "absent");

      if (absentRecords && absentRecords.length > 0) {
        const ids = absentRecords.map(r => r.id);
        await supabase
          .from("attendance")
          .update({ status: "excused", notes: "تحديث تلقائي لتسجيل إجازة للطالب" })
          .in("id", ids);
        await fetchAttendance();
      }
    }
    
    setShowModal(false);
    setEditingId(null);
    setForm({ studentId: "", startDate: "", endDate: "", reason: "" });
  };

  const handleEdit = (vacation: Vacation) => {
    setEditingId(vacation.id);
    setForm({
      studentId: vacation.studentId,
      startDate: vacation.startDate,
      endDate: vacation.endDate,
      reason: vacation.reason || ""
    });
    setShowModal(true);
  };

  const toggleApproval = async (id: string, approved: boolean) => {
    if (supabase) {
      const nextApprovedState = !approved;
      await supabase.from("vacations").update({ approved: nextApprovedState }).eq("id", id);
      
      // Update daily records accordingly
      const { data: vac } = await supabase
        .from("vacations")
        .select("student_id, start_date, end_date, reason")
        .eq("id", id)
        .single();
        
      if (vac) {
        if (nextApprovedState) {
          // Approved: change absent to excused
          const { data: absentRecords } = await supabase
            .from("attendance")
            .select("id")
            .eq("student_id", vac.student_id)
            .gte("date", vac.start_date)
            .lte("date", vac.end_date)
            .eq("status", "absent");

          if (absentRecords && absentRecords.length > 0) {
            const ids = absentRecords.map(r => r.id);
            await supabase
              .from("attendance")
              .update({ status: "excused", notes: `تحول تلقائيًا بعد اعتماد الإجازة: ${vac.reason || 'ظرف شخصي'}` })
              .in("id", ids);
          }
        } else {
          // Unapproved: change excused back to absent
          const { data: excusedRecords } = await supabase
            .from("attendance")
            .select("id, notes")
            .eq("student_id", vac.student_id)
            .gte("date", vac.start_date)
            .lte("date", vac.end_date)
            .eq("status", "excused");

          if (excusedRecords && excusedRecords.length > 0) {
            const idsToRevert = excusedRecords
              .filter(r => r.notes?.includes("إجازة") || r.notes?.includes("vacation") || r.notes?.includes("تلقائي"))
              .map(r => r.id);
            
            if (idsToRevert.length > 0) {
              await supabase
                .from("attendance")
                .update({ status: "absent", notes: "تم إلغاء اعتماد الإجازة" })
                .in("id", idsToRevert);
            }
          }
        }
        await fetchAttendance();
      }
    }
    await fetchVacations();
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-[var(--foreground)] tracking-tight">إدارة الإجازات</h1>
          <p className="text-[var(--muted)] mt-2 font-medium">
            تسجيل إجازات الطلاب واعتمادها — تظهر تلقائياً في سجل الحضور.
          </p>
        </div>
        <button
          onClick={() => setShowModal(true)}
          className="px-8 py-4 bg-teal-600 text-white rounded-2xl text-sm font-black shadow-lg flex items-center gap-2 hover:bg-teal-700 transition-all self-start"
        >
          <Plus className="w-5 h-5" /> تسجيل إجازة
        </button>
      </div>

      {/* Stats */}
      <div className="grid grid-cols-3 gap-4 lg:gap-6">
        {[
          { label: "إجمالي الإجازات", value: stats.total, icon: CalendarRange, color: "text-teal-600", bg: "bg-teal-50 dark:bg-teal-900/20" },
          { label: "في إجازة الآن", value: stats.active, icon: Palmtree, color: "text-blue-600", bg: "bg-blue-50 dark:bg-blue-900/20" },
          { label: "بانتظار الاعتماد", value: stats.pending, icon: Clock, color: "text-amber-600", bg: "bg-amber-50 dark:bg-amber-900/20" },
        ].map((item, i) => (
          <div key={i} className="bg-[var(--surface)] rounded-[2rem] border border-[var(--border)] p-6 flex flex-col items-center text-center shadow-sm">
            <div className={`w-10 h-10 ${item.bg} rounded-2xl flex items-center justify-center mb-3`}>
              <item.icon className={`w-5 h-5 ${item.color}`} />
            </div>
            <p className="text-2xl font-black text-[var(--foreground)]">{item.value}</p>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{item.label}</p>
          </div>
        ))}
      </div>

      <div className="rounded-[2rem] border border-gray-100 bg-white p-5 shadow-sm dark:border-gray-800 dark:bg-gray-900">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <SlidersHorizontal className="h-5 w-5 text-teal-600" />
            <div>
              <h2 className="text-sm font-black text-[var(--foreground)]">تنظيم سجل الإجازات</h2>
              <p className="text-[11px] font-bold text-gray-400">{filteredVacations.length} نتيجة مطابقة</p>
            </div>
          </div>
          <button
            type="button"
            onClick={() => {
              setPeriodFilter("all");
              setStatusFilter("all");
              setStudentFilter("");
              setReasonFilter("");
              setCustomFrom("");
              setCustomTo("");
            }}
            className="rounded-xl bg-gray-100 px-4 py-2 text-xs font-black text-gray-600 dark:bg-gray-800 dark:text-gray-300"
          >
            مسح الفلاتر
          </button>
        </div>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-4">
          <select value={periodFilter} onChange={event => setPeriodFilter(event.target.value as typeof periodFilter)} className="rounded-2xl bg-gray-50 px-4 py-3 text-xs font-black outline-none dark:bg-gray-800">
            <option value="all">كل الفترات</option>
            <option value="week">الأسبوع الحالي (السبت–الجمعة)</option>
            <option value="month">الشهر الحالي</option>
            <option value="custom">فترة مخصصة</option>
          </select>
          <select value={statusFilter} onChange={event => setStatusFilter(event.target.value as typeof statusFilter)} className="rounded-2xl bg-gray-50 px-4 py-3 text-xs font-black outline-none dark:bg-gray-800">
            <option value="all">كل الحالات</option>
            <option value="active">سارية الآن</option>
            <option value="upcoming">قادمة</option>
            <option value="expired">منتهية</option>
            <option value="pending">بانتظار الاعتماد</option>
            <option value="approved">معتمدة</option>
          </select>
          <select value={studentFilter} onChange={event => setStudentFilter(event.target.value)} className="rounded-2xl bg-gray-50 px-4 py-3 text-xs font-black outline-none dark:bg-gray-800">
            <option value="">كل الطلاب</option>
            {sortedStudents.map(student => <option key={student.id} value={student.id}>{student.name}</option>)}
          </select>
          <label className="flex items-center gap-2 rounded-2xl bg-gray-50 px-4 dark:bg-gray-800">
            <Search className="h-4 w-4 shrink-0 text-gray-400" />
            <input value={reasonFilter} onChange={event => setReasonFilter(event.target.value)} placeholder="ابحث في السبب…" className="min-w-0 flex-1 bg-transparent py-3 text-xs font-bold outline-none" />
          </label>
        </div>
        {periodFilter === "custom" && (
          <div className="mt-3 grid gap-3 sm:grid-cols-2">
            <label className="rounded-2xl bg-gray-50 px-4 py-2 text-[10px] font-black text-gray-400 dark:bg-gray-800">
              من تاريخ
              <input type="date" value={customFrom} onChange={event => setCustomFrom(event.target.value)} className="mt-1 block w-full bg-transparent py-1 text-xs font-bold text-gray-800 outline-none dark:text-gray-100" />
            </label>
            <label className="rounded-2xl bg-gray-50 px-4 py-2 text-[10px] font-black text-gray-400 dark:bg-gray-800">
              إلى تاريخ
              <input type="date" min={customFrom || undefined} value={customTo} onChange={event => setCustomTo(event.target.value)} className="mt-1 block w-full bg-transparent py-1 text-xs font-bold text-gray-800 outline-none dark:text-gray-100" />
            </label>
          </div>
        )}
      </div>

      {/* List */}
      <div className="bg-white/60 dark:bg-gray-900/60 backdrop-blur-md rounded-[3rem] border border-white dark:border-gray-800 shadow-xl overflow-hidden">
        {filteredVacations.length === 0 ? (
          <div className="p-16 flex flex-col items-center text-center gap-4 opacity-50">
            <Palmtree className="w-16 h-16 text-gray-300" />
            <p className="font-bold text-gray-400">لا توجد إجازات مطابقة للفلاتر الحالية</p>
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-right border-collapse">
              <thead>
                <tr className="bg-gray-50/50 dark:bg-gray-800/50">
                  <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest">الطالب</th>
                  <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest">الفترة</th>
                  <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest">السبب</th>
                  <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">الحالة</th>
                  <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">إجراءات</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
                {filteredVacations.map((v) => {
                  const isActive = today >= v.startDate && today <= v.endDate;
                  return (
                    <tr key={v.id} className="hover:bg-teal-50/20 dark:hover:bg-teal-900/10 transition-colors">
                      <td className="px-8 py-6">
                        <p className="font-black text-gray-800 dark:text-white text-sm">{studentName(v.studentId)}</p>
                        {isActive && (
                          <span className="text-[10px] font-bold text-blue-500 flex items-center gap-1 mt-0.5">
                            <Palmtree className="w-3 h-3" /> في إجازة حالياً
                          </span>
                        )}
                      </td>
                      <td className="px-8 py-6">
                        <p className="text-xs font-bold text-gray-600 dark:text-gray-300">
                          {v.startDate} <span className="text-gray-300 mx-1">←</span> {v.endDate}
                        </p>
                        <p className="text-[10px] text-gray-400 mt-1">{getHijriDate(new Date(v.startDate)).full}</p>
                      </td>
                      <td className="px-8 py-6 text-xs font-bold text-[var(--muted)]">{v.reason || "—"}</td>
                      <td className="px-8 py-6 text-center">
                        <button
                          onClick={() => toggleApproval(v.id, v.approved)}
                          className={`inline-flex items-center gap-2 px-3 py-1 rounded-xl text-[10px] font-black transition-all ${
                            v.approved
                              ? "bg-green-50 text-green-600 dark:bg-green-900/20"
                              : "bg-amber-50 text-amber-600 dark:bg-amber-900/20"
                          }`}
                        >
                          {v.approved ? <CheckCircle className="w-3 h-3" /> : <Clock className="w-3 h-3" />}
                          {v.approved ? "معتمدة" : "بانتظار الاعتماد"}
                        </button>
                      </td>
                      <td className="px-8 py-6 text-center flex items-center justify-center gap-2">
                        <button
                          onClick={() => handleEdit(v)}
                          className="p-2 rounded-xl text-gray-400 hover:text-teal-600 hover:bg-teal-50 dark:hover:bg-teal-900/20 transition-all"
                          aria-label="تعديل الإجازة"
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => {
                            if (confirm("هل تريد حذف هذه الإجازة؟")) deleteVacation(v.id);
                          }}
                          className="p-2 rounded-xl text-gray-400 hover:text-red-600 hover:bg-red-50 dark:hover:bg-red-900/20 transition-all"
                          aria-label="حذف الإجازة"
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Add/Edit Modal */}
      {showModal && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-[var(--surface)] rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative">
            <button
              onClick={() => {
                setShowModal(false);
                setEditingId(null);
                setForm({ studentId: "", startDate: "", endDate: "", reason: "" });
              }}
              className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
              aria-label="إغلاق"
            >
              <X className="w-6 h-6 text-gray-400" />
            </button>
            <h3 className="text-2xl font-black text-[var(--foreground)] mb-6">
              {editingId ? "تعديل تفاصيل الإجازة" : "تسجيل إجازة جديدة"}
            </h3>

            <div className="space-y-5">
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2">الطالب</label>
                <select
                  value={form.studentId}
                  onChange={(e) => setForm({ ...form, studentId: e.target.value })}
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 font-bold outline-none"
                >
                  <option value="">اختر الطالب...</option>
                  {sortedStudents.map((s) => (
                    <option key={s.id} value={s.id}>{s.name}</option>
                  ))}
                </select>
              </div>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2">من تاريخ</label>
                  <input
                    type="date"
                    value={form.startDate}
                    onChange={(e) => setForm({ ...form, startDate: e.target.value })}
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 font-bold outline-none"
                  />
                </div>
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2">إلى تاريخ</label>
                  <input
                    type="date"
                    value={form.endDate}
                    onChange={(e) => setForm({ ...form, endDate: e.target.value })}
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 font-bold outline-none"
                  />
                </div>
              </div>
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2">السبب</label>
                <input
                  type="text"
                  value={form.reason}
                  onChange={(e) => setForm({ ...form, reason: e.target.value })}
                  placeholder="مثال: سفر عائلي، ظرف صحي..."
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 font-bold outline-none"
                />
              </div>
              <button
                onClick={handleSubmit}
                disabled={!form.studentId || !form.startDate || !form.endDate}
                className="w-full py-5 bg-teal-600 text-white rounded-[2rem] font-black text-sm shadow-xl transition-all disabled:opacity-40"
              >
                حفظ الإجازة
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
