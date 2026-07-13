"use client";

import { useMemo, useEffect, useState } from "react";
import { 
  Download, 
  BookOpen, 
  Award,
  Users,
  Share2,
  PieChart,
  Target,
  AlertCircle,
  MessageCircle,
  Copy,
  Check
} from "lucide-react";
import { useStore } from "@/store/useStore";
import { buildMonthlyReportMessage, buildWhatsAppLink } from "@/lib/monthlyReport";

export default function ReportsPage() {
  const { 
    students, 
    homeworkGrades, 
    points, 
    memorization,
    exams,
    centerType,
    currentCenter,
    attendance,
    fetchCenterData,
    suspendedDates = [],
    fetchSuspendedDates
  } = useStore();
  const currentMonthKey = new Date().toISOString().slice(0, 7);
  const todayKey = new Date().toISOString().slice(0, 10);
  const [periodStart, setPeriodStart] = useState(`${currentMonthKey}-01`);
  const [periodEnd, setPeriodEnd] = useState(todayKey);
  const [reportStudentId, setReportStudentId] = useState<string>("");
  const [reportMonth, setReportMonth] = useState<string>(currentMonthKey);
  const [copied, setCopied] = useState(false);
  const [showPreview, setShowPreview] = useState(false);

  const inPeriod = (date: string) => date >= periodStart && date <= periodEnd;
  const activeStudents = useMemo(
    () => students.filter(student => student.status === "active"),
    [students]
  );
  const activeStudentIds = useMemo(
    () => new Set(activeStudents.map(student => student.id)),
    [activeStudents]
  );

  const periodAttendance = useMemo(
    () => attendance.filter(record => activeStudentIds.has(record.studentId) && inPeriod(record.date) && !suspendedDates.includes(record.date)),
    [attendance, activeStudentIds, suspendedDates, periodStart, periodEnd]
  );
  const periodGrades = useMemo(
    () => homeworkGrades.filter(record => activeStudentIds.has(record.studentId) && inPeriod(record.date) && !suspendedDates.includes(record.date)),
    [homeworkGrades, activeStudentIds, suspendedDates, periodStart, periodEnd]
  );
  const periodPoints = useMemo(
    () => points.filter(record => activeStudentIds.has(record.studentId) && inPeriod(record.date)),
    [points, activeStudentIds, periodStart, periodEnd]
  );
  const periodMemorization = useMemo(
    () => memorization.filter(record => activeStudentIds.has(record.studentId) && inPeriod(record.date)),
    [memorization, activeStudentIds, periodStart, periodEnd]
  );
  const periodExams = useMemo(
    () => exams.filter(exam => inPeriod(exam.date)),
    [exams, periodStart, periodEnd]
  );

  useEffect(() => {
    fetchCenterData();
    fetchSuspendedDates();
  }, [fetchCenterData, fetchSuspendedDates]);

  const reportMessage = useMemo(() => {
    const student = students.find(s => s.id === reportStudentId);
    if (!student) return "";
    return buildMonthlyReportMessage({
      student,
      month: reportMonth,
      attendance,
      grades: homeworkGrades,
      points,
      suspendedDates,
      centerType: centerType as "men" | "women" | "mixed",
    });
  }, [reportStudentId, reportMonth, students, attendance, homeworkGrades, points, suspendedDates, centerType]);

  const handleSendWhatsApp = () => {
    const student = students.find(s => s.id === reportStudentId);
    if (!student || !reportMessage) return;
    const link = buildWhatsAppLink(student.parentPhone, reportMessage);
    window.open(link, "_blank");
  };

  const handleCopyReport = async () => {
    if (!reportMessage) return;
    await navigator.clipboard.writeText(reportMessage);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const stats = useMemo(() => {
    const validAttendance = periodAttendance;
    const attendedCount = validAttendance.filter(a => a.status === 'present' || a.status === 'late').length;
    const totalRecords = validAttendance.length;
    const avgAttendance = totalRecords > 0 ? Math.round((attendedCount / totalRecords) * 100) : 0;

    const totalPoints = periodPoints.reduce((s, p) => s + p.amount, 0);

    // Filter out grades on suspended dates
    const gradedRecords = periodGrades.filter(g => g.gradeMark !== "absent");
    const scoreMap: Record<string, number> = {
      excellent: 5,
      very_good: 4,
      good: 3,
      needs_work: 2,
    };
    const avgMemorization = gradedRecords.length > 0
      ? (gradedRecords.reduce((sum, g) => sum + (scoreMap[g.gradeMark] || 3), 0) / gradedRecords.length).toFixed(1)
      : "0.0";
    const examScores = periodExams.flatMap(exam =>
      exam.studentScores
        .filter(score => activeStudentIds.has(score.studentId))
        .map(score => exam.maxDegree > 0 ? (score.degree / exam.maxDegree) * 100 : 0)
    );
    const avgExams = examScores.length
      ? Math.round(examScores.reduce((sum, score) => sum + score, 0) / examScores.length)
      : 0;
    const qualityPercent = Number(avgMemorization) * 20;
    const performance = Math.round(
      avgAttendance * 0.5 + qualityPercent * 0.35 + avgExams * 0.15
    );
    const totalMemorizedAyahs = periodMemorization
      .filter(record => !record.isRevision)
      .reduce((sum, record) => sum + Math.max(0, record.toAyah - record.fromAyah + 1), 0);
    const totalRevisedAyahs = periodMemorization
      .filter(record => record.isRevision)
      .reduce((sum, record) => sum + Math.max(0, record.toAyah - record.fromAyah + 1), 0);

    return {
      attendance: avgAttendance,
      points: totalPoints,
      memorization: avgMemorization,
      exams: avgExams,
      performance,
      totalMemorizedAyahs,
      totalRevisedAyahs,
      present: validAttendance.filter(record => record.status === "present").length,
      late: validAttendance.filter(record => record.status === "late").length,
      absent: validAttendance.filter(record => record.status === "absent").length,
      excused: validAttendance.filter(record => record.status === "excused").length,
    };
  }, [periodAttendance, periodGrades, periodPoints, periodMemorization, periodExams, activeStudentIds]);

  const topStudents = useMemo(() => {
    return activeStudents
      .map(student => {
        const studentPoints = periodPoints
          .filter(p => p.studentId === student.id)
          .reduce((sum, p) => sum + p.amount, 0);
        const grades = periodGrades.filter(g => g.studentId === student.id && g.gradeMark !== "absent");
        const gradeScore: Record<string, number> = { excellent: 5, very_good: 4, good: 3, needs_work: 2 };
        const quality = grades.length
          ? grades.reduce((sum, grade) => sum + (gradeScore[grade.gradeMark] || 0), 0) / grades.length
          : 0;
        const records = periodAttendance.filter(record => record.studentId === student.id);
        const attended = records.filter(record => record.status === "present" || record.status === "late").length;
        const attendanceRate = records.length ? Math.round((attended / records.length) * 100) : 0;
        const performance = Math.round(attendanceRate * 0.6 + quality * 20 * 0.4);
        const memorizedAyahs = periodMemorization
          .filter(record => record.studentId === student.id && !record.isRevision)
          .reduce((sum, record) => sum + Math.max(0, record.toAyah - record.fromAyah + 1), 0);
        return {
          ...student,
          totalPoints: studentPoints,
          performance,
          memorizedAyahs,
          attendanceRate,
          hasPeriodData: records.length > 0 || grades.length > 0 || memorizedAyahs > 0 || studentPoints !== 0,
        };
      })
      .filter(student => student.hasPeriodData)
      .sort((a, b) => b.performance - a.performance || b.memorizedAyahs - a.memorizedAyahs)
      .slice(0, 3);
  }, [activeStudents, periodPoints, periodGrades, periodAttendance, periodMemorization]);

  const attentionStudents = useMemo(() => activeStudents.filter(student => {
    const records = periodAttendance.filter(record => record.studentId === student.id);
    const absent = records.filter(record => record.status === "absent").length;
    const heard = periodMemorization.some(record => record.studentId === student.id && !record.isRevision);
    return records.length > 0 && (absent >= 2 || !heard);
  }), [activeStudents, periodAttendance, periodMemorization]);

  const downloadSummaryImage = () => {
    const canvas = document.createElement("canvas");
    canvas.width = 1200;
    canvas.height = 1500;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const gradient = ctx.createLinearGradient(1200, 0, 0, 1500);
    gradient.addColorStop(0, "#f0fdfa");
    gradient.addColorStop(1, "#f8fafc");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 1200, 1500);
    ctx.fillStyle = "#0f766e";
    ctx.fillRect(0, 0, 1200, 270);
    ctx.textAlign = "right";
    ctx.direction = "rtl";
    ctx.font = "bold 56px Tahoma, Arial";
    ctx.fillStyle = "#ffffff";
    ctx.fillText("التقرير التجميعي للحلقة", 1100, 90);
    ctx.font = "32px Tahoma, Arial";
    ctx.fillStyle = "#ccfbf1";
    ctx.fillText(currentCenter?.activeHalaqa?.name || currentCenter?.name || "حلقتي", 1100, 150);
    ctx.font = "25px Tahoma, Arial";
    ctx.fillText(`${periodStart} — ${periodEnd}`, 1100, 205);
    ctx.beginPath();
    ctx.fillStyle = "#ffffff";
    ctx.arc(150, 135, 88, 0, Math.PI * 2);
    ctx.fill();
    ctx.textAlign = "center";
    ctx.fillStyle = stats.performance >= 80 ? "#16a34a" : stats.performance >= 60 ? "#f59e0b" : "#dc2626";
    ctx.font = "bold 42px Tahoma, Arial";
    ctx.fillText(`${stats.performance}%`, 150, 135);
    ctx.font = "20px Tahoma, Arial";
    ctx.fillText("مستوى الحلقة", 150, 172);

    const cards = [
      ["الطلاب النشطون", activeStudents.length],
      ["نسبة الحضور", `${stats.attendance}%`],
      ["الحفظ الجديد", `${stats.totalMemorizedAyahs} آية`],
      ["المراجعة", `${stats.totalRevisedAyahs} آية`],
      ["إجمالي النقاط", stats.points],
      ["يحتاجون متابعة", attentionStudents.length],
    ];
    cards.forEach(([label, value], index) => {
      const col = index % 2;
      const row = Math.floor(index / 2);
      const x = col === 0 ? 620 : 70;
      const y = 320 + row * 180;
      ctx.fillStyle = "#ffffff";
      ctx.strokeStyle = "#cbd5e1";
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.roundRect(x, y, 510, 145, 24);
      ctx.fill();
      ctx.stroke();
      ctx.textAlign = "right";
      ctx.fillStyle = "#0f172a";
      ctx.font = "bold 36px Tahoma, Arial";
      ctx.fillText(String(value), x + 455, y + 65);
      ctx.fillStyle = "#64748b";
      ctx.font = "24px Tahoma, Arial";
      ctx.fillText(String(label), x + 455, y + 110);
    });
    ctx.fillStyle = "#ffffff";
    ctx.strokeStyle = "#cbd5e1";
    ctx.beginPath();
    ctx.roundRect(70, 890, 1060, 420, 28);
    ctx.fill();
    ctx.stroke();
    ctx.textAlign = "right";
    ctx.fillStyle = "#0f172a";
    ctx.font = "bold 34px Tahoma, Arial";
    ctx.fillText("متميزو الفترة", 1070, 955);
    topStudents.forEach((student, index) => {
      const y = 1025 + index * 82;
      ctx.fillStyle = index === 0 ? "#d97706" : "#0f766e";
      ctx.font = "bold 27px Tahoma, Arial";
      ctx.fillText(`${index + 1}. ${student.name}`, 1060, y);
      ctx.fillStyle = "#475569";
      ctx.font = "23px Tahoma, Arial";
      ctx.fillText(`الأداء ${student.performance}% · الحفظ ${student.memorizedAyahs} آية · الحضور ${student.attendanceRate}%`, 720, y);
    });
    ctx.textAlign = "center";
    ctx.fillStyle = "#94a3b8";
    ctx.font = "22px Tahoma, Arial";
    ctx.fillText("تقرير مولّد من البيانات المسجلة في تطبيق حلقتي", 600, 1425);
    canvas.toBlob(blob => {
      if (!blob) return;
      const link = document.createElement("a");
      link.href = URL.createObjectURL(blob);
      link.download = `تقرير_الحلقة_${periodStart}_${periodEnd}.png`;
      link.click();
      URL.revokeObjectURL(link.href);
    }, "image/png");
  };

  const exportToCSV = () => {
    const headers = [
      "اسم الطالب",
      "رقم الهاتف",
      "رقم ولي الأمر",
      "المستوى",
      "العمر",
      "عدد التسميعات",
      "تسميعات ممتاز",
      "تسميعات جيد جداً",
      "تسميعات جيد",
      "تسميعات مقبول",
      "تسميعات غائب",
      "متوسط الأخطاء",
      "تاريخ الانضمام",
      "الحالة"
    ];

    const rows = students.map(student => {
      // Exclude grades on suspended dates
      const studentGrades = periodGrades.filter(g => g.studentId === student.id);
      const gradedCount = studentGrades.length;
      
      const excellentCount = studentGrades.filter(g => g.gradeMark === "excellent").length;
      const veryGoodCount = studentGrades.filter(g => g.gradeMark === "very_good").length;
      const goodCount = studentGrades.filter(g => g.gradeMark === "good").length;
      const needsWorkCount = studentGrades.filter(g => g.gradeMark === "needs_work").length;
      const absentCount = studentGrades.filter(g => g.gradeMark === "absent").length;

      const activeGrades = studentGrades.filter(g => g.gradeMark !== "absent");
      const avgMistakes = activeGrades.length > 0
        ? (activeGrades.reduce((sum, g) => sum + g.mistakesCount, 0) / activeGrades.length).toFixed(1)
        : "0";

      return [
        student.name,
        student.phone,
        student.parentPhone,
        student.level,
        student.age,
        gradedCount,
        excellentCount,
        veryGoodCount,
        goodCount,
        needsWorkCount,
        absentCount,
        avgMistakes,
        student.joinDate,
        student.status === "active" ? "نشط" : "غير نشط"
      ];
    });

    const csvContent = [
      headers.join(","),
      ...rows.map(row => row.map(val => `"${String(val).replace(/"/g, '""')}"`).join(","))
    ].join("\n");

    const BOM = "\uFEFF";
    const blob = new Blob([BOM + csvContent], { type: "text/csv;charset=utf-8;" });
    const url = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.setAttribute("href", url);
    link.setAttribute("download", `تقرير_طلاب_الحلقة_${new Date().toISOString().split("T")[0]}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700">
      {suspendedDates.length > 0 && (
        <div className="bg-amber-500/10 border border-amber-500/20 text-amber-700 dark:text-amber-400 p-6 rounded-[2rem] flex items-center gap-4 animate-in slide-in-from-top-4">
          <AlertCircle className="w-8 h-8 text-amber-600 animate-pulse" />
          <div>
            <h4 className="font-black text-base text-amber-900 dark:text-white">تنبيه تعليق الحلقة ⚠️</h4>
            <p className="text-xs font-bold text-amber-600 dark:text-amber-405 mt-1">توجد أيام معلقة في هذه الحلقة ({suspendedDates.length} أيام). تم استبعاد هذه الأيام بالكامل من حسابات نسب الحضور والتقارير لضمان دقة الإحصائيات.</p>
          </div>
        </div>
      )}

      {/* Header */}
      <div className="flex flex-col lg:flex-row lg:items-center justify-between gap-6">
        <div className="flex items-center gap-4">
          <div className="text-4xl">📊</div>
          <div>
            <h1 className="text-3xl font-black text-gray-900 dark:text-white">التقارير والإحصائيات</h1>
            <p className="text-gray-500 dark:text-gray-400 font-medium">تحليل شامل لأداء الحلقة ومستويات تقدم الطلاب.</p>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <button 
            onClick={exportToCSV}
            className="flex items-center gap-2 bg-teal-600 text-white px-8 py-4 rounded-2xl font-black text-sm shadow-xl hover:bg-teal-700 transition-all"
          >
            <Download className="w-5 h-5" /> تصدير تقرير الطلاب (CSV)
          </button>
          <button 
            onClick={downloadSummaryImage}
            className="p-4 bg-white dark:bg-gray-900 border border-gray-100 dark:border-gray-800 rounded-2xl text-gray-400 hover:text-teal-600 transition-all shadow-sm"
            title="تنزيل صورة التقرير"
          >
            <Share2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="bg-white dark:bg-gray-900 rounded-3xl border border-gray-100 dark:border-gray-800 p-5 grid sm:grid-cols-2 lg:grid-cols-[1fr_1fr_auto] gap-4 items-end">
        <label className="text-sm font-black text-gray-600 dark:text-gray-300">
          من تاريخ
          <input type="date" value={periodStart} max={periodEnd} onChange={event => setPeriodStart(event.target.value)} className="mt-2 w-full rounded-xl border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-800" />
        </label>
        <label className="text-sm font-black text-gray-600 dark:text-gray-300">
          إلى تاريخ
          <input type="date" value={periodEnd} min={periodStart} max={todayKey} onChange={event => setPeriodEnd(event.target.value)} className="mt-2 w-full rounded-xl border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-800" />
        </label>
        <button onClick={downloadSummaryImage} className="rounded-xl bg-indigo-600 px-6 py-3 font-black text-white hover:bg-indigo-700">
          تنزيل صورة PNG
        </button>
      </div>

      {/* Main Stats Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-5 gap-6">
        {[
          { label: "مستوى الحلقة", value: `${stats.performance}%`, icon: PieChart, color: "text-indigo-600", bg: "bg-indigo-50" },
          { label: "نسبة الحضور", value: `${stats.attendance}%`, icon: Users, color: "text-teal-600", bg: "bg-teal-50" },
          { label: "متوسط الحفظ", value: stats.memorization, icon: BookOpen, color: "text-amber-600", bg: "bg-amber-50" },
          { label: "إجمالي النقاط", value: stats.points, icon: Award, color: "text-purple-600", bg: "bg-purple-50" },
          { label: "معدل الاختبارات", value: `${stats.exams}%`, icon: Target, color: "text-rose-600", bg: "bg-rose-50" },
        ].map((item, i) => (
          <div key={i} className="bg-white dark:bg-gray-900 rounded-[2.5rem] border border-gray-100 dark:border-gray-800 p-8 flex flex-col items-center text-center group hover:scale-[1.02] transition-all shadow-sm">
            <div className={`w-12 h-12 ${item.bg} dark:bg-gray-800 rounded-2xl flex items-center justify-center mb-4`}>
              <item.icon className={`w-6 h-6 ${item.color}`} />
            </div>
            <p className="text-3xl font-black text-gray-900 dark:text-white mb-1 tracking-tight">{item.value}</p>
            <p className="text-[10px] font-black text-gray-400 uppercase tracking-widest">{item.label}</p>
          </div>
        ))}
      </div>

      {/* Monthly WhatsApp Report */}
      <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-8 lg:p-10 shadow-sm">
        <div className="flex items-center gap-4 mb-8">
          <div className="w-12 h-12 bg-green-50 dark:bg-green-900/20 rounded-2xl flex items-center justify-center">
            <MessageCircle className="w-6 h-6 text-green-600" />
          </div>
          <div>
            <h3 className="text-xl font-black text-gray-900 dark:text-white">التقرير الشهري لولي الأمر</h3>
            <p className="text-xs font-bold text-gray-400">قالب واتساب جاهز بالإيموجي — اختر الطالب والشهر ثم أرسل مباشرة.</p>
          </div>
        </div>

        <div className="grid sm:grid-cols-2 gap-4 mb-6">
          <div>
            <label className="block text-[10px] font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">الطالب</label>
            <select
              value={reportStudentId}
              onChange={(e) => { setReportStudentId(e.target.value); setShowPreview(true); }}
              className="w-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-2xl px-4 py-3 font-bold text-sm text-gray-800 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
            >
              <option value="">— اختر الطالب —</option>
              {students.map(s => (
                <option key={s.id} value={s.id}>{s.name}</option>
              ))}
            </select>
          </div>
          <div>
            <label className="block text-[10px] font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">الشهر</label>
            <input
              type="month"
              value={reportMonth}
              onChange={(e) => setReportMonth(e.target.value)}
              className="w-full bg-gray-50 dark:bg-gray-800 border border-gray-100 dark:border-gray-700 rounded-2xl px-4 py-3 font-bold text-sm text-gray-800 dark:text-white focus:outline-none focus:ring-2 focus:ring-teal-500"
            />
          </div>
        </div>

        {reportStudentId && showPreview && (
          <div className="mb-6">
            <div className="bg-gray-50 dark:bg-gray-800 rounded-2xl p-5 border border-gray-100 dark:border-gray-700 whitespace-pre-wrap text-sm font-medium text-gray-700 dark:text-gray-200 leading-relaxed max-h-80 overflow-y-auto" dir="rtl">
              {reportMessage}
            </div>
          </div>
        )}

        <div className="flex flex-col sm:flex-row gap-3">
          <button
            onClick={handleSendWhatsApp}
            disabled={!reportStudentId}
            className="flex-1 flex items-center justify-center gap-2 bg-green-600 text-white px-6 py-4 rounded-2xl font-black text-sm shadow-lg hover:bg-green-700 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
          >
            <MessageCircle className="w-5 h-5" /> إرسال عبر واتساب
          </button>
          <button
            onClick={handleCopyReport}
            disabled={!reportStudentId}
            className="flex items-center justify-center gap-2 bg-white dark:bg-gray-800 border border-gray-100 dark:border-gray-700 text-gray-700 dark:text-white px-6 py-4 rounded-2xl font-black text-sm hover:bg-gray-50 transition-all disabled:opacity-40 disabled:cursor-not-allowed"
          >
            {copied ? <><Check className="w-5 h-5 text-green-600" /> تم النسخ</> : <><Copy className="w-5 h-5" /> نسخ النص</>}
          </button>
        </div>
      </div>

      <div className="grid lg:grid-cols-2 gap-10">
        {/* Top Students */}
        <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm">
          <h3 className="text-xl font-black text-gray-900 dark:text-white mb-8">الطلاب الأكثر تميزاً ⭐</h3>
          <div className="space-y-6">
            {topStudents.map((student, i) => (
              <div key={student.id} className="flex items-center gap-6 p-4 rounded-3xl hover:bg-gray-50 dark:hover:bg-gray-800 transition-all group">
                <div className={`w-12 h-12 rounded-2xl flex items-center justify-center font-black text-lg ${
                  i === 0 ? "bg-amber-100 text-amber-600" : "bg-gray-100 text-gray-400"
                }`}>
                  {i + 1}
                </div>
                <div className="flex-1">
                  <h4 className="font-black text-gray-800 dark:text-white">{student.name}</h4>
                  <p className="text-[10px] font-bold text-gray-400 uppercase tracking-widest">الأداء: {student.performance}% · الحفظ: {student.memorizedAyahs} آية</p>
                </div>
                <div className="text-right">
                  <span className="text-xl font-black text-teal-600">{student.performance}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        {/* Attendance Progress */}
        <div className="bg-white dark:bg-gray-900 rounded-[3rem] border border-gray-100 dark:border-gray-800 p-10 shadow-sm flex flex-col">
          <div className="flex items-center justify-between mb-8">
            <h3 className="text-xl font-black text-gray-900 dark:text-white">تطور الحضور</h3>
            <span className="text-[10px] font-black text-teal-600 bg-teal-50 px-3 py-1 rounded-full">الفترة المختارة</span>
          </div>
          <div className="space-y-5">
            {[
              ["حاضر", stats.present, "bg-green-500"],
              ["متأخر", stats.late, "bg-amber-500"],
              ["غائب", stats.absent, "bg-red-500"],
              ["مستأذن", stats.excused, "bg-blue-500"],
            ].map(([label, value, color]) => (
              <div key={String(label)}>
                <div className="mb-1 flex justify-between text-sm font-black"><span>{label}</span><span>{value}</span></div>
                <div className="h-3 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
                  <div className={`h-full ${color}`} style={{ width: `${Math.min(100, Number(value) / Math.max(1, periodAttendance.length) * 100)}%` }} />
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>

      {/* Assessment Summary */}
      <div className="bg-teal-900 rounded-[3.5rem] p-12 text-white relative overflow-hidden flex flex-col md:flex-row items-center gap-12 group">
        <div className="flex-1 space-y-6">
          <h2 className="text-3xl font-black flex items-center gap-4">
            خلاصة تقييم الحلقة ☀️
          </h2>
          <p className="text-teal-100/60 text-lg font-medium leading-relaxed">
            بلغ مستوى الحلقة خلال الفترة المختارة {stats.performance}%، بنسبة حضور {stats.attendance}%،
            وإنجاز {stats.totalMemorizedAyahs} آية حفظ جديد و{stats.totalRevisedAyahs} آية مراجعة.
            {attentionStudents.length > 0
              ? ` يوجد ${attentionStudents.length} من الطلاب يحتاجون متابعة بسبب الغياب المتكرر أو عدم وجود تسميع مسجل في الفترة.`
              : " لا توجد مؤشرات متابعة مرتفعة وفق البيانات المسجلة في هذه الفترة."}
          </p>
        </div>
        <div className="shrink-0 relative">
          <div className="w-32 h-32 rounded-full border-8 border-teal-500/20 flex items-center justify-center relative">
            <div className="w-32 h-32 rounded-full border-8 border-teal-400 border-t-transparent animate-spin-slow absolute inset-0" />
            <PieChart className="w-12 h-12 text-teal-400" />
          </div>
        </div>
        <div className="absolute inset-0 bg-[url('https://www.transparenttextures.com/patterns/islamic-art.png')] opacity-10 pointer-events-none" />
      </div>
    </div>
  );
}
