import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (path, fragments) => {
  const source = path === "lib/services/database_service.dart"
    ? read(path) + read("lib/services/local_database_schema.dart")
    : read(path);
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`P1.20 missing ${fragment} in ${path}`);
    }
  }
};

requireAll("pubspec.yaml", [
  "version: 4.3.0-alpha.24+80",
  "family: Tajawal",
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
]);
requireAll("lib/app/build_info.dart", [
  "4.3.0-alpha.24",
  "buildNumber = 80",
  "releaseLabel = 'P1.27'",
]);

requireAll("lib/widgets/app_design_widgets.dart", [
  "class AppCompactActionGrid",
  "class AppCompactActionTile",
  "final columns",
  "width >= 390",
]);
requireAll("lib/screens/home/home_screen.dart", [
  "AppCompactActionGrid",
  "CompetitionsScreen",
  "OfflineExchangeScreen",
  "انضم إلى الخدمة السحابية مجانًا",
]);
requireAll("lib/screens/memorization/recitation_history_screen.dart", [
  "الاسم أو كود الطالب أو السورة",
  "_normalizeSearch",
]);
requireAll("lib/screens/reports/reports_screen.dart", [
  "HalaqahPeriodReportScreen",
  "StudentPeriodReportScreen",
  "StudentReceiptScreen",
  "initialPeriod:",
  "_buildDashboard",
  "لوحة أداء الحلقة",
]);
requireAll("lib/services/database_service.dart", [
  "reconcileStudentMemorizedTotal",
  "_setExactStudentMemorizedTotal",
  "_upgradeToVersion21",
  "competition_events",
  "mergeFromBackup",
  "اختبار التجاوز",
]);

requireAll("lib/services/revision_system_policy.dart", [
  "adaptive_spaced",
  "five_day_stabilization",
  "sabaq_sabqi_manzil",
  "teacher_custom",
]);
requireAll("lib/screens/memorization/revision_screen.dart", [
  "RevisionSystemPolicy",
  "MandatoryRevisionScheduleService.chunkForDay",
  "mandatoryFromPage",
  "five_day_stabilization",
  "preserveInputOrder",
]);

for (const path of [
  "lib/models/competition.dart",
  "lib/services/competition_scoring_service.dart",
  "lib/screens/competition/competitions_screen.dart",
  "lib/screens/competition/competition_judge_screen.dart",
]) {
  if (!existsSync(resolve(root, path))) throw new Error(`P1.20 missing ${path}`);
}
requireAll("lib/services/competition_scoring_service.dart", [
  "obviousErrorDeduction = 3",
  "subtleErrorDeduction = 1",
  "promptDeduction = 4",
  "stopDeduction = 2",
  "tajweedErrorDeduction = 0.5",
]);
requireAll("lib/screens/competition/competition_judge_screen.dart", [
  "ExamGeneratorScreen",
  "التحكيم",
  "النتائج",
]);

requireAll("lib/screens/settings/offline_exchange_screen.dart", [
  "OfflineExchangePolicy",
  "exportDeviceExchange",
  "Share.shareXFiles",
  "mergeBackup",
  "كود الربط",
]);
requireAll("android/app/src/main/kotlin/com/example/halaqah_teacher/MainActivity.kt", [
  "halaqah/offline_exchange",
  "ACTION_OPEN_DOCUMENT",
  "openExchangeFilePicker",
  "pickHalaqahFile",
]);
requireAll("android/app/build.gradle.kts", [
  "minSdk = 23",
  "isMinifyEnabled = true",
  "isShrinkResources = true",
  "proguard-rules.pro",
]);
requireAll("tools/build_lean_android.ps1", [
  "--split-per-abi",
  "--obfuscate",
  "--split-debug-info",
]);
requireAll("lib/services/activation_policy_service.dart", [
  "activationRequired = false",
  "isAccessAllowed => true",
]);

requireAll("website/src/app/portal/page.tsx", [
  "recentBehavior",
  "unresolvedViolations",
  "60_000",
  "السلوك والتنبيهات",
]);
requireAll("website/src/app/supervision/page.tsx", [
  "supervision_visits",
  "createVisit",
  "updateVisitStatus",
  "التوجيه والزيارات الإشرافية",
]);
requireAll(
  "website/supabase/migrations/20260727000100_p1_20_portal_supervision.sql",
  [
    "review_system",
    "CREATE TABLE IF NOT EXISTS public.supervision_visits",
    "current_user_can_manage_supervisor",
    "unresolved_violations",
    "recent_behavior",
  ],
);
requireAll("website/src/app/layout.tsx", [
  "@fontsource/readex-pro/400.css",
  "@fontsource/readex-pro/700.css",
]);

console.log(
  "P1.20 passed: compact work grid, reports, exact progress, revision systems, competitions, offline exchange, portals, supervision, lean Android, and unified typography are protected.",
);
