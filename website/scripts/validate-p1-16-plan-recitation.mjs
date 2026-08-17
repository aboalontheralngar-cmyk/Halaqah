import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const model = read("lib/models/plan_recitation_record.dart");
const database = read("lib/services/database_service.dart") + read("lib/services/local_database_schema.dart");
const progress = read("lib/services/plan_progress_service.dart");
const screen = read("lib/screens/plans/plan_recitation_screen.dart");
const plansScreen = read("lib/screens/plans/plans_screen.dart");
const sync = read("lib/services/supabase_service.dart");
const migration = read("website/supabase/migrations/20260722000400_p1_16_plan_recitation_tracking.sql");
const verification = read("website/supabase/verification/20260722000400_p1_16_plan_recitation_tracking_readiness.sql");
const setupWeb = read("tools/setup_web.ps1");
const vscode = read(".vscode/settings.json");
const schedule = read("lib/services/smart_plan_schedule_service.dart");
const pdf = read("lib/services/pdf_service.dart");
const buildInfo = read("lib/app/build_info.dart");
const pubspec = read("pubspec.yaml");
const reports = read("lib/screens/reports/reports_screen.dart");
const helpers = read("lib/utils/helpers.dart");
const main = read("lib/main.dart");
const webWorkspaceSettings = read("website/.vscode/settings.json");
const windowsSetup = read("SETUP_WEB_WINDOWS.cmd");
const dashboardLayout = read("website/src/components/DashboardLayout.tsx");

for (const [source, text, label] of [
  [model, "class PlanRecitationRecord", "dedicated recitation model"],
  [model, "sessionId", "cross-surah session grouping"],
  [database, "static const int version = 27", "SQLite schema upgrade"],
  [database, "savePlanRecitationSession", "atomic local session save"],
  [database, "getStudentPlanRecitationRecords", "cross-plan recitation continuation"],
  [database, "deleted_plan_recitation_record_ids", "cloud deletion tombstones"],
  [progress, "requiredRecitation", "third plan requirement"],
  [progress, "actualRecitation", "measured recitation achievement"],
  [progress, "recitationRatio >= 1", "plan accomplishment gate"],
  [screen, "لا يزيد محفوظ الطالب", "clear non-memorization policy"],
  [screen, "اعتماد السرد إلى نهاية المقرر", "teacher completion action"],
  [plansScreen, "تسجيل السرد وعرض الجلسات", "plan entry point"],
  [sync, "_syncPlanRecitationRecords", "bidirectional cloud sync"],
  [migration, "plan_recitation_records", "cloud table"],
  [migration, "validate_plan_recitation_record", "scope and date guard"],
  [migration, "enable row level security", "cloud RLS"],
  [verification, "plan_recitation_scope_trigger", "readiness verification"],
  [schedule, "class SmartPlanDailyAssignment", "daily Quran assignment model"],
  [schedule, "MemorizationProgressionService.nextStartingPoint", "memorization continuation"],
  [schedule, "RevisionProgressionService.nextStartingPoint", "revision continuation"],
  [schedule, "class _PlanCalendarDay", "complete calendar-day schedule"],
  [schedule, "إجازة أسبوعية", "explicit weekly holiday row"],
  [schedule, "سورة ${_quran.getSurahName", "explicit surah and ayah labels"],
  [pdf, "dailyAssignmentsByPlan", "bulk exact-range PDF"],
  [pdf, "SmartPlanPrintPolicy.validateExactAssignments", "no generic amount fallback"],
  [pdf, "assignment.recitationRange", "printed recitation Quran range"],
  [reports, "DropdownButtonFormField<String>", "stable Hijri month dropdown value"],
  [helpers, "rangesByKey.putIfAbsent", "deduplicated Hijri month choices"],
  [main, "_runNonCriticalStartupTask", "nonfatal optional startup services"],
  [main, "return previousPlatformHandler?.call(error, stackTrace) ?? true", "contained runtime incidents"],
  [setupWeb, "-Command $npmCommand -Arguments @('ci')", "Windows dependency recovery"],
  [setupWeb, "node_modules/react/package.json", "React installation verification"],
  [setupWeb, "node_modules/typescript/lib/tsserver.js", "TypeScript server verification"],
  [windowsSetup, "setup_web.ps1", "double-click Windows setup launcher"],
  [vscode, "website/node_modules/typescript/lib", "workspace TypeScript SDK"],
  [webWorkspaceSettings, "node_modules/typescript/lib", "website-folder TypeScript SDK"],
  [dashboardLayout, "type NavigationItem", "explicit navigation typing"],
  [dashboardLayout, "children: ReactNode", "React namespace-independent child typing"],
  [buildInfo, "releaseLabel = 'P1.27'", "central current release label"],
  [pubspec, "version: 4.3.0-alpha.26+83", "current package version"],
]) {
  requireText(source, text, label);
}

if (pdf.includes("assignment?.memorizationRange ??") || pdf.includes("assignment?.reviewRange ??")) {
  throw new Error("Smart-plan PDF must not fall back to generic daily amounts");
}

console.log("P1.16.2 passed: exact Quran plans and recoverable Windows web dependencies are protected end to end.");
