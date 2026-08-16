import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const attendance = read("lib/screens/attendance/attendance_screen.dart");
const directEntry = read("lib/screens/memorization/add_memorization_screen.dart");
const qrWeb = read("website/src/app/attendance/qr/page.tsx");
const memorizationWeb = read("website/src/app/memorization/page.tsx");
const buildInfo = read("lib/app/build_info.dart");
const pubspec = read("pubspec.yaml");

for (const [source, text, label] of [
  [attendance, "'memorization_session'", "QR recitation-session action"],
  [attendance, "'memorization_direct'", "QR direct-memorization action"],
  [attendance, "AddMemorizationScreen(student: student)", "Android direct-entry route"],
  [attendance, "StudentLearningPolicy.canReceiveNewMemorization", "graduate direct-entry guard"],
  [directEntry, "الحفظ المباشر", "validated direct memorization screen"],
  [qrWeb, 'openMemorization("direct")', "web QR direct action"],
  [qrWeb, 'openMemorization("session")', "web QR session action"],
  [qrWeb, 'memorization_entry_mode', "web QR handoff mode"],
  [memorizationWeb, 'entryMode === "direct"', "web direct-entry mode"],
  [memorizationWeb, 'const recordRange = entryMode === "direct"', "direct range persistence"],
  [memorizationWeb, "تسجيل الحفظ مباشرة", "direct-save label"],
  [buildInfo, "releaseLabel = 'P1.27'", "central current release label"],
  [pubspec, "version: 4.3.0-alpha.24+80", "current package version"],
]) {
  requireText(source, text, label);
}

console.log("P1.17.1 passed: QR offers direct memorization or a recitation session on Android and Web.");
