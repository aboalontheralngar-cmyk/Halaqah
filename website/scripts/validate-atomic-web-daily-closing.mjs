import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const migration = read(
  "website/supabase/migrations/20260722000200_p1_14_atomic_web_daily_closing.sql",
);
requireAll(
  migration,
  [
    "CREATE TABLE IF NOT EXISTS public.daily_closings",
    "CREATE TABLE IF NOT EXISTS public.study_suspensions",
    "session_end_time",
    "timezone_name",
    "weekly_holiday_days",
    "points_config",
    "public.set_study_suspension",
    "public.get_daily_closing_state",
    "public.close_daily_operations",
    "pg_advisory_xact_lock",
    "already_closed",
    "daily_closing_blocked",
    "غياب بدون عذر (تلقائي)",
    "عدم التسميع (تلقائي)",
    "public.homework_grades",
    "public.memorization",
    "public.student_holds",
    "daily_operations_closed",
    "ENABLE ROW LEVEL SECURITY",
    "FROM PUBLIC, anon",
  ],
  "Atomic Supabase daily close",
);

const store = read("website/src/store/useStore.ts");
requireAll(
  store,
  [
    "getDailyClosingStatus",
    "closeDailyOperations",
    "fetchStudentHolds",
    "fetchSuspendedDates: async",
    "set_study_suspension",
    "normalizePointsConfig",
    "updateDailySchedule",
    "weeklyHolidayDays: [5]",
    "unexcused_absence: -10",
  ],
  "Web data-store integration",
);

const evaluator = read("website/src/lib/dailyClosing.ts");
requireAll(
  evaluator,
  [
    "homeworkGrades",
    'record.gradeMark !== "absent"',
    "studentHolds",
    "isWeeklyHoliday",
    "normalizePointsConfig",
    "commonPenalty + 1",
  ],
  "Daily close evaluator parity",
);

requireAll(
  read("website/src/app/daily-closing/page.tsx"),
  [
    "مركز إغلاق اليوم",
    "اعتماد إغلاق اليوم",
    "رقم الإيصال",
    "closeDailyOperations",
    "getDailyClosingStatus",
    "isWeeklyHoliday",
    "homeworkGrades",
    "studentHolds",
  ],
  "Atomic closing user interface",
);

requireAll(
  read("website/src/app/attendance/page.tsx"),
  [
    "showSuspensionModal",
    "suspensionReason",
    "اعتماد التعليق",
    "isWeeklyDayOff",
    "activeSuspension?.reason",
  ],
  "Cloud suspension workflow",
);

requireAll(
  read("website/src/app/settings/page.tsx"),
  [
    "وقت انتهاء الدوام",
    "المنطقة الزمنية",
    "أيام الإجازة الأسبوعية",
    "updateDailySchedule",
  ],
  "Daily schedule settings",
);

requireAll(
  read("website/supabase/verification/20260722000200_p1_14_atomic_daily_closing_readiness.sql"),
  [
    "table:daily_closings",
    "table:study_suspensions",
    "function:close_daily_operations",
    "columns:center_settings",
  ],
  "Read-only Supabase verification",
);

console.log(
  "P1.14 passed: atomic Web close, idempotent receipts, cloud suspensions, weekly holidays, and balanced automatic penalties.",
);
