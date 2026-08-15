import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const policy = read("lib/services/student_learning_policy.dart");
const memorization = read("lib/screens/memorization/memorization_screen.dart");
const plans = read("lib/screens/plans/plans_screen.dart");
const schedule = read("lib/services/smart_plan_schedule_service.dart");
const progress = read("lib/services/plan_progress_service.dart");
const pdf = read("lib/services/pdf_service.dart");
const closing = read("lib/services/daily_closing_service.dart");
const home = read("lib/screens/home/home_screen.dart");
const revision = read("lib/screens/memorization/revision_screen.dart");
const webPlans = read("website/src/app/plans/page.tsx");
const buildInfo = read("lib/app/build_info.dart");
const pubspec = read("pubspec.yaml");

for (const [source, text, label] of [
  [policy, "student.status == 'graduated'", "graduated-status policy"],
  [policy, "QuranData.totalAyahs", "completed-Quran total policy"],
  [policy, "canReceiveNewMemorization", "new memorization eligibility"],
  [memorization, "_db.getStudents(status: 'graduated')", "graduates in revision source"],
  [memorization, "StudentLearningPolicy.canReceiveNewMemorization", "graduates excluded from new memorization"],
  [plans, "الخطة مخصصة للمراجعة والسرد/التلاوة فقط", "revision-only plan form"],
  [plans, "includeMemorization: !revisionOnly", "revision-only achievement UI"],
  [schedule, "memorizationRange: revisionOnly", "revision-only exact schedule"],
  [progress, "requiredMemorization: StudentLearningPolicy.hasCompletedQuran", "zero graduate memorization requirement"],
  [progress, "_requiredRatios", "active-stream accomplishment percentage"],
  [pdf, "if (!revisionOnly)", "memorization-free graduate PDF"],
  [closing, "closeOverdueDays", "automatic overdue close"],
  [closing, "daily_operations_close_mode_", "automatic close audit mode"],
  [closing, "student.joinDate", "join-date-safe automatic close"],
  [home, "_scheduleAutomaticDailyClosing", "midnight close timer"],
  [home, "_buildCompactStat", "compact home metrics"],
  [revision, "_buildWorkspaceHeader", "revision selection workspace"],
  [revision, "ابحث باسم السورة أو رقمها", "revision Surah search"],
  [revision, "bottomNavigationBar", "safe persistent revision action"],
  [webPlans, 'student.status === "graduated"', "web graduate plan parity"],
  [buildInfo, "releaseLabel = 'P1.27'", "central current release label"],
  [pubspec, "version: 4.3.0-alpha.22+76", "current package version"],
]) {
  requireText(source, text, label);
}

console.log("P1.17 passed: graduate learning paths, automatic daily close, compact home, and revision workspace are protected.");
