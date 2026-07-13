"use client";

import { useState, useEffect, useMemo } from "react";
import { 
  BookOpen, 
  Plus, 
  X, 
  Sparkles, 
  Filter,
  Lightbulb,
  Share2,
  PlusCircle,
  MinusCircle,
  MessageCircle,
  CheckCircle,
  Pencil,
  Trash2,
  CalendarRange,
} from "lucide-react";
import { useStore, HomeworkGrade, type Student } from "@/store/useStore";
import { quranService, Surah } from "@/services/quranService";
import { EmptyState, PageHeader, Surface } from "@/components/ui/AppDesign";

const DEFAULT_GRADING_TEMPLATE = "السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}";

export default function MemorizationPage() {
  const { 
    students, 
    homeworkGrades, 
    addHomeworkGrade, 
    updateHomeworkGrade,
    deleteHomeworkGrade,
    fetchHomeworkGrades, 
    fetchStudents, 
    messageTemplates, 
    fetchMessageTemplates,
    addPoints,
    pointsConfig,
    fetchPointsConfig
  } = useStore();

  const [surahs, setSurahs] = useState<Surah[]>([]);
  const [showForm, setShowForm] = useState(false);
  const [studentFilter, setStudentFilter] = useState("");
  const [typeFilter, setTypeFilter] = useState<"all" | "memorization" | "revision">("all");
  const [dateFrom, setDateFrom] = useState("");
  const [dateTo, setDateTo] = useState("");
  const [editingGrade, setEditingGrade] = useState<HomeworkGrade | null>(null);
  const [saving, setSaving] = useState(false);
  const [toastMessage, setToastMessage] = useState<string | null>(null);

  const [formData, setFormData] = useState({
    studentId: "",
    surahNum: "" as number | "",
    fromAyah: 1,
    toAyah: 1,
    gradeMark: "excellent" as HomeworkGrade["gradeMark"],
    mistakesCount: 0,
    isRevision: false,
    remark: "",
    date: new Date().toISOString().slice(0, 10),
  });

  const sortedActiveStudents = useMemo(
    () => students
      .filter(student => student.status === "active" || student.status === "graduated")
      .sort((a, b) => a.name.localeCompare(b.name, "ar")),
    [students],
  );

  useEffect(() => {
    quranService.initialize().then(() => {
      setSurahs(quranService.getSurahs());
    });
    fetchStudents();
    fetchHomeworkGrades();
    fetchMessageTemplates();
    fetchPointsConfig();
  }, [fetchStudents, fetchHomeworkGrades, fetchMessageTemplates, fetchPointsConfig]);

  const showToast = (message: string) => {
    setToastMessage(message);
    setTimeout(() => {
      setToastMessage(null);
    }, 3000);
  };

  const selectedSurah = useMemo(() => {
    if (!formData.surahNum) return undefined;
    return surahs.find(s => s.number === formData.surahNum);
  }, [formData.surahNum, surahs]);

  const setEndAtBoundary = (boundary: "page" | "hizb") => {
    if (!selectedSurah) return;
    const start = selectedSurah.ayahs.find(
      (ayah) => ayah.number === formData.fromAyah
    );
    if (!start) return;
    const matching = selectedSurah.ayahs.filter(
      (ayah) =>
        ayah.number >= formData.fromAyah &&
        (boundary === "page" ? ayah.page === start.page : ayah.hizb === start.hizb)
    );
    const end = matching.reduce(
      (last, ayah) => Math.max(last, ayah.number),
      formData.fromAyah
    );
    setFormData({ ...formData, toAyah: end });
  };

  // إجمالي الآيات المحفوظة لطالب معيّن (من سجل الحفظ الجديد غير الغياب)
  const getMemorizedAyahCount = (studentId: string) => {
    return homeworkGrades
      .filter(g => g.studentId === studentId && !g.isRevision && g.gradeMark !== 'absent')
      .reduce((sum, g) => sum + Math.max(0, (g.toAyah - g.fromAyah + 1)), 0);
  };

  // الطالب الذي ختم القرآن (إجمالي محفوظه >= 6236 آية): يُغلق عليه الحفظ الجديد وتبقى المراجعة فقط
  const selectedStudentFinishedQuran = useMemo(() => {
    if (!formData.studentId) return false;
    const student = students.find(item => item.id === formData.studentId);
    return student?.status === "graduated" || getMemorizedAyahCount(formData.studentId) >= 6236;
  }, [formData.studentId, homeworkGrades, students]);

  const getTemplateText = (type: "assignment" | "grading") => {
    const template = messageTemplates.find(t => t.type === type);
    return template ? template.content : DEFAULT_GRADING_TEMPLATE;
  };

  const generateReportMessage = (grade: Omit<HomeworkGrade, "id">) => {
    const student = students.find(s => s.id === grade.studentId);
    const studentName = student?.name || "";
    const templateText = getTemplateText("grading");
    
    const gradeTranslation: Record<string, string> = {
      excellent: "ممتاز ⭐⭐⭐⭐⭐",
      very_good: "جيد جداً ⭐⭐⭐⭐",
      good: "جيد ⭐⭐⭐",
      needs_work: "يحتاج تركيز ⭐⭐",
      absent: "غائب ❌",
    };

    return templateText
      .replace(/{اسم_الطالب}/g, studentName)
      .replace(/{السورة}/g, grade.surah)
      .replace(/{من}/g, String(grade.fromAyah))
      .replace(/{إلى}/g, String(grade.toAyah))
      .replace(/{التقييم}/g, gradeTranslation[grade.gradeMark] || grade.gradeMark)
      .replace(/{الأخطاء}/g, String(grade.mistakesCount))
      .replace(/{الملاحظة}/g, grade.remark || "لا يوجد");
  };

  const getNextAyahForStudent = (student: Student, lastGrade?: HomeworkGrade) => {
    const dir = student.memorizationDirection || 'desc';
    const defSurah = dir === 'desc' ? 114 : 1;
    const defAyah = 1;
    
    if (lastGrade) {
      const lastSurahObj = surahs.find(s => s.name === lastGrade.surah);
      if (lastSurahObj) {
        const currentSurah = lastSurahObj.number;
        const currentAyah = lastGrade.toAyah;
        
        if (currentAyah < lastSurahObj.totalAyahs) {
          return { surahNum: currentSurah, ayahNum: currentAyah + 1 };
        } else {
          if (dir === 'desc') {
            const nextSurah = currentSurah - 1;
            return { surahNum: nextSurah >= 1 ? nextSurah : 1, ayahNum: 1 };
          } else {
            const nextSurah = currentSurah + 1;
            return { surahNum: nextSurah <= 114 ? nextSurah : 114, ayahNum: 1 };
          }
        }
      }
    }
    
    if (student.preMemorizedEndSurah) {
      const preEndSurahObj = surahs.find(s => s.number === student.preMemorizedEndSurah);
      if (preEndSurahObj) {
        const currentSurah = student.preMemorizedEndSurah;
        const currentAyah = student.preMemorizedEndAyah || 1;
        
        if (currentAyah < preEndSurahObj.totalAyahs) {
          return { surahNum: currentSurah, ayahNum: currentAyah + 1 };
        } else {
          if (dir === 'desc') {
            const nextSurah = currentSurah - 1;
            return { surahNum: nextSurah >= 1 ? nextSurah : 1, ayahNum: 1 };
          } else {
            const nextSurah = currentSurah + 1;
            return { surahNum: nextSurah <= 114 ? nextSurah : 114, ayahNum: 1 };
          }
        }
      }
    }
    
    return {
      surahNum: defSurah,
      ayahNum: defAyah
    };
  };

  const getGradeAmount = (surahNum: number, fromAyah: number, toAyah: number, planType: 'ayahs' | 'pages' | 'lines') => {
    const surah = surahs.find(s => s.number === surahNum);
    if (!surah) return 0;
    if (planType === 'ayahs') {
      return toAyah - fromAyah + 1;
    } else if (planType === 'lines') {
      const ayahsInRange = surah.ayahs.filter(a => a.number >= fromAyah && a.number <= toAyah);
      const uniquePages = new Set(ayahsInRange.map(a => a.page));
      return uniquePages.size * 15; // Approximate 15 lines per page
    } else {
      const ayahsInRange = surah.ayahs.filter(a => a.number >= fromAyah && a.number <= toAyah);
      const uniquePages = new Set(ayahsInRange.map(a => a.page));
      return uniquePages.size;
    }
  };

  const resetForm = () => {
    setEditingGrade(null);
    setShowForm(false);
    setFormData({
      studentId: "",
      surahNum: "",
      fromAyah: 1,
      toAyah: 1,
      gradeMark: "excellent",
      mistakesCount: 0,
      isRevision: false,
      remark: "",
      date: new Date().toISOString().slice(0, 10),
    });
  };

  const selectStudentForNewRecord = (studentId: string) => {
    if (!studentId) {
      setFormData(current => ({
        ...current,
        studentId: "",
        surahNum: "",
        fromAyah: 1,
        toAyah: 1,
      }));
      return;
    }
    const student = students.find(item => item.id === studentId);
    if (!student) return;
    const lastGrade = homeworkGrades
      .filter(grade =>
        grade.studentId === studentId &&
        !grade.isRevision &&
        grade.gradeMark !== "absent"
      )
      .sort((a, b) =>
        b.date.localeCompare(a.date) ||
        (b.createdAt ?? "").localeCompare(a.createdAt ?? "")
      )[0];
    const next = getNextAyahForStudent(student, lastGrade);
    const finishedQuran = student.status === "graduated" ||
      getMemorizedAyahCount(studentId) >= 6236;
    setFormData(current => ({
      ...current,
      studentId,
      surahNum: next.surahNum,
      fromAyah: next.ayahNum,
      toAyah: next.ayahNum,
      isRevision: finishedQuran ? true : current.isRevision,
    }));
  };

  useEffect(() => {
    if (surahs.length === 0 || students.length === 0) return;
    const studentId = localStorage.getItem("memorization_prefill_student_id");
    if (!studentId || !students.some(student => student.id === studentId)) return;
    localStorage.removeItem("memorization_prefill_student_id");
    setEditingGrade(null);
    setShowForm(true);
    selectStudentForNewRecord(studentId);
  }, [students, surahs, homeworkGrades]);

  const openEditForm = (grade: HomeworkGrade) => {
    const surah = surahs.find(item => item.name === grade.surah);
    if (!surah) {
      showToast("تعذر العثور على السورة في بيانات المصحف");
      return;
    }
    setEditingGrade(grade);
    setFormData({
      studentId: grade.studentId,
      surahNum: surah.number,
      fromAyah: grade.fromAyah,
      toAyah: grade.toAyah,
      gradeMark: grade.gradeMark,
      mistakesCount: grade.mistakesCount,
      isRevision: grade.isRevision,
      remark: grade.remark ?? "",
      date: grade.date,
    });
    setShowForm(true);
  };

  const handleDelete = async (grade: HomeworkGrade) => {
    const studentName = students.find(student => student.id === grade.studentId)?.name ?? "الطالب";
    if (!confirm(`حذف سجل ${studentName} بتاريخ ${grade.date}؟ سيعاد حساب خريطة المصحف.`)) return;
    const deleted = await deleteHomeworkGrade(grade.id);
    if (deleted) showToast("تم حذف السجل وإعادة حساب خريطة المصحف");
  };

  const handleSave = async (e: React.FormEvent, shouldShare = false) => {
    e.preventDefault();
    if (!formData.studentId || !formData.surahNum || saving) return;

    const surah = surahs.find(s => s.number === formData.surahNum);
    if (!surah || formData.fromAyah < 1 || formData.toAyah < formData.fromAyah || formData.toAyah > surah.totalAyahs) {
      showToast("نطاق الآيات غير صحيح للسورة المحددة");
      return;
    }
    const newGrade = {
      studentId: formData.studentId,
      surah: surah?.name || "",
      fromAyah: formData.fromAyah,
      toAyah: formData.toAyah,
      date: formData.date,
      gradeMark: formData.gradeMark,
      mistakesCount: formData.mistakesCount,
      isRevision: formData.isRevision,
      remark: formData.remark,
    };

    setSaving(true);
    const saved = editingGrade
      ? await updateHomeworkGrade(editingGrade.id, newGrade)
      : await addHomeworkGrade(newGrade);
    if (!saved) {
      setSaving(false);
      return;
    }

    // Auto-points reward logic for exceeding target
    const student = students.find(s => s.id === formData.studentId);
    let addedExtraPoints = false;
    let extraPoints = 0;
    if (!editingGrade && student && !formData.isRevision && formData.gradeMark !== 'absent') {
      const completedAmount = getGradeAmount(Number(formData.surahNum), formData.fromAyah, formData.toAyah, student.planType);
      if (completedAmount > student.planAmount) {
        extraPoints = pointsConfig['extra_memorization'] ?? 2;
        if (extraPoints > 0) {
          await addPoints({
            studentId: formData.studentId,
            type: 'positive',
            amount: extraPoints,
            reason: 'زيادة عن المقرر اليومي',
            date: new Date().toISOString().split("T")[0]
          });
          addedExtraPoints = true;
        }
      }
    }

    if (shouldShare) {
      const msg = generateReportMessage(newGrade);
      const parentPhone = student?.parentPhone || "";

      if (navigator.share) {
        try {
          await navigator.share({
            title: `تقرير تسميع ${student?.name}`,
            text: msg,
          });
          showToast(addedExtraPoints 
            ? `تمت المشاركة وإضافة ${extraPoints} نقاط للزيادة 🎉` 
            : "تمت المشاركة بنجاح");
        } catch {
          navigator.clipboard.writeText(msg);
          showToast(addedExtraPoints 
            ? `تم نسخ التقرير وإضافة ${extraPoints} نقاط للزيادة 🎉` 
            : "تم نسخ التقرير للحافظة");
          if (parentPhone) {
            window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
          }
        }
      } else {
        navigator.clipboard.writeText(msg);
        showToast(addedExtraPoints 
          ? `تم نسخ التقرير وإضافة ${extraPoints} نقاط للزيادة 🎉` 
          : "تم نسخ التقرير للحافظة");
        if (parentPhone) {
          window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
        }
      }
    } else {
      showToast(addedExtraPoints 
        ? `تم حفظ التقييم بنجاح، وإضافة ${extraPoints} نقاط مكافأة للزيادة 🎉` 
        : "تم حفظ التقييم بنجاح");
    }

    setSaving(false);
    resetForm();
  };

  const handleShareExisting = (grade: HomeworkGrade) => {
    const msg = generateReportMessage(grade);
    const student = students.find(s => s.id === grade.studentId);
    const parentPhone = student?.parentPhone || "";

    if (navigator.clipboard) {
      navigator.clipboard.writeText(msg);
      showToast("تم نسخ التقرير للحافظة");
    }
    
    if (parentPhone) {
      window.open(`https://wa.me/${parentPhone}?text=${encodeURIComponent(msg)}`, "_blank");
    }
  };

  const handleShareImage = async (grade: HomeworkGrade) => {
    const student = students.find(s => s.id === grade.studentId);
    const studentName = student?.name || "طالب";
    const parentPhone = student?.parentPhone || "";

    const canvas = document.createElement("canvas");
    canvas.width = 800;
    canvas.height = 500;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;

    // Background Gradient (Teal to Slate/Cyan)
    const gradient = ctx.createLinearGradient(0, 0, 800, 500);
    gradient.addColorStop(0, "#0f766e"); // dark teal
    gradient.addColorStop(1, "#115e59"); // deeper teal
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, 800, 500);

    // Subtle decorative circles
    ctx.fillStyle = "rgba(255, 255, 255, 0.03)";
    ctx.beginPath();
    ctx.arc(80, 80, 150, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.arc(720, 420, 200, 0, Math.PI * 2);
    ctx.fill();

    // White card background
    ctx.fillStyle = "rgba(255, 255, 255, 0.96)";
    ctx.beginPath();
    ctx.roundRect(40, 40, 720, 420, 30);
    ctx.fill();

    // Border
    ctx.strokeStyle = "rgba(20, 184, 166, 0.2)";
    ctx.lineWidth = 4;
    ctx.stroke();

    // Title Banner
    ctx.fillStyle = "#14b8a6"; // teal-500
    ctx.beginPath();
    ctx.roundRect(250, 20, 300, 50, 15);
    ctx.fill();

    ctx.fillStyle = "#ffffff";
    ctx.font = "bold 20px 'Segoe UI', Tahoma, Arial";
    ctx.textAlign = "center";
    ctx.fillText("بطاقة تقييم التسميع اليومي 📖", 400, 52);

    // Text details (Align Right since it's Arabic)
    ctx.textAlign = "right";
    ctx.textBaseline = "middle";

    // Student Name
    ctx.fillStyle = "#0f172a"; // slate-900
    ctx.font = "bold 26px 'Segoe UI', Tahoma, Arial";
    ctx.fillText(`اسم الطالب: ${studentName}`, 700, 120);

    // Surah and Ayahs
    ctx.fillStyle = "#334155"; // slate-700
    ctx.font = "bold 22px 'Segoe UI', Tahoma, Arial";
    ctx.fillText(`الواجب المنجز: سورة ${grade.surah} (الآيات ${grade.fromAyah} إلى ${grade.toAyah})`, 700, 180);

    // Type of homework
    const typeText = grade.isRevision ? "مراجعة" : "حفظ جديد";
    ctx.fillText(`نوع التسميع: ${typeText}`, 700, 230);

    // Mistakes Count
    if (grade.gradeMark !== "absent") {
      ctx.fillStyle = grade.mistakesCount > 0 ? "#e11d48" : "#0f766e";
      ctx.fillText(`عدد الأخطاء: ${grade.mistakesCount}`, 700, 280);
    }

    // Remark
    if (grade.remark) {
      ctx.fillStyle = "#475569";
      ctx.font = "italic 18px 'Segoe UI', Tahoma, Arial";
      ctx.fillText(`ملاحظات المعلم: ${grade.remark}`, 700, 330);
    }

    // Date
    ctx.fillStyle = "#94a3b8";
    ctx.font = "bold 16px 'Segoe UI', Tahoma, Arial";
    ctx.fillText(`التاريخ: ${grade.date}`, 700, 380);

    // Draw Grade Badge (Left Side)
    const gradeBadges: Record<string, { label: string; bg: string; text: string }> = {
      excellent: { label: "ممتاز", bg: "#dcfce7", text: "#15803d" },
      very_good: { label: "جيد جداً", bg: "#dcfce7", text: "#166534" },
      good: { label: "جيد", bg: "#fef3c7", text: "#b45309" },
      needs_work: { label: "مقبول", bg: "#ffedd5", text: "#c2410c" },
      absent: { label: "غائب", bg: "#fee2e2", text: "#b91c1c" }
    };
    const badge = gradeBadges[grade.gradeMark] || gradeBadges.good;

    ctx.fillStyle = badge.bg;
    ctx.beginPath();
    ctx.roundRect(80, 160, 200, 160, 20);
    ctx.fill();

    ctx.fillStyle = badge.text;
    ctx.font = "bold 34px 'Segoe UI', Tahoma, Arial";
    ctx.textAlign = "center";
    ctx.fillText(badge.label, 180, 230);

    ctx.font = "bold 16px 'Segoe UI', Tahoma, Arial";
    ctx.fillText("التقييم العام", 180, 280);

    // Footer brand logo
    ctx.fillStyle = "#0f766e";
    ctx.font = "bold 18px 'Segoe UI', Tahoma, Arial";
    ctx.fillText("مقرأة حلقة القرآن الكريم الإلكترونية", 400, 435);

    // Process sharing
    try {
      canvas.toBlob(async (blob) => {
        if (!blob) return;
        const file = new File([blob], `grade_report_${studentName}.png`, { type: "image/png" });
        if (navigator.canShare && navigator.canShare({ files: [file] })) {
          await navigator.share({
            files: [file],
            title: `تقرير تسميع ${studentName}`,
            text: `تقرير تسميع الطالب ${studentName} لليوم`,
          });
          showToast("تمت مشاركة الصورة بنجاح");
        } else {
          // Fallback to direct download
          const url = URL.createObjectURL(blob);
          const a = document.createElement("a");
          a.href = url;
          a.download = `تقرير_تسميع_${studentName}.png`;
          document.body.appendChild(a);
          a.click();
          document.body.removeChild(a);
          URL.revokeObjectURL(url);
          showToast("تم تحميل صورة التقرير بنجاح");
          if (parentPhone) {
            window.open(`https://wa.me/${parentPhone}`, "_blank");
          }
        }
      }, "image/png");
    } catch (e) {
      console.error(e);
      showToast("فشلت المشاركة، جاري التحميل بدلاً من ذلك");
    }
  };

  const filteredGrades = useMemo(() => {
    return homeworkGrades
      .filter(m => !studentFilter || m.studentId === studentFilter)
      .filter(m => typeFilter === "all" || (typeFilter === "revision" ? m.isRevision : !m.isRevision))
      .filter(m => !dateFrom || m.date >= dateFrom)
      .filter(m => !dateTo || m.date <= dateTo)
      .sort((a, b) =>
        b.date.localeCompare(a.date) ||
        (b.createdAt ?? "").localeCompare(a.createdAt ?? "")
      );
  }, [homeworkGrades, studentFilter, typeFilter, dateFrom, dateTo]);

  const stats = useMemo(() => {
    const count = filteredGrades.length;
    if (count === 0) return { count, avg: "0.0" };

    const scoreMap: Record<string, number> = {
      excellent: 5,
      very_good: 4,
      good: 3,
      needs_work: 2,
      absent: 0
    };

    const gradedRecords = filteredGrades.filter(g => g.gradeMark !== "absent");
    if (gradedRecords.length === 0) return { count, avg: "0.0" };

    const sum = gradedRecords.reduce((acc, curr) => acc + scoreMap[curr.gradeMark], 0);
    const avg = (sum / gradedRecords.length).toFixed(1);
    return { count, avg };
  }, [filteredGrades]);

  const getStudentName = (id: string) => students.find(s => s.id === id)?.name || "طالب محذوف";

  const gradeBadges: Record<string, { label: string; style: string }> = {
    excellent: { label: "ممتاز", style: "bg-emerald-100 text-emerald-800 dark:bg-emerald-900/30 dark:text-emerald-400" },
    very_good: { label: "جيد جداً", style: "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-400" },
    good: { label: "جيد", style: "bg-amber-100 text-amber-800 dark:bg-amber-900/30 dark:text-amber-400" },
    needs_work: { label: "مقبول", style: "bg-orange-100 text-orange-800 dark:bg-orange-900/30 dark:text-orange-400" },
    absent: { label: "غائب", style: "bg-rose-100 text-rose-800 dark:bg-rose-900/30 dark:text-rose-400" }
  };

  return (
    <div className="page-enter relative space-y-8 pb-20">
      {/* Toast Alert */}
      {toastMessage && (
        <div className="fixed bottom-10 left-10 z-50 bg-gray-900 text-white px-6 py-4 rounded-2xl shadow-2xl flex items-center gap-3 animate-in fade-in slide-in-from-left-4">
          <CheckCircle className="w-5 h-5 text-emerald-400" />
          <span className="font-bold text-xs">{toastMessage}</span>
        </div>
      )}

      {/* Header */}
      <PageHeader
        title="سجل التقييم والتسميع"
        description="تقييم الحفظ والمراجعة، ومتابعة الأخطاء، ومشاركة النتائج مع أولياء الأمور."
        icon={BookOpen}
      />

      <div className="grid lg:grid-cols-3 gap-10">
        {/* Sidebar Info */}
        <div className="space-y-8 flex flex-col items-start order-2 lg:order-1">
          <button 
            onClick={() => {
              resetForm();
              setShowForm(true);
            }}
            className="w-full bg-teal-600 text-white px-8 py-5 rounded-[2rem] font-black text-sm hover:bg-teal-700 shadow-xl shadow-teal-100 dark:shadow-none transition-all flex items-center justify-center gap-2 group"
          >
            <Plus className="w-5 h-5 group-hover:rotate-90 transition-transform" />
            تسجيل تقييم جديد
          </button>

          <div className="w-full bg-gradient-to-br from-teal-600 to-teal-400 rounded-[3rem] p-10 text-white shadow-xl relative overflow-hidden group">
            <h3 className="text-xl font-black mb-8 relative z-10 flex items-center gap-2">
              إحصائيات التقييم 📊
            </h3>
            <div className="grid grid-cols-2 gap-4 relative z-10">
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.avg}</p>
                <p className="text-[10px] font-bold text-teal-100 uppercase mt-1">معدل الدرجات</p>
              </div>
              <div className="bg-white/10 backdrop-blur-md rounded-[2rem] p-6 border border-white/10 flex flex-col items-center text-center">
                <p className="text-3xl font-black">{stats.count}</p>
                <p className="text-[10px] font-bold text-teal-100 uppercase mt-1">تسميع مسجل</p>
              </div>
            </div>
            <Sparkles className="absolute -bottom-10 -right-10 w-40 h-40 text-white/10" />
          </div>

          <div className="w-full bg-cyan-50/50 dark:bg-cyan-900/10 border border-cyan-100 dark:border-cyan-800 rounded-[3rem] p-8 flex flex-col gap-4">
            <div className="w-12 h-12 bg-white dark:bg-gray-800 rounded-2xl flex items-center justify-center shadow-sm">
              <Lightbulb className="w-6 h-6 text-teal-600" />
            </div>
            <div>
              <h4 className="text-sm font-black text-gray-900 dark:text-white mb-2">مشاركة أولياء الأمور 💬</h4>
              <p className="text-xs text-gray-500 dark:text-gray-400 leading-relaxed font-medium">
                بإمكانك إرسال التقرير اليومي لولي الأمر مباشرة عبر واتساب بضغطة زر. يمكنك تخصيص قالب الرسائل في صفحة الإعدادات لتغيير صيغة الخطاب.
              </p>
            </div>
          </div>
        </div>

        {/* Main Records List */}
        <div className="lg:col-span-2 space-y-6 order-1 lg:order-2">
          <div className="space-y-3">
            <div className="flex items-center justify-between gap-3">
            <h2 className="text-xl font-black text-gray-900 dark:text-white">آخر التقييمات</h2>
            <div className="flex items-center gap-3 bg-white dark:bg-gray-900 px-4 py-2 rounded-2xl border border-gray-100 dark:border-gray-800 shadow-sm">
              <Filter className="w-4 h-4 text-gray-400" />
              <select 
                value={studentFilter} 
                onChange={(e) => setStudentFilter(e.target.value)}
                className="text-xs font-bold text-gray-600 outline-none bg-transparent"
              >
                <option value="">كل الطلاب</option>
                {sortedActiveStudents.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
              </select>
            </div>
            </div>
            <div className="grid sm:grid-cols-2 xl:grid-cols-4 gap-2">
              <select
                value={typeFilter}
                onChange={event => setTypeFilter(event.target.value as typeof typeFilter)}
                className="bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl px-4 py-3 text-xs font-bold"
              >
                <option value="all">الحفظ والمراجعة</option>
                <option value="memorization">الحفظ الجديد فقط</option>
                <option value="revision">المراجعة فقط</option>
              </select>
              <label className="flex items-center gap-2 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl px-3">
                <CalendarRange className="w-4 h-4 text-gray-400" />
                <input type="date" value={dateFrom} onChange={event => setDateFrom(event.target.value)} className="w-full bg-transparent py-3 text-xs" aria-label="من تاريخ" />
              </label>
              <label className="flex items-center gap-2 bg-white dark:bg-gray-900 border border-gray-200 dark:border-gray-800 rounded-xl px-3">
                <CalendarRange className="w-4 h-4 text-gray-400" />
                <input type="date" value={dateTo} onChange={event => setDateTo(event.target.value)} className="w-full bg-transparent py-3 text-xs" aria-label="إلى تاريخ" />
              </label>
              <button
                onClick={() => { setStudentFilter(""); setTypeFilter("all"); setDateFrom(""); setDateTo(""); }}
                className="rounded-xl bg-gray-100 dark:bg-gray-800 px-4 py-3 text-xs font-black text-gray-600 dark:text-gray-300"
              >
                مسح الفلاتر
              </button>
            </div>
          </div>

          {filteredGrades.length === 0 ? (
            <Surface>
              <EmptyState
                icon={BookOpen}
                title="لا توجد تقييمات مسجلة"
                description="سجّل أول تسميع، أو غيّر مرشحات الطالب والنوع والفترة."
              />
            </Surface>
          ) : (
            <div className="grid gap-6">
              {filteredGrades.map((grade) => {
                const badge = gradeBadges[grade.gradeMark];
                return (
                  <div 
                    key={grade.id} 
                    className="bg-white dark:bg-gray-900 rounded-3xl p-6 border border-gray-100 dark:border-gray-850 hover:border-teal-500/30 transition-all flex flex-col md:flex-row justify-between md:items-center gap-4 group"
                  >
                    <div className="space-y-3">
                      <div className="flex items-center gap-3">
                        <span className="font-black text-base text-gray-900 dark:text-white">
                          {getStudentName(grade.studentId)}
                        </span>
                        <span className={`text-[10px] px-3 py-1 rounded-full font-black ${badge.style}`}>
                          {badge.label}
                        </span>
                        <span className={`text-[10px] px-3 py-1 rounded-full font-black ${
                          grade.isRevision 
                            ? "bg-purple-100 text-purple-800 dark:bg-purple-900/20 dark:text-purple-400" 
                            : "bg-blue-100 text-blue-800 dark:bg-blue-900/20 dark:text-blue-400"
                        }`}>
                          {grade.isRevision ? "مراجعة" : "حفظ جديد"}
                        </span>
                      </div>
                      
                      <div className="text-xs font-bold text-gray-500 dark:text-gray-400 flex flex-wrap items-center gap-x-4 gap-y-1">
                        <span>📖 سورة {grade.surah} ({grade.fromAyah} - {grade.toAyah})</span>
                        {grade.gradeMark !== "absent" && (
                          <span className={grade.mistakesCount > 0 ? "text-rose-500 font-bold" : ""}>
                            ⚠️ الأخطاء: {grade.mistakesCount}
                          </span>
                        )}
                        <span>📅 {grade.date}</span>
                      </div>

                      {grade.remark && (
                        <p className="text-xs bg-gray-50 dark:bg-gray-800 text-gray-600 dark:text-gray-300 px-4 py-2 rounded-xl border-r-4 border-teal-500">
                          {grade.remark}
                        </p>
                      )}
                    </div>

                    <div className="flex items-center gap-2 self-end md:self-center">
                      <button
                        onClick={() => openEditForm(grade)}
                        className="bg-blue-50 hover:bg-blue-100 text-blue-700 dark:bg-blue-900/20 dark:text-blue-300 p-3 rounded-2xl transition-colors"
                        title="تعديل السجل"
                        aria-label="تعديل السجل"
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDelete(grade)}
                        className="bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-900/20 dark:text-rose-300 p-3 rounded-2xl transition-colors"
                        title="حذف السجل"
                        aria-label="حذف السجل"
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                      <button 
                        onClick={() => handleShareExisting(grade)}
                        className="bg-teal-50 hover:bg-teal-100 text-teal-700 dark:bg-teal-900/20 dark:hover:bg-teal-900/40 dark:text-teal-400 p-3 rounded-2xl text-xs font-bold flex items-center gap-2 transition-colors"
                        title="مشاركة النص"
                      >
                        <MessageCircle className="w-4 h-4" />
                        <span>مشاركة النص</span>
                      </button>
                      <button 
                        onClick={() => handleShareImage(grade)}
                        className="bg-amber-50 hover:bg-amber-100 text-amber-700 dark:bg-amber-900/20 dark:hover:bg-amber-900/40 dark:text-amber-400 p-3 rounded-2xl text-xs font-bold flex items-center gap-2 transition-colors"
                        title="مشاركة كصورة"
                      >
                        <Share2 className="w-4 h-4" />
                        <span>مشاركة كصورة</span>
                      </button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>

      {/* Entry Modal */}
      {showForm && (
        <div className="fixed inset-0 bg-gray-900/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
          <div className="bg-white dark:bg-gray-900 rounded-[3rem] p-10 w-full max-w-xl shadow-2xl relative overflow-y-auto max-h-[90vh] border border-gray-100 dark:border-gray-800">
            <button 
              onClick={resetForm}
              className="absolute top-8 left-8 p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-full transition-colors"
            >
              <X className="w-6 h-6 text-gray-400" />
            </button>
            <h3 className="text-2xl font-black text-gray-900 dark:text-white mb-8 text-center">
              {editingGrade ? "تعديل سجل التسميع" : "تسجيل تسميع جديد"}
            </h3>
            
            <form onSubmit={(e) => handleSave(e, false)} className="space-y-6">
              {/* Student */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">الطالب</label>
                <select 
                  value={formData.studentId} 
                  onChange={e => selectStudentForNewRecord(e.target.value)}
                  disabled={Boolean(editingGrade)}
                  required 
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                >
                  <option value="">اختر الطالب</option>
                  {sortedActiveStudents.map(s => <option key={s.id} value={s.id}>{s.name}</option>)}
                </select>
              </div>

              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">تاريخ التسميع</label>
                <input
                  type="date"
                  value={formData.date}
                  max={new Date().toISOString().slice(0, 10)}
                  onChange={event => setFormData({ ...formData, date: event.target.value })}
                  required
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                />
              </div>

              {/* Type Chip selector */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">نوع التسميع</label>
                {selectedStudentFinishedQuran && (
                  <div className="mb-3 flex items-center gap-2 text-[11px] font-black text-amber-700 dark:text-amber-400 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-900 rounded-xl px-4 py-2">
                    <CheckCircle className="w-4 h-4" />
                    أتم حفظ القرآن الكريم — المراجعة فقط
                  </div>
                )}
                <div className="grid grid-cols-2 gap-4">
                  <button
                    type="button"
                    disabled={selectedStudentFinishedQuran}
                    onClick={() => setFormData({ ...formData, isRevision: false })}
                    className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                      selectedStudentFinishedQuran ? "opacity-40 cursor-not-allowed" : ""
                    } ${
                      !formData.isRevision 
                        ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                        : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                    }`}
                  >
                    حفظ جديد
                  </button>
                  <button
                    type="button"
                    onClick={() => setFormData({ ...formData, isRevision: true })}
                    className={`py-3 rounded-xl font-bold text-xs border transition-all ${
                      formData.isRevision 
                        ? "bg-teal-50 border-teal-500 text-teal-800 dark:bg-teal-900/30 dark:border-teal-400 dark:text-teal-400"
                        : "border-gray-200 dark:border-gray-800 text-gray-500 hover:bg-gray-50 dark:hover:bg-gray-800"
                    }`}
                  >
                    مراجعة
                  </button>
                </div>
              </div>

              {/* Surah and Ayah Selection */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">السورة</label>
                  <select 
                    value={formData.surahNum} 
                    onChange={e => {
                      const num = parseInt(e.target.value);
                      const s = surahs.find(x => x.number === num);
                      setFormData({...formData, surahNum: num, fromAyah: 1, toAyah: s?.totalAyahs || 1});
                    }} 
                    required 
                    className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none"
                  >
                    <option value="">اختر السورة</option>
                    {surahs.map(s => <option key={s.number} value={s.number}>{s.name}</option>)}
                  </select>
                </div>
                <div className="flex gap-4">
                  <div className="flex-1">
                    <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">من آية</label>
                    <select 
                      value={formData.fromAyah} 
                      onChange={e => {
                        const val = parseInt(e.target.value);
                        setFormData({...formData, fromAyah: val, toAyah: Math.max(val, formData.toAyah)});
                      }} 
                      required 
                      className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 text-sm font-bold outline-none"
                    >
                      {Array.from({ length: selectedSurah?.totalAyahs || 0 }, (_, i) => i + 1).map(n => (
                        <option key={n} value={n}>{n}</option>
                      ))}
                    </select>
                  </div>
                  <div className="flex-1">
                    <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">إلى آية</label>
                    <select 
                      value={formData.toAyah} 
                      onChange={e => setFormData({...formData, toAyah: parseInt(e.target.value)})} 
                      required 
                      className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-4 py-4 text-sm font-bold outline-none"
                    >
                      {Array.from({ length: selectedSurah?.totalAyahs || 0 }, (_, i) => i + 1)
                        .filter(n => n >= formData.fromAyah)
                        .map(n => (
                        <option key={n} value={n}>{n}</option>
                      ))}
                    </select>
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <button
                  type="button"
                  onClick={() => setEndAtBoundary("page")}
                  disabled={!selectedSurah}
                  className="py-3 rounded-xl border border-teal-200 dark:border-teal-800 text-teal-700 dark:text-teal-300 font-bold text-xs disabled:opacity-40"
                >
                  إلى نهاية الصفحة
                </button>
                <button
                  type="button"
                  onClick={() => setEndAtBoundary("hizb")}
                  disabled={!selectedSurah}
                  className="py-3 rounded-xl border border-teal-200 dark:border-teal-800 text-teal-700 dark:text-teal-300 font-bold text-xs disabled:opacity-40"
                >
                  إلى نهاية الحزب
                </button>
              </div>

              {/* 5-Level Grade Mark */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">التقييم</label>
                <div className="grid grid-cols-5 gap-2">
                  {([
                    { key: "excellent", label: "ممتاز", style: "bg-emerald-500 hover:bg-emerald-600 text-white" },
                    { key: "very_good", label: "جيد جداً", style: "bg-green-500 hover:bg-green-600 text-white" },
                    { key: "good", label: "جيد", style: "bg-amber-500 hover:bg-amber-600 text-white" },
                    { key: "needs_work", label: "مقبول", style: "bg-orange-500 hover:bg-orange-600 text-white" },
                    { key: "absent", label: "غائب", style: "bg-rose-500 hover:bg-rose-600 text-white" }
                  ] satisfies Array<{
                    key: HomeworkGrade["gradeMark"];
                    label: string;
                    style: string;
                  }>).map(item => {
                    const isSelected = formData.gradeMark === item.key;
                    return (
                      <button
                        key={item.key}
                        type="button"
                        onClick={() => setFormData({ ...formData, gradeMark: item.key })}
                        className={`py-3 rounded-xl font-black text-[11px] transition-all border ${
                          isSelected 
                            ? `${item.style} border-transparent shadow-lg shadow-black/10 scale-[1.03]`
                            : "bg-gray-50 dark:bg-gray-800 border-gray-100 dark:border-gray-800 text-gray-600 dark:text-gray-400 hover:bg-gray-100"
                        }`}
                      >
                        {item.label}
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Mistakes Counter */}
              {formData.gradeMark !== "absent" && (
                <div>
                  <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">عدد الأخطاء</label>
                  <div className="flex items-center gap-4">
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, mistakesCount: Math.max(0, formData.mistakesCount - 1) })}
                      className="text-teal-600 hover:text-teal-700 dark:text-teal-400 transition-colors"
                    >
                      <MinusCircle className="w-8 h-8" />
                    </button>
                    <span className="text-lg font-black w-8 text-center text-gray-900 dark:text-white">
                      {formData.mistakesCount}
                    </span>
                    <button
                      type="button"
                      onClick={() => setFormData({ ...formData, mistakesCount: formData.mistakesCount + 1 })}
                      className="text-teal-600 hover:text-teal-700 dark:text-teal-400 transition-colors"
                    >
                      <PlusCircle className="w-8 h-8" />
                    </button>
                  </div>
                </div>
              )}

              {/* Remark */}
              <div>
                <label className="block text-xs font-black text-gray-400 mb-2 mr-1 uppercase tracking-widest">ملاحظات</label>
                <textarea 
                  value={formData.remark} 
                  onChange={e => setFormData({...formData, remark: e.target.value})} 
                  rows={2} 
                  placeholder="ملاحظات حول الأداء ومخارج الحروف..."
                  className="w-full bg-gray-50 dark:bg-gray-800 border-none rounded-2xl px-6 py-4 text-sm font-bold outline-none" 
                />
              </div>

              {/* Action Buttons */}
              <div className="grid grid-cols-1 md:grid-cols-2 gap-4 pt-4 border-t border-gray-50 dark:border-gray-800">
                <button 
                  type="submit" 
                  disabled={saving}
                  className="w-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-800 dark:hover:bg-gray-750 text-gray-800 dark:text-white py-5 rounded-[2rem] font-black text-xs transition-all flex items-center justify-center gap-2"
                >
                  {saving ? "جاري الحفظ…" : editingGrade ? "حفظ التعديل" : "حفظ التسميع"}
                </button>
                <button 
                  type="button"
                  onClick={(e) => handleSave(e, true)}
                  disabled={saving}
                  className="w-full bg-teal-600 hover:bg-teal-700 text-white py-5 rounded-[2rem] font-black text-xs transition-all flex items-center justify-center gap-2 shadow-lg shadow-teal-100 dark:shadow-none"
                >
                  <MessageCircle className="w-4 h-4" />
                  {editingGrade ? "حفظ التعديل وإرساله" : "حفظ وإرسال لولي الأمر"}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
