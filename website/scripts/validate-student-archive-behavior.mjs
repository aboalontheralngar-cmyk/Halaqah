import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const database = read("lib/services/database_service.dart");
const archive = read("lib/screens/students/student_archive_screen.dart");
const students = read("lib/screens/students/students_screen.dart");
const details = read("lib/screens/students/student_detail_screen.dart");
const addPoint = read("lib/screens/behavior/add_point_screen.dart");
const pointHistory = read("lib/screens/behavior/points_history_screen.dart");
const violations = read("lib/screens/behavior/appearance_violations_screen.dart");
const sync = read("lib/services/supabase_service.dart");
const webStudents = read("website/src/app/students/page.tsx");
const webPoints = read("website/src/app/points/page.tsx");
const store = read("website/src/store/useStore.ts");
const migration = read("website/supabase/migrations/20260712000200_p5_student_archive_behavior_audit.sql");
const behaviorTest = read("test/behavior_point_policy_test.dart");
const statusTest = read("test/student_status_policy_test.dart");

for (const contract of [
  "version: 18",
  "CREATE TABLE IF NOT EXISTS student_status_history",
  "CREATE TABLE IF NOT EXISTS behavior_point_corrections",
  "getOperationalStudents",
  "getArchivedStudents",
  "changeStudentStatus",
  "reassignBehaviorPoint",
  "deleted_behavior_point_ids",
]) {
  requireText(database, contract, `SQLite contract ${contract}`);
}

for (const contract of [
  "أرشيف الطلاب",
  "إعادة تفعيل",
  "سجل الحالة",
  "سبب إعادة التفعيل (إلزامي)",
]) {
  requireText(archive, contract, `archive UI contract ${contract}`);
}
requireText(students, "getOperationalStudents", "operational student list");
requireText(students, "StudentArchiveScreen", "archive navigation");
requireText(details, "AddPointScreen(student: _student)", "single point-entry path");
if (details.includes("class _AddPointsSheet")) {
  throw new Error("Legacy point-entry sheet still bypasses the centralized confirmation screen");
}
requireText(addPoint, "تأكيد إسناد النقاط", "point assignment confirmation");
requireText(addPoint, "ولي الأمر", "student identity disambiguation");
requireText(pointHistory, "reassignBehaviorPoint", "point reassignment correction");
requireText(pointHistory, "سبب التصحيح (إلزامي)", "mandatory correction reason");
requireText(violations, "recordedPenalty", "recorded violation amount");
if (violations.includes("(daysCount + 1) * 3")) {
  throw new Error("Violation UI still shows an unpersisted daily multiplier");
}

requireText(sync, "'amount': e.points", "signed point sync");
requireText(sync, "deleted_behavior_point_ids", "cloud deletion tombstone");
requireText(sync, "behavior_point_corrections", "correction audit sync");
requireText(webStudents, "statusView", "web current/archive split");
requireText(webStudents, "changeStudentStatus", "web status RPC wiring");
requireText(webPoints, "confirmPointRegistration", "web identity confirmation");
requireText(webPoints, "submitCorrection", "web point correction UI");
requireText(store, "reassign_behavior_point", "web reassignment RPC");
requireText(store, "delete_behavior_point_with_audit", "web audited delete RPC");

for (const contract of [
  "CREATE TABLE IF NOT EXISTS public.student_status_history",
  "CREATE TABLE IF NOT EXISTS public.behavior_point_corrections",
  "CREATE OR REPLACE FUNCTION public.change_student_status",
  "CREATE OR REPLACE FUNCTION public.reassign_behavior_point",
  "CREATE OR REPLACE FUNCTION public.delete_behavior_point_with_audit",
  "ADD COLUMN IF NOT EXISTS halaqa_id",
  "current_user_can_access_halaqa",
  "UPDATE public.points SET amount = -ABS(amount)",
]) {
  requireText(migration, contract, `Supabase migration contract ${contract}`);
}

requireText(behaviorTest, "rejects sign mismatch and archived students", "point policy regression test");
requireText(statusTest, "separates operational and archived statuses", "status policy regression test");

console.log("Student archive/behavior contract passed: archive, status audit, identity confirmation, correction trail, signed sync, and scoped SQL.");
