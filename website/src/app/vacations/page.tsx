"use client";

import { useState, useMemo } from "react";
import { Palmtree, Plus, Trash2, CheckCircle, Clock, X, CalendarRange, Pencil } from "lucide-react";
import { useStore } from "@/store/useStore";
import { supabase } from "@/lib/supabase";
import { getHijriDate } from "@/utils/dateUtils";

export default function VacationsPage() {
  const { students, vacations, addVacation, deleteVacation, fetchVacations, fetchAttendance } = useStore();
  const [showModal, setShowModal] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [form, setForm] = useState({ studentId: "", startDate: "", endDate: "", reason: "" });

  const today = new Date().toISOString().split("T")[0];

  const sorted = useMemo(
    () => [...vacations].sort((a, b) => b.startDate.localeCompare(a.startDate)),
    [vacations]
  );

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

  const handleEdit = (vacation: any) => {
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
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">إدارة الإجازات</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">
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
          <div key={i} className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm">
            <div className={`w-10 h-10 ${item.bg} rounded-2xl flex items-center justify-center mb-3`}>
              <item.icon className={`w-5 h-5 ${item.color}`} />
            </div>
            <p className="text-2xl font-black text-gray-900 dark:text-white">{item.value}</p>
            <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">{item.label}</p>
          </div>
        ))}
      </div>

      {/* List */}
      <div className="bg-white/60 dark:bg-gray-900/60 backdrop-blur-md rounded-[3rem] border border-white dark:border-gray-800 shadow-xl overflow-hidden">
        {sorted.length === 0 ? (
          <div className="p-16 flex flex-col items-center text-center gap-4 opacity-50">
            <Palmtree className="w-16 h-16 text-gray-300" />
            <p className="font-bold text-gray-400">لا توجد إجازات مسجلة بعد</p>
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
                {sorted.map((v) => {
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
                      <td className="px-8 py-6 text-xs font-bold text-gray-500 dark:text-gray-400">{v.reason || "—"}</td>
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
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative">
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
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-6">
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
                  {students.map((s) => (
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
