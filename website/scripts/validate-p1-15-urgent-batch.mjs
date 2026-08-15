import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const planModel = read("lib/models/plan.dart");
const planScreen = read("lib/screens/plans/plans_screen.dart");
const planProgress = read("lib/services/plan_progress_service.dart");
const reviewPolicy = read("lib/services/review_plan_policy.dart");
const reportModel = read("lib/models/student_period_report.dart");
const behaviorModel = read("lib/models/behavior_point.dart");
const reportService = read("lib/services/student_period_report_service.dart");
const reportPdf = read("lib/services/pdf_service.dart");
const attendance = read("lib/screens/attendance/attendance_screen.dart");
const notifications = read("lib/screens/notifications/notifications_screen.dart");
const fundModel = read("lib/models/fund_transaction.dart");
const fundScreen = read("lib/screens/fund/fund_screen.dart");
const cloudSql = read("website/supabase/migrations/20260722000300_p1_15_urgent_plans_reports.sql");
const webPlan = read("website/src/app/plans/page.tsx");
const webStore = read("website/src/store/useStore.ts");

for (const [source, text, label] of [
  [planModel, "recitationAmount", "mobile recitation plan field"],
  [planScreen, "الخطة منجزة حسابيًا", "calculated plan completion"],
  [planScreen, "الأسبوع القادم", "next-week scheduling"],
  [planScreen, "ReviewPlanPolicy.recommend", "review recommendation"],
  [planProgress, "isAccomplished", "plan accomplishment rule"],
  [planProgress, "reviewByDay", "daily periodic review accounting"],
  [reviewPolicy, "دورة تقارب 30 يومًا", "review cycle policy"],
  [reportModel, "totalLateMinutes", "late time aggregate"],
  [reportModel, "periodRank", "top-three rank"],
  [behaviorModel, "isAttendancePenalty", "attendance penalty classification"],
  [reportService, "_withTopThreeRanks", "ranking calculation"],
  [reportService, "getStudentFundTransactionsInRange", "period-scoped settlements"],
  [reportPdf, "الفصل الإداري للحضور والمخالفات", "separated PDF sections"],
  [reportPdf, "تقييم الحفظ", "daily memorization rating"],
  [reportPdf, "تُصرف لصالح أنشطة وفعاليات الحلقة", "penalty purpose notice"],
  [attendance, "_showQrQuickActions", "QR action hub"],
  [attendance, "effectiveAttendance", "automatic late status"],
  [notifications, "الحضور والغياب", "notification filters"],
  [fundModel, "settledNegativePoints", "negative settlement field"],
  [fundScreen, "الرصيد السلبي غير المسوّى", "fund settlement UI"],
  [cloudSql, "recitation_amount", "cloud recitation column"],
  [cloudSql, "settled_negative_points", "cloud settlement column"],
  [webPlan, "السرد/التلاوة اليومية", "web recitation plan UI"],
  [webStore, "recitation_amount", "web recitation persistence"],
]) {
  requireText(source, text, label);
}

console.log("P1.15 urgent batch contract passed: plans, reports, QR, notifications, points, and fund settlements.");
