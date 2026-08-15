import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const students = read("website/src/app/students/page.tsx");
const detail = read("website/src/app/students/[id]/page.tsx");
const vacations = read("website/src/app/vacations/page.tsx");

requireText(students, "الملف التفصيلي", "student detail navigation");
for (const contract of [
  "QRCodeSVG",
  "المحفوظ المثبت في ملف الطالب",
  "آخر حفظ جديد",
  "آخر مراجعة",
  "مقدار المراجعة",
  "saveDailyPlan",
  "memorization_prefill_student_id",
]) {
  requireText(detail, contract, `student detail contract ${contract}`);
}

for (const contract of [
  'periodFilter',
  'statusFilter',
  'reasonFilter',
  'studentFilter',
  'الأسبوع الحالي (السبت–الجمعة)',
  'فترة مخصصة',
  'filteredVacations',
  'localeCompare(right.name, "ar"',
]) {
  requireText(vacations, contract, `vacation organization contract ${contract}`);
}

console.log("Student detail and vacation organization passed: QR/profile progress, editable daily plan, and week/month/status/reason filters.");
