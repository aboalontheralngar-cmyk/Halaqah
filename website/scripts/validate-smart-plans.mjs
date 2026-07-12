import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const model = read("lib/models/plan.dart");
const database = read("lib/services/database_service.dart");
const mobile = read("lib/screens/plans/plans_screen.dart");
const pdf = read("lib/services/pdf_service.dart");
const sync = read("lib/services/supabase_service.dart");
const web = read("website/src/app/plans/page.tsx");
const store = read("website/src/store/useStore.ts");
const sql = read("website/supabase/migrations/20260712000100_p5_smart_plans.sql");

for (const field of ["testStatus", "completionExamId", "completedAt", "updatedAt"]) {
  requireText(model, field, `plan model field ${field}`);
}
for (const contract of [
  "getSmartPlanGateReason",
  "completeSmartPlan",
  "approveSmartPlanExam",
  "deleted_plan_ids",
  "_applyPlanAsStudentDefault",
]) {
  requireText(database, contract, `database contract ${contract}`);
}
for (const contract of [
  "إكمال وطلب اختبار تجاوز",
  "اعتماد اختبار التجاوز",
  "طباعة كاشير 80مم",
  "_AmountStepper",
]) {
  requireText(mobile, contract, `mobile plans UI ${contract}`);
}
requireText(pdf, "generateSmartPlan", "plan PDF generator");
requireText(pdf, "80 * PdfPageFormat.mm", "80mm receipt format");
for (const contract of ["test_status", "completion_exam_id", "deleted_at"]) {
  requireText(sql, contract, `SQL column ${contract}`);
}
requireText(sql, "previous_plan_requires_passing_exam", "cloud plan gate");
requireText(sql, "invalid_or_early_completion_exam", "cloud exam verification");
requireText(sql, "CREATE OR REPLACE FUNCTION public.current_user_can_access_halaqa", "self-contained scope helper");
requireText(sql, "TO authenticated", "scope helper execute grant");
requireText(sync, "deleteSmartPlanFromSync", "soft deletion pull");
requireText(sync, "plan.updatedAt.isAfter", "newest plan wins sync");
for (const contract of ["fetchPlans", "addSmartPlan", "updateSmartPlan", "deleteSmartPlan"]) {
  requireText(store, contract, `persistent web store ${contract}`);
}
requireText(web, "fetchPlans", "web plans loading");
requireText(web, "كاشير 80مم", "web receipt printing");
requireText(web, "اعتماد اختبار التجاوز", "web exam approval");

console.log("Smart plans contract passed: persistence, steppers, exam gate, sync, and printing.");
