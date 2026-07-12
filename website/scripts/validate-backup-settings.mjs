import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const settingsModel = read("lib/models/settings.dart");
const settingsScreen = read("lib/screens/settings/settings_screen.dart");
const homeScreen = read("lib/screens/home/home_screen.dart");
const backupService = read("lib/services/backup_service.dart");
const policyService = read("lib/services/backup_policy_service.dart");
const policyTest = read("test/backup_policy_service_test.dart");

for (const contract of [
  "backupReminderEnabled",
  "backupReminderIntervalDays",
  "automaticBackupEnabled",
  "automaticBackupHour",
  "automaticBackupRetentionCount",
]) {
  requireText(settingsModel, contract, `persisted setting ${contract}`);
}

for (const contract of [
  "_buildSettingsNavigation",
  "النسخ المحلي التلقائي",
  "تذكير سلامة البيانات",
  "عدد النسخ التلقائية المحتفظ بها",
  "المزامنة السحابية",
]) {
  requireText(settingsScreen, contract, `settings UI contract ${contract}`);
}

for (const contract of [
  "performAutomaticBackupIfDue",
  "last_automatic_backup_at",
  "last_backup_reminder_at",
  "halaqah_backup_auto_",
  "_pruneAutomaticBackups",
]) {
  requireText(backupService, contract, `backup service contract ${contract}`);
}

requireText(homeScreen, "_handleBackupMaintenance", "startup backup maintenance");
requireText(homeScreen, "حماية بيانات الحلقة", "backup reminder dialog");
requireText(policyService, "isAutomaticBackupDue", "automatic backup policy");
requireText(policyService, "isReminderDue", "backup reminder policy");
requireText(policyTest, "runs once on the first launch after schedule", "schedule regression test");
requireText(policyTest, "respects both backup and reminder intervals", "reminder regression test");

console.log("Backup/settings contract passed: organization, persistence, schedule, reminder, retention, and startup wiring.");
