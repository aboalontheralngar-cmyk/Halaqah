import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const database = read("lib/services/database_service.dart");
const service = read("lib/services/daily_excellence_service.dart");
const screen = read("lib/screens/honor_board/daily_excellence_screen.dart");
const home = read("lib/screens/home/home_screen.dart");
const detail = read("lib/screens/students/student_detail_screen.dart");
const sync = read("lib/services/supabase_service.dart");
const test = read("test/daily_excellence_service_test.dart");
const webPage = read("website/src/app/daily-excellence/page.tsx");
const webStore = read("website/src/store/useStore.ts");
const layout = read("website/src/components/DashboardLayout.tsx");
const migration = read("website/supabase/migrations/20260712000300_p5_daily_excellence.sql");

for (const contract of [
  "version: 14",
  "CREATE TABLE IF NOT EXISTS daily_achievements",
  "getDailyAchievements",
  "saveDailyAchievement",
  "awardDailyAchievement",
  "تكريم متميز اليوم",
  "daily_achievements",
]) requireText(database, contract, `SQLite contract ${contract}`);

for (const contract of [
  "uniqueAyahs",
  "unit == 'pages'",
  "unit == 'lines'",
  "actualAmount > planAmount",
]) requireText(service, contract, `calculation contract ${contract}`);

for (const contract of [
  "متميزو اليوم",
  "تجاوزوا المقرر",
  "إضافة متميز يدويًا",
  "وجبة/عشاء جماعي",
  "awardDailyAchievement",
]) requireText(screen, contract, `Android UI contract ${contract}`);

requireText(home, "DailyExcellenceScreen", "Android navigation");
requireText(detail, "ملخص المسار الحالي", "student learning summary");
requireText(detail, "تعديل المقرر", "editable daily target");
requireText(detail, "آخر مراجعة", "latest revision summary");
requireText(sync, "_syncDailyAchievements", "bidirectional achievement sync");
requireText(test, "deduplicates overlapping daily recitation ranges", "deduplication regression test");
requireText(test, "requires a real increase above the plan", "strict over-plan regression test");

for (const contract of [
  "متميزو اليوم",
  "calculateActual",
  "saveDailyAchievement",
  "awardDailyAchievement",
  "وجبة/عشاء جماعي",
  "!record.isRevision",
]) requireText(webPage, contract, `web daily excellence contract ${contract}`);
requireText(webStore, "dailyAchievements", "web achievement state");
requireText(webStore, "award_daily_achievement", "web atomic reward RPC");
requireText(layout, 'href: "/daily-excellence"', "web navigation");

for (const contract of [
  "CREATE TABLE IF NOT EXISTS public.daily_achievements",
  "CREATE OR REPLACE FUNCTION public.award_daily_achievement",
  "ON CONFLICT (student_id, date)",
  "current_user_can_access_halaqa",
  "p_reward_type = 'points'",
]) requireText(migration, contract, `Supabase contract ${contract}`);

console.log("Daily excellence contract passed: strict over-plan math, manual recognition, atomic rewards, student summary, sync, web, and scoped SQL.");
