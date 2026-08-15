import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
function read(relative) {
  return fs.readFileSync(path.join(root, relative), "utf8");
}
function assert(condition, message) {
  if (!condition) {
    console.error(`Build 75 Hotfix 3 validation failed: ${message}`);
    process.exit(1);
  }
}

const pubspec = read("pubspec.yaml");
assert(pubspec.includes("printing: 5.14.3"), "printing 5.14.3 pin must remain");
assert(pubspec.includes("share_plus: 10.0.3"), "share_plus must be pinned to 10.0.3");
assert(!pubspec.includes("share_plus: 9.0.0"), "incompatible share_plus 9.0.0 must not return");
assert(!/^\s*web:\s/m.test(pubspec), "do not paper over the solver conflict with a direct web dependency");

const shareUsageFiles = [
  "lib/screens/settings/diagnostics_screen.dart",
  "lib/screens/settings/operational_readiness_screen.dart",
  "lib/screens/settings/settings_screen.dart",
  "lib/screens/settings/offline_exchange_screen.dart",
  "lib/screens/memorization/recitation_screen.dart",
  "lib/screens/reports/student_receipt_screen.dart",
  "lib/screens/reports/student_period_report_screen.dart",
  "lib/screens/reports/halaqah_period_report_screen.dart",
  "lib/services/report_export_service.dart",
];
for (const file of shareUsageFiles) {
  const source = read(file);
  assert(source.includes("package:share_plus/share_plus.dart"), `${file} must keep share_plus import`);
}

console.log("Build 75 Hotfix 3 dependency-pair validation passed.");
