import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = relative => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const service = read("website/src/services/quranRangeService.ts");
const page = read("website/src/app/memorization/page.tsx");
const store = read("website/src/store/useStore.ts");
const migration = read("website/supabase/migrations/20260719000100_p1_web_connected_recitation.sql");

for (const contract of [
  "buildToAmount",
  "buildToEnd",
  "truncateAt",
  "splitIntoSegments",
  'QuranRangeUnit = "ayahs" | "lines" | "pages" | "hizbs"',
]) {
  requireText(service, contract, `connected range service ${contract}`);
}

for (const contract of [
  "بدء جلسة التسميع",
  "التوقف هنا",
  "stopRecitationHere",
  "sessionRatings",
  "showAyahText",
  "addHomeworkGradeSession(sessionRecords)",
]) {
  requireText(page, contract, `web open recitation UI ${contract}`);
}

requireText(store, "addHomeworkGradeSession", "atomic session store action");
requireText(store, "save_recitation_session", "atomic session RPC call");

for (const contract of [
  "BEGIN;",
  "CREATE OR REPLACE FUNCTION public.save_recitation_session",
  "FOR segment IN SELECT value FROM jsonb_array_elements(p_segments)",
  "PERFORM public.save_recitation_record",
  "CASE WHEN cardinality(saved_ids) = 0 THEN p_mistakes_count ELSE 0 END",
  "TO authenticated;",
  "COMMIT;",
]) {
  requireText(migration, contract, `atomic SQL contract ${contract}`);
}
if (migration.includes("gen_random_bytes") || migration.includes("gen_random_uuid")) {
  throw new Error("Connected recitation migration must not depend on pgcrypto random functions.");
}

const quran = JSON.parse(read("website/public/quran_data.json"));
const surahs = quran.surahs ?? [];
const first = surahs.find(surah => surah.number === 1);
const second = surahs.find(surah => surah.number === 2);
const lastFirstAyah = Math.max(...first.ayahs.map(ayah => ayah.number).filter(number => number > 0));
const firstSecondAyah = Math.min(...second.ayahs.map(ayah => ayah.number).filter(number => number > 0));
if (lastFirstAyah !== 7 || firstSecondAyah !== 1) {
  throw new Error("Unexpected Quran boundary data for cross-surah validation.");
}

console.log("Web connected recitation passed: open stop-point UI, cross-surah ranges, and atomic SQL session persistence.");
