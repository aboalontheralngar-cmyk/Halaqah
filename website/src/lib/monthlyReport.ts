import type { Student, AttendanceRecord, HomeworkGrade, PointRecord } from "@/store/useStore";

const GRADE_LABEL: Record<string, string> = {
  excellent: "ممتاز",
  very_good: "جيد جداً",
  good: "جيد",
  needs_work: "يحتاج مراجعة",
  absent: "غائب",
};

const GRADE_SCORE: Record<string, number> = {
  excellent: 5,
  very_good: 4,
  good: 3,
  needs_work: 2,
};

const ARABIC_MONTHS = [
  "يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو",
  "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر",
];

export interface MonthlyReportInput {
  student: Student;
  /** المفتاح بصيغة YYYY-MM */
  month: string;
  attendance: AttendanceRecord[];
  grades: HomeworkGrade[];
  points: PointRecord[];
  suspendedDates?: string[];
  centerName?: string;
  centerType?: "men" | "women" | "mixed";
}

/** يحوّل الرقم لنجوم تقييم */
function stars(avg: number): string {
  const full = Math.round(avg);
  return "⭐".repeat(Math.max(0, Math.min(5, full)));
}

/** يبني نص تقرير شهري منسّق لإرساله عبر واتساب لولي الأمر */
export function buildMonthlyReportMessage(input: MonthlyReportInput): string {
  const { student, month, suspendedDates = [], centerName } = input;
  const [yearStr, monthStr] = month.split("-");
  const monthIndex = parseInt(monthStr, 10) - 1;
  const monthLabel = `${ARABIC_MONTHS[monthIndex] ?? monthStr} ${yearStr}`;

  const inMonth = (date: string) => date.startsWith(month) && !suspendedDates.includes(date);

  // الحضور
  const att = input.attendance.filter(a => a.studentId === student.id && inMonth(a.date));
  const presentDays = att.filter(a => a.status === "present" || a.status === "late").length;
  const excusedDays = att.filter(a => a.status === "excused").length;
  const absentDays = att.filter(a => a.status === "absent").length;
  const lateDays = att.filter(a => a.status === "late").length;
  const totalDays = att.length;
  const attendancePct = totalDays > 0 ? Math.round((presentDays / totalDays) * 100) : 0;

  // التسميع والمراجعة
  const grades = input.grades.filter(g => g.studentId === student.id && inMonth(g.date));
  const memo = grades.filter(g => !g.isRevision && g.gradeMark !== "absent");
  const revision = grades.filter(g => g.isRevision && g.gradeMark !== "absent");
  const graded = grades.filter(g => g.gradeMark !== "absent");
  const avgScore = graded.length > 0
    ? graded.reduce((s, g) => s + (GRADE_SCORE[g.gradeMark] || 3), 0) / graded.length
    : 0;
  const avgMistakes = graded.length > 0
    ? (graded.reduce((s, g) => s + (g.mistakesCount || 0), 0) / graded.length).toFixed(1)
    : "0";

  // أفضل تقدير متكرر (الأكثر تكراراً خلال الشهر)
  let bestGrade = "—";
  if (graded.length > 0) {
    const counts: Record<string, number> = {};
    for (const g of graded) counts[g.gradeMark] = (counts[g.gradeMark] || 0) + 1;
    const topMark = Object.entries(counts).sort((a, b) => b[1] - a[1])[0][0];
    bestGrade = GRADE_LABEL[topMark] ?? "—";
  }

  // النقاط
  const pts = input.points.filter(p => p.studentId === student.id && inMonth(p.date));
  const positive = pts.filter(p => p.amount > 0).reduce((s, p) => s + p.amount, 0);
  const negative = pts.filter(p => p.amount < 0).reduce((s, p) => s + p.amount, 0);
  const netPoints = positive + negative;

  const greeting = (input.centerType === "women") ? "ابنتكم" : "ابنكم";

  const lines: string[] = [];
  lines.push(`🕌 *تقرير شهر ${monthLabel}*`);
  if (centerName) lines.push(`📚 ${centerName}`);
  lines.push("");
  lines.push(`السلام عليكم ورحمة الله وبركاته 🌿`);
  lines.push(`نوافيكم بتقرير أداء ${greeting} *${student.name}* لهذا الشهر:`);
  lines.push("");
  lines.push(`📅 *الحضور والمواظبة:*`);
  lines.push(`✅ أيام الحضور: ${presentDays}`);
  if (lateDays > 0) lines.push(`⏰ أيام التأخر: ${lateDays}`);
  lines.push(`📝 أيام الاستئذان: ${excusedDays}`);
  lines.push(`❌ أيام الغياب: ${absentDays}`);
  lines.push(`📊 نسبة الحضور: ${attendancePct}%`);
  lines.push("");
  lines.push(`📖 *الحفظ والمراجعة:*`);
  lines.push(`🆕 جلسات الحفظ الجديد: ${memo.length}`);
  lines.push(`🔄 جلسات المراجعة: ${revision.length}`);
  lines.push(`🎯 متوسط التقييم: ${stars(avgScore)} (${bestGrade})`);
  lines.push(`✏️ متوسط الأخطاء بالجلسة: ${avgMistakes}`);
  lines.push("");
  lines.push(`🏆 *النقاط السلوكية:*`);
  lines.push(`➕ نقاط إيجابية: ${positive}`);
  lines.push(`➖ نقاط سلبية: ${negative}`);
  lines.push(`💯 الصافي: ${netPoints}`);
  lines.push("");

  // رسالة ختامية حسب الأداء
  if (attendancePct >= 90 && avgScore >= 4) {
    lines.push(`🌟 أداء متميز، بارك الله فيه وزاده توفيقاً.`);
  } else if (attendancePct >= 70) {
    lines.push(`👍 أداء جيد، نتطلع لمزيد من المواظبة والتميز.`);
  } else {
    lines.push(`🤝 نأمل تعزيز المواظبة، ونسعد بتعاونكم لرفع المستوى.`);
  }
  lines.push("");
  lines.push(`جزاكم الله خيراً على متابعتكم 🌹`);

  return lines.join("\n");
}

/** ينظّف رقم الهاتف لصيغة دولية صالحة لرابط wa.me */
export function normalizePhoneForWhatsApp(phone: string, defaultCountryCode = "966"): string {
  const p = (phone || "").replace(/[^\d+]/g, "");
  if (p.startsWith("+")) return p.slice(1);
  if (p.startsWith("00")) return p.slice(2);
  if (p.startsWith("0")) return defaultCountryCode + p.slice(1);
  if (p.startsWith(defaultCountryCode)) return p;
  return p;
}

/** يبني رابط واتساب جاهز للإرسال */
export function buildWhatsAppLink(phone: string, message: string): string {
  const num = normalizePhoneForWhatsApp(phone);
  return `https://wa.me/${num}?text=${encodeURIComponent(message)}`;
}
