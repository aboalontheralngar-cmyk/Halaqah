"use client";

import { useState, useMemo } from "react";
import { 
  Calendar as CalendarIcon, 
  CheckCircle, 
  XCircle, 
  Clock, 
  Save, 
  Search,
  UserCheck,
  History,
  Sparkles,
  Palmtree,
  MessageSquare,
  ChevronRight,
  ChevronLeft,
  X,
  AlertCircle
} from "lucide-react";
import { useStore, AttendanceRecord } from "@/store/useStore";
import { getHijriDate } from "@/utils/dateUtils";
import Link from "next/link";

function formatDate(date: Date): string {
  return date.toISOString().split("T")[0];
}

export default function AttendancePage() {
  const { students, attendance, vacations, addAttendance, updateAttendance } = useStore();
  const [selectedDate, setSelectedDate] = useState(formatDate(new Date()));
  const [search, setSearch] = useState("");
  const [showDetailModal, setShowDetailModal] = useState<{studentId: string, status: AttendanceRecord['status']} | null>(null);
  const [extraData, setExtraData] = useState({ arrivalTime: "", absenceReason: "", notes: "" });

  const getAttendanceStatus = (studentId: string, date: string) => {
    const record = attendance.find(a => a.studentId === studentId && a.date === date);
    return record?.status;
  };

  const isStudentOnVacation = (studentId: string, date: string) => {
    return vacations.find(v => v.studentId === studentId && date >= v.startDate && date <= v.endDate);
  };

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
  }, [attendance, selectedDate, students, vacations]);

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {/* Header Section */}
      <div className="flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div>
          <h1 className="text-3xl font-black text-gray-900 dark:text-white tracking-tight">تسجيل الحضور اليومي 📝</h1>
          <p className="text-gray-500 dark:text-gray-400 mt-2 font-medium">نظام رصد دقيق يشمل وقت الوصول، الإجازات، وأسباب الغياب.</p>
        </div>
        
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
      </div>

      {/* Stats Section */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4 lg:gap-6">
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm">
          <div className="w-10 h-10 bg-green-50 dark:bg-green-900/20 rounded-2xl flex items-center justify-center mb-3">
            <CheckCircle className="w-5 h-5 text-green-600" />
          </div>
          <p className="text-2xl font-black text-gray-900 dark:text-white">{stats.present}</p>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">حاضر</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm">
          <div className="w-10 h-10 bg-red-50 dark:bg-red-900/20 rounded-2xl flex items-center justify-center mb-3">
            <XCircle className="w-5 h-5 text-red-600" />
          </div>
          <p className="text-2xl font-black text-gray-900 dark:text-white">{stats.absent}</p>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">غائب</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm">
          <div className="w-10 h-10 bg-amber-50 dark:bg-amber-900/20 rounded-2xl flex items-center justify-center mb-3">
            <Clock className="w-5 h-5 text-amber-600" />
          </div>
          <p className="text-2xl font-black text-gray-900 dark:text-white">{stats.excused}</p>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">مستأذن</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm">
          <div className="w-10 h-10 bg-blue-50 dark:bg-blue-900/20 rounded-2xl flex items-center justify-center mb-3">
            <Palmtree className="w-5 h-5 text-blue-600" />
          </div>
          <p className="text-2xl font-black text-gray-900 dark:text-white">{stats.onVacation}</p>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">في إجازة</p>
        </div>
        <div className="bg-white dark:bg-gray-900 rounded-[2rem] border border-gray-100 dark:border-gray-800 p-6 flex flex-col items-center text-center shadow-sm hidden md:flex">
          <div className="w-10 h-10 bg-teal-50 dark:bg-teal-900/20 rounded-2xl flex items-center justify-center mb-3">
            <UserCheck className="w-5 h-5 text-teal-600" />
          </div>
          <p className="text-2xl font-black text-gray-900 dark:text-white">{stats.total}</p>
          <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">الإجمالي</p>
        </div>
      </div>

      {/* Main List Container */}
      <div className="bg-white/60 dark:bg-gray-900/60 backdrop-blur-md rounded-[3rem] border border-white dark:border-gray-800 shadow-xl overflow-hidden">
        <div className="p-8 border-b border-gray-50 dark:border-gray-800 flex flex-col md:flex-row md:items-center justify-between gap-6">
          <div className="relative flex-1 max-w-md">
            <Search className="absolute right-5 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
            <input 
              type="text" 
              placeholder="بحث سريع باسم الطالب..." 
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="w-full pr-12 pl-6 py-3 bg-gray-50 dark:bg-gray-800 border-none rounded-2xl outline-none text-xs font-bold"
            />
          </div>
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
                        <button onClick={() => handleQuickStatus(student.id, "present")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${status === "present" ? "bg-green-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-green-600"}`}><CheckCircle className="w-5 h-5" /></button>
                        <button onClick={() => handleQuickStatus(student.id, "late")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${status === "late" ? "bg-amber-500 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-amber-500"}`}><Clock className="w-5 h-5" /></button>
                        <button onClick={() => handleQuickStatus(student.id, "absent")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${status === "absent" ? "bg-red-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-red-600"}`}><XCircle className="w-5 h-5" /></button>
                        <button onClick={() => handleQuickStatus(student.id, "excused")} className={`w-10 h-10 rounded-xl flex items-center justify-center transition-all ${status === "excused" ? "bg-blue-600 text-white" : "bg-gray-50 dark:bg-gray-800 text-gray-400 hover:text-blue-600"}`}><MessageSquare className="w-5 h-5" /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Details Modal (For Late/Absent) */}
      {showDetailModal && (
        <div className="fixed inset-0 bg-gray-900/40 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-in fade-in duration-300">
          <div className="bg-white dark:bg-gray-900 rounded-[2.5rem] p-10 w-full max-w-md shadow-2xl relative">
            <button onClick={() => setShowDetailModal(null)} className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"><X className="w-6 h-6 text-gray-400" /></button>
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-6">
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