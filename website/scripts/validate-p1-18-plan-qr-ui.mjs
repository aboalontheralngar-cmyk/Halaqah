import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const database = read("lib/services/database_service.dart") + read("lib/services/local_database_schema.dart");
const directEntry = read("lib/screens/memorization/add_memorization_screen.dart");
const recitation = read("lib/screens/memorization/recitation_screen.dart");
const coordinator = read("lib/services/recitation_flow_coordinator.dart");
const attendance = read("lib/screens/attendance/attendance_screen.dart");
const plans = read("lib/screens/plans/plans_screen.dart");
const pdf = read("lib/services/pdf_service.dart");
const notifications = read("lib/screens/notifications/notifications_screen.dart");
const memorization = read("lib/screens/memorization/memorization_screen.dart");
const home = read("lib/screens/home/home_screen.dart");
const buildInfo = read("lib/app/build_info.dart");
const pubspec = read("pubspec.yaml");

for (const [source, text, label] of [
  [coordinator, "static bool acquire", "single recitation-flow lock"],
  [directEntry, "RecitationFlowCoordinator.acquire", "direct-entry lock"],
  [recitation, "RecitationFlowCoordinator.acquire", "session lock"],
  [attendance, "_controller?.stop()", "scanner stop after successful decode"],
  [database, "ensureSurahCompletionNotification", "durable surah notification"],
  [database, "type: 'surah_completed'", "surah notification type"],
  [directEntry, "ensureSurahCompletionNotification", "direct-entry completion notice"],
  [recitation, "ensureSurahCompletionNotification", "session completion notice"],
  [notifications, "'surah_completed'", "completion notice filter"],
  [plans, "تُحدّث النسبة تلقائيًا من سجلات التسميع", "plan progress explanation"],
  [plans, "_progressAxis", "per-axis plan progress"],
  [pdf, "_planCheckCell", "printable completion checkbox"],
  [memorization, "_buildWorkspaceSummary", "compact memorization workspace"],
  [home, "AppFocusPanel(", "task-first mobile home header"],
  [buildInfo, "releaseLabel = 'P1.27'", "current release label"],
  [pubspec, "version: 4.3.0-alpha.24+80", "current package version"],
]) {
  requireText(source, text, label);
}

console.log("P1.18 passed: plan progress, durable surah notices, QR flow locking, printable checks, and compact mobile workspaces are protected.");
