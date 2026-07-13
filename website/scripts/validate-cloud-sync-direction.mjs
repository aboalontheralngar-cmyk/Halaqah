import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const service = read("lib/services/supabase_service.dart");
const home = read("lib/screens/home/home_screen.dart");
const settings = read("lib/screens/settings/settings_screen.dart");
const login = read("lib/screens/auth/login_screen.dart");
const backup = read("lib/services/backup_service.dart");
const test = read("test/cloud_sync_direction_test.dart");

for (const contract of [
  "enum CloudSyncDirection { uploadOnly, downloadOnly, bidirectional }",
  "bool get shouldUpload",
  "bool get shouldDownload",
  "if (direction.shouldDownload) await _createDailyPreSyncBackup();",
  "last_cloud_upload_at",
  "last_cloud_download_at",
  "last_cloud_sync_direction",
  "_fetchHalaqahStudentIds",
]) {
  requireText(service, contract, `cloud sync service contract ${contract}`);
}

for (const contract of [
  "رفع تغييرات الجهاز",
  "تنزيل بيانات السحابة",
  "مزامنة ذكية ثنائية الاتجاه",
  "CloudSyncDirection.uploadOnly",
  "CloudSyncDirection.downloadOnly",
]) {
  requireText(home, contract, `home sync UI ${contract}`);
  requireText(settings, contract, `settings sync UI ${contract}`);
}

if (login.includes("synchronizeData(")) {
  throw new Error("Login must not start an implicit cloud synchronization");
}

requireText(test, "upload only never downloads", "upload-only regression test");
requireText(test, "download only never uploads", "download-only regression test");
requireText(backup, "createPreSyncBackup", "pre-sync protected backup");
requireText(backup, "_pruneAutomaticBackups", "pre-sync backup retention");

console.log(
  "Cloud sync direction contract passed: explicit upload/download, protected pull, scoped records, separate timestamps, and no implicit login sync.",
);
