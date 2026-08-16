import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const settings = read("lib/screens/settings/settings_screen.dart");
const buildInfo = read("lib/app/build_info.dart");
const pubspec = read("pubspec.yaml");

for (const [source, text, label] of [
  [settings, "String _selectedDataArea = 'backup'", "data workspace state"],
  [settings, "String _settingsQuery = ''", "settings search state"],
  [settings, "إعدادات الحلقة اليومية", "everyday settings group"],
  [settings, "الإدارة والحماية", "administration settings group"],
  [settings, "ابحث عن إعداد", "settings search field"],
  [settings, "_buildSettingsNavGroup", "grouped settings navigation"],
  [settings, "_buildDataAreaNavigation", "data sub-navigation"],
  [settings, "النسخ والحماية", "backup workspace"],
  [settings, "المزامنة والاتصال", "sync workspace"],
  [settings, "الخصوصية والسجل", "privacy workspace"],
  [settings, "إدارة النظام والدعم", "system administration center"],
  [settings, "جاهزية التشغيل والإطلاق", "readiness task"],
  [settings, "التشخيص الفني وتقرير الدعم", "diagnostics task"],
  [settings, "سجل التدقيق الإداري", "audit task"],
  [buildInfo, "releaseLabel = 'P1.27'", "current release label"],
  [pubspec, "version: 4.3.0-alpha.24+80", "current package version"],
]) {
  requireText(source, text, label);
}

console.log("P1.17.2 passed: settings, data protection, and system administration are grouped and searchable.");
