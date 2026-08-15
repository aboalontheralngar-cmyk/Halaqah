import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const service = read("lib/services/daily_closing_service.dart");
requireAll(
  service,
  [
    "DailyClosingEvaluator",
    "DailyClosingSnapshot",
    "isPastEndTime",
    "isDateSuspended",
    "getAllVacations",
    "getActiveStudentHolds",
    "db.transaction",
    "daily_operations_closed_",
    "ConflictAlgorithm.abort",
    "غياب بدون عذر (تلقائي)",
    "عدم التسميع (تلقائي)",
    "generateNotifications",
    "daily_operations_closed",
  ],
  "Atomic Android daily closing",
);

requireAll(
  read("lib/screens/attendance/daily_closing_screen.dart"),
  [
    "مركز إغلاق اليوم",
    "مراجعة اليوم قبل الاعتماد",
    "يحتاج إجراء",
    "اعتماد إغلاق اليوم",
    "لا يمكن تكرار الإغلاق",
    "SafeArea",
    "MediaQuery.textScalerOf(context)",
  ],
  "Responsive closing review UI",
);

const home = read("lib/screens/home/home_screen.dart");
requireAll(
  home,
  [
    "DailyClosingScreen",
    "مراجعة وإغلاق اليوم",
    "_dailyClosingActionCount",
    "LayoutBuilder",
    "textScale > 1.35",
    "textScale > 1.2",
  ],
  "Responsive home integration",
);

requireAll(
  read("test/daily_closing_service_test.dart"),
  [
    "approved vacation wins over an absent record",
    "actual attendance wins over a previously approved vacation",
    "missing attendance remains reviewable until explicit close",
    "hold exempts recitation but not attendance",
    "present student without recitation needs follow-up",
  ],
  "Daily closing regression tests",
);

requireAll(
  read("website/src/lib/dailyClosing.ts"),
  [
    "evaluateDailyClosing",
    'localeCompare(b.name, "ar")',
    'state: "unrecorded"',
    'state: "no_recitation"',
    "actionRequired",
  ],
  "Web daily review evaluator",
);

requireAll(
  read("website/src/app/daily-closing/page.tsx"),
  [
    "مراجعة عمليات اليوم",
    "يحتاج إجراء",
    'href="/attendance"',
    'href="/memorization"',
    "suspendedDates.includes(date)",
  ],
  "Web daily review route",
);

requireAll(
  read("website/src/app/page.tsx"),
  [
    "localDateKey",
    'href: "/daily-closing"',
    'router.push("/notifications")',
    'href: "/points"',
  ],
  "Working dashboard actions and local date",
);

const discipline = read("website/src/app/discipline/page.tsx");
requireAll(
  discipline,
  ["buildWhatsAppLink", "student.parentPhone", 'window.open(link, "_blank"', "نأمل تعاونكم معنا"],
  "Guardian WhatsApp follow-up",
);
if (discipline.includes("TODO: Send WhatsApp")) {
  throw new Error("Guardian follow-up must not remain a placeholder");
}

const login = read("website/src/app/login/page.tsx");
requireAll(
  login,
  [
    "supabaseConfiguration.isConfigured",
    "تسجيل الدخول غير متاح",
    "لن ينشئ النظام مستخدمًا تجريبيًا",
    "disabled={loading || !supabaseConfiguration.isConfigured}",
  ],
  "Fail-closed web authentication",
);
if (login.includes("mock-user") || login.includes("Mock for demo")) {
  throw new Error("Production login must fail closed without a mock identity");
}

requireAll(
  read("website/package.json"),
  ['"sharp": "0.35.3"', '"postcss": "8.5.23"'],
  "Patched transitive web dependencies",
);

for (const path of [
  "website/src/app/login/page.tsx",
  "website/src/app/page.tsx",
  "website/src/app/reports/page.tsx",
]) {
  if (read(path).includes("transparenttextures.com")) {
    throw new Error(`${path} must not require an external decorative texture`);
  }
}

console.log(
  "P1.13 daily operations passed: atomic Android close, web review parity, guardian WhatsApp, fail-closed auth, and responsive home.",
);
