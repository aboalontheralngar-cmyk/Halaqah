import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const manifest = read("pubspec.yaml");
const main = read("lib/main.dart");
const scheduler = read("lib/services/background_backup_scheduler.dart");
const policy = read("lib/services/backup_policy_service.dart");
const policyTest = read("test/backup_policy_service_test.dart");
const settings = read("lib/screens/settings/settings_screen.dart");
const diagnostics = read("lib/services/diagnostic_center_service.dart");
const androidBuild = read("android/app/build.gradle.kts");
const iosProject = read("ios/Runner.xcodeproj/project.pbxproj");

requireText(manifest, "workmanager: 0.9.0+3", "WorkManager dependency");
requireText(
  main,
  "BackgroundBackupScheduler.initializeAndSynchronize()",
  "startup scheduling",
);

for (const contract of [
  "@pragma('vm:entry-point')",
  "Workmanager().executeTask",
  "registerPeriodicTask",
  "cancelByUniqueName",
  "isScheduledByUniqueName",
  "frequency: const Duration(hours: 24)",
  "performAutomaticBackupIfDue",
  "last_background_backup_worker_at",
  "last_background_backup_worker_status",
  "last_background_backup_scheduler_error",
]) {
  requireText(scheduler, contract, `background scheduler contract ${contract}`);
}

requireText(
  policy,
  "delayUntilNextScheduledHour",
  "pure scheduling policy",
);
requireText(
  policyTest,
  "background schedule targets the next configured local hour",
  "background schedule regression test",
);
requireText(
  settings,
  "حتى عند إغلاق التطبيق",
  "closed-app settings explanation",
);
requireText(
  settings,
  "قد يتأخر قليلًا مع توفير البطارية",
  "Android scheduling expectation",
);
requireText(
  diagnostics,
  "backgroundBackupWorkerStatus",
  "background worker diagnostics",
);
requireText(
  androidBuild,
  "sourceCompatibility = JavaVersion.VERSION_17",
  "WorkManager Java compatibility",
);
requireText(
  androidBuild,
  "jvmTarget = JavaVersion.VERSION_17.toString()",
  "WorkManager Kotlin compatibility",
);
if (iosProject.includes("IPHONEOS_DEPLOYMENT_TARGET = 13.0")) {
  throw new Error("WorkManager 0.9 requires iOS deployment target 14.0+");
}
requireText(
  iosProject,
  "IPHONEOS_DEPLOYMENT_TARGET = 14.0",
  "WorkManager iOS compile compatibility",
);

console.log(
  "P5.8 background backup scheduler contract passed: Android scheduling, settings refresh, diagnostics, and regression policy.",
);
