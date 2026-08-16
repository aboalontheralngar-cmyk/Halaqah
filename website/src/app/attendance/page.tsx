"use client";

import { useState, useMemo, useEffect, useCallback } from "react";
import { useShallow } from "zustand/react/shallow";
import { 
  Calendar as CalendarIcon, 
  CheckCircle, 
  XCircle, 
  Clock, 
  UserCheck,
  Sparkles,
  Palmtree,
  MessageSquare,
  X,
  AlertCircle
} from "lucide-react";
import { useStore, AttendanceRecord } from "@/store/useStore";
import { getHijriDate, localDateKey } from "@/utils/dateUtils";
import Link from "next/link";
import { MetricCard, PageHeader, SearchField, Surface } from "@/components/ui/AppDesign";
import { isWeeklyHoliday } from "@/lib/dailyClosing";

function formatDate(date: Date): string {
  return localDateKey(date);
}

export default function AttendancePage() {
  const {
    students,
    attendance,
    vacations,
    addAttendance,
    updateAttendance,
    suspendedDates = [],
    studySuspensions,
    weeklyHolidayDays,
    fetchSuspendedDates,
    fetchCenterSettings,
    toggleSuspendedDate
  } = useStore(
    useShallow((state) => ({
      students: state.students,
      attendance: state.attendance,
      vacations: state.vacations,
      addAttendance: state.addAttendance,
      updateAttendance: state.updateAttendance,
      suspendedDates: state.suspendedDates,
      studySuspensions: state.studySuspensions,
      weeklyHolidayDays: state.weeklyHolidayDays,
      fetchSuspendedDates: state.fetchSuspendedDates,
      fetchCenterSettings: state.fetchCenterSettings,
      toggleSuspendedDate: state.toggleSuspendedDate,
    })),
  );
  const [selectedDate, setSelectedDate] = useState(formatDate(new Date()));
  const [search, setSearch] = useState("");
  const [showDetailModal, setShowDetailModal] = useState<{studentId: string, status: AttendanceRecord['status']} | null>(null);
  const [extraData, setExtraData] = useState({ arrivalTime: "", absenceReason: "", notes: "" });
  const [showSuspensionModal, setShowSuspensionModal] = useState(false);
  const [suspensionReason, setSuspensionReason] = useState("");
  const [savingSuspension, setSavingSuspension] = useState(false);

  const isExplicitlySuspended = suspendedDates.includes(selectedDate);
  const isWeeklyDayOff = isWeeklyHoliday(selectedDate, weeklyHolidayDays);
  const isSuspended = isExplicitlySuspended || isWeeklyDayOff;
  const activeSuspension = studySuspensions.find((item) => item.date === selectedDate);

  const getAttendanceStatus = useCallback((studentId: string, date: string) => {
    const record = attendance.find(a => a.studentId === studentId && a.date === date);
    return record?.status;
  }, [attendance]);

  const isStudentOnVacation = useCallback((studentId: string, date: string) => {
    return vacations.find(v => v.studentId === studentId && date >= v.startDate && date <= v.endDate);
  }, [vacations]);

  useEffect(() => {
    fetchSuspendedDates();
    fetchCenterSettings();
  }, [fetchCenterSettings, fetchSuspendedDates]);

  const handleSuspensionButton = async () => {
    if (isWeeklyDayOff) return;
    if (!isExplicitlySuspended) {
      setSuspensionReason("");
      setShowSuspensionModal(true);
      return;
    }
    if (!window.confirm("هل تريد إلغاء تعليق الدراسة لهذا اليوم؟")) return;
    setSavingSuspension(true);
    try {
      await toggleSuspendedDate(selectedDate);
    } catch (error) {
      alert(error instanceof Error ? error.message : "تعذر إلغاء التعليق");
    } finally {
      setSavingSuspension(false);
    }
  };

  useEffect(() => {
    if (isSuspended) return;

    const autoCorrectVacations = async () => {
      for (const student of students) {
        const vacation = isStudentOnVacation(student.id, selectedDate);
        if (vacation && vacation.approved) {
          const status = getAttendanceStatus(student.id, selectedDate);
          if (!status || status === "absent") {
            const existingRecord = attendance.find(
              a => a.studentId === student.id && a.date === selectedDate
            );
            const notes = `إجازة تلقائية: ${vacation.reason || 'ظرف شخصي'}`;
            if (existingRecord) {
              if (existingRecord.status !== "excused") {
                await updateAttendance(existingRecord.id, "excused", { notes });
              }
            } else {
              await addAttendance({ 
                studentId: student.id, 
                date: selectedDate, 
                status: "excused", 
                notes 
              });
            }
          }
        }
      }
    };

    autoCorrectVacations();
  }, [selectedDate, students, attendance, isSuspended, addAttendance, updateAttendance, getAttendanceStatus, isStudentOnVacation]);

  const handleQuickStatus = async (studentId: string, status: AttendanceRecord['status']) => {
    if (status === "late" || status === "absent") {
      setShowDetailModal({ studentId, status });
      setExtraData({ arrivalTime: "08:00", absenceReason: "", notes: "" });
      return;
    }

    const existingRecord = attendance.find(a => a.studentId === studentId && a.date === selectedDate);
    if (existingRecord) {
      await updateAttendance(existingRecord.id, status);
    } else {
      await addAttendance({ studentId, date: selectedDate, status });
    }
  };

  const handleSaveDetails = async () => {
    if (!showDetailModal) return;
    const { studentId, status } = showDetailModal;
    const existingRecord = attendance.find(a => a.studentId === studentId && a.date === selectedDate);
    
    if (existingRecord) {
      await updateAttendance(existingRecord.id, status, extraData);
    } else {
      await addAttendance({ studentId, date: selectedDate, status, ...extraData });
    }
    setShowDetailModal(null);
  };

  const filteredStudents = useMemo(() => {
    return students.filter(s => s.name.includes(search));
  }, [students, search]);

  const stats = useMemo(() => {
    const todayAttendance = attendance.filter(a => a.date === selectedDate);
    const present = todayAttendance.filter(a => a.status === "present" || a.status === "late").length;
    const absent = todayAttendance.filter(a => a.status === "absent").length;
    const excused = todayAttendance.filter(a => a.status === "excused").length;
    const onVacation = students.filter(s => isStudentOnVacation(s.id, selectedDate)).length;
    return { present, absent, excused, onVacation, total: students.length };
  }, [attendance, selectedDate, students, isStudentOnVacation]);

  return (
    <div className="page-enter space-y-8">
      {/* Header Section */}
      <PageHeader
        title="تسجيل الحضور اليومي"
        description="رصد الحضور والتأخر والإجازات وأسباب الغياب بتاريخ واضح."
        icon={CalendarIcon}
        actions={
          <>
          <button
            type="button"
            onClick={handleSuspensionButton}
            disabled={savingSuspension || isWeeklyDayOff}
            className={`px-5 py-3 rounded-2xl text-xs font-black transition-all border flex items-center gap-2 ${
              isSuspended
                ? "bg-emerald-50 text-emerald-700 border-emerald-200 dark:bg-emerald-950/20 dark:text-emerald-300 dark:border-emerald-900"
                : "bg-rose-50 text-rose-700 border-rose-200 dark:bg-rose-950/20 dark:text-rose-450 dark:border-rose-900"
            } disabled:cursor-not-allowed disabled:opacity-70`}
          >
            🗓️ {isWeeklyDayOff ? "إجازة أسبوعية" : isExplicitlySuspended ? "إلغاء تعليق الحلقة" : "تعليق الحلقة اليوم"}
          </button>

          <div className="bg-white/60 dark:bg-gray-900/60 backdrop-blur-md border border-white dark:border-gray-800 rounded-3xl shadow-xl p-4 flex items-center gap-6">
            <input 
              type="date" 
              value={selectedDate} 
              onChange={(e) => setSelectedDate(e.target.value)}
              className="bg-transparent border-none outline-none font-black text-teal-600 dark:text-teal-400 cursor-pointer" 
            />
            <div className="h-8 w-[1px] bg-gray-100 dark:bg-gray-800" />
            <span className="text-xs font-bold text-gray-400 dark:text-gray-500">{getHijriDate(new Date(selectedDate)).full}</span>
          </div>
          </>
        }
      />

      {isSuspended && (
        <div className="bg-rose-500/10 border border-rose-500/20 text-rose-700 dark:text-rose-400 p-6 rounded-[2rem] flex items-center gap-4 animate-in slide-in-from-top-4">
          <AlertCircle className="w-8 h-8 text-rose-600 animate-pulse" />
          <div>
            <h4 className="font-black text-base text-rose-900 dark:text-white">الحلقة معلقة اليوم ⚠️</h4>
            <p className="text-xs font-bold text-rose-600 dark:text-rose-300 mt-1">
              {isWeeklyDayOff ? "إجازة أسبوعية معتمدة." : activeSuspension?.reason || "تعليق دراسة معتمد."} تم قفل الحضور ولن يحتسب اليوم في الغياب أو النقاط.
            </p>
          </div>
        </div>
      )}

      {/* Stats Section */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 lg:gap-6">
        <MetricCard label="حاضر" value={stats.present} icon={CheckCircle} tone="green" />
        <MetricCard label="غائب" value={stats.absent} icon={XCircle} tone="red" />
        <MetricCard label="مستأذن" value={stats.excused} icon={Clock} tone="amber" />
        <MetricCard label="في إجازة" value={stats.onVacation} icon={Palmtree} tone="blue" />
        <div className="hidden md:block">
          <MetricCard label="الإجمالي" value={stats.total} icon={UserCheck} tone="teal" />
        </div>
      </div>

      {/* Main List Container */}
      <Surface className="overflow-hidden">
        <div className="p-8 border-b border-gray-50 dark:border-gray-800 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <SearchField
            value={search}
            onChange={setSearch}
            placeholder="بحث سريع باسم الطالب..."
            className="max-w-md flex-1"
          />
          <Link 
            href="/attendance/qr"
            className="px-8 py-3 bg-teal-600 text-white rounded-2xl text-xs font-black shadow-lg shadow-teal-100 flex items-center gap-2 hover:bg-teal-700 transition-all"
          >
            <Sparkles className="w-4 h-4" /> حضور ذكي (QR)
          </Link>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-right border-collapse">
            <thead>
              <tr className="bg-gray-50/50 dark:bg-gray-800/50">
                <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest">الطالب</th>
                <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">الحالة</th>
                <th className="px-8 py-4 text-[10px] font-black text-gray-400 uppercase tracking-widest text-center">رصد الحضور</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-gray-50 dark:divide-gray-800">
              {filteredStudents.map(student => {
                const status = getAttendanceStatus(student.id, selectedDate);
                const onVacation = isStudentOnVacation(student.id, selectedDate);
                
                return (
                  <tr key={student.id} className="hover:bg-teal-50/20 dark:hover:bg-teal-900/10 transition-colors group">
                    <td className="px-8 py-6">
                      <div className="flex items-center gap-4">
                        <div className="w-12 h-12 bg-gray-100 dark:bg-gray-800 rounded-2xl flex items-center justify-center font-black text-gray-400 group-hover:bg-teal-600 group-hover:text-white transition-all">
                          {student.name[0]}
                        </div>
                        <div>
                          <p className="font-black text-gray-800 dark:text-white text-sm">{student.name}</p>
                          {onVacation && (
                            <span className="text-[10px] font-bold text-blue-500 flex items-center gap-1 mt-0.5">
                              <Palmtree className="w-3 h-3" /> في إجازة ({onVacation.reason})
                            </span>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="px-8 py-6 text-center">
                      {status ? (
                        <div className={`inline-flex items-center gap-2 px-3 py-1 rounded-xl text-[10px] font-black ${
                          status === "present" ? "bg-green-50 text-green-600" : 
                          status === "late" ? "bg-amber-50 text-amber-600" :
                          status === "absent" ? "bg-red-50 text-red-600" : "bg-blue-50 text-blue-600"
                        }`}>
                          {status === "present" ? "حاضر" : status === "late" ? "متأخر" : status === "absent" ? "غائب" : "مستأذن"}
                        </div>
                      ) : (
                        <span className="text-[10px] font-bold text-gray-300 dark:text-gray-600">لم يرصد</span>
                      )}
                    </td>
                    <td className="px-8 py-6">
                      <div className="flex items-center justify-center gap-2">
                        <button disabled={isSuspended} onClick={() => handleQuickStatus(student.id, "present")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${isSuspended ? "opacity-35 cursor-not-allowed" : ""} ${status === "present" ? "bg-green-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-green-600"}`}><CheckCircle className="w-5 h-5" /></button>
                        <button disabled={isSuspended} onClick={() => handleQuickStatus(student.id, "late")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${isSuspended ? "opacity-35 cursor-not-allowed" : ""} ${status === "late" ? "bg-amber-500 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-amber-500"}`}><Clock className="w-5 h-5" /></button>
                        <button disabled={isSuspended} onClick={() => handleQuickStatus(student.id, "absent")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${isSuspended ? "opacity-35 cursor-not-allowed" : ""} ${status === "absent" ? "bg-red-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-red-600"}`}><XCircle className="w-5 h-5" /></button>
                        <button disabled={isSuspended} onClick={() => handleQuickStatus(student.id, "excused")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${isSuspended ? "opacity-35 cursor-not-allowed" : ""} ${status === "excused" ? "bg-blue-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-blue-600"}`}><MessageSquare className="w-5 h-5" /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </Surface>

      {showSuspensionModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-gray-900/50 p-4 backdrop-blur-sm">
          <div className="w-full max-w-md rounded-[2.5rem] bg-white p-8 shadow-2xl dark:bg-gray-900">
            <h3 className="text-xl font-black text-[var(--foreground)]">تعليق الدراسة</h3>
            <p className="mt-2 text-xs font-bold leading-6 text-gray-500">اكتب السبب ليظهر في التقارير، ولن يحتسب هذا اليوم ضمن الغياب أو عدم التسميع.</p>
            <textarea
              autoFocus
              value={suspensionReason}
              onChange={(event) => setSuspensionReason(event.target.value)}
              placeholder="مثال: نشاط المركز، إجازة رسمية، ظرف طارئ..."
              className="mt-5 h-28 w-full rounded-2xl border border-gray-200 bg-gray-50 px-5 py-4 text-sm font-bold outline-none focus:ring-2 focus:ring-teal-500/20 dark:border-gray-800 dark:bg-gray-800"
            />
            <div className="mt-6 flex gap-3">
              <button
                type="button"
                onClick={() => setShowSuspensionModal(false)}
                className="flex-1 rounded-2xl bg-gray-100 py-3 text-xs font-black text-gray-600 dark:bg-gray-800"
              >
                إلغاء
              </button>
              <button
                type="button"
                disabled={savingSuspension || !suspensionReason.trim()}
                onClick={async () => {
                  setSavingSuspension(true);
                  try {
                    await toggleSuspendedDate(selectedDate, suspensionReason);
                    setShowSuspensionModal(false);
                  } catch (error) {
                    alert(error instanceof Error ? error.message : "تعذر تعليق الدراسة");
                  } finally {
                    setSavingSuspension(false);
                  }
                }}
                className="flex-1 rounded-2xl bg-rose-600 py-3 text-xs font-black text-white disabled:opacity-50"
              >
                {savingSuspension ? "جارٍ الحفظ..." : "اعتماد التعليق"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Details Modal (For Late/Absent) */}
      {showDetailModal && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-[var(--surface)] rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative">
            <button onClick={() => setShowDetailModal(null)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><X className="w-6 h-6 text-gray-400" /></button>
            <h3 className="text-2xl font-black text-[var(--foreground)] mb-6">
              تفاصيل {showDetailModal.status === "late" ? "التأخر" : "الغياب"}
            </h3>
            
            <div className="space-y-6">
              {showDetailModal.status === "late" ? (
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2">وقت الوصول</label>
                  <input type="time" value={extraData.arrivalTime} onChange={e => setExtraData({...extraData, arrivalTime: e.target.value})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 font-bold outline-none" />
                </div>
              ) : (
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2">سبب الغياب</label>
                  <input type="text" value={extraData.absenceReason} onChange={e => setExtraData({...extraData, absenceReason: e.target.value})} placeholder="مثال: ظرف عائلي، مرض..." className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 font-bold outline-none" />
                </div>
              )}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2">ملاحظات إضافية</label>
                <textarea value={extraData.notes} onChange={e => setExtraData({...extraData, notes: e.target.value})} className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 font-bold outline-none h-24" />
              </div>
              <button onClick={handleSaveDetails} className="w-full py-5 bg-teal-600 text-white rounded-[2rem] font-black text-sm shadow-xl transition-all">حفظ البيانات</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
