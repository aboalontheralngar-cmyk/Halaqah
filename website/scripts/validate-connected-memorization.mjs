import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireText = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
  }
};

const range = read("lib/services/quran_cross_surah_range_service.dart");
requireText(
  range,
  [
    "static QuranCrossSurahRange? toEnd",
    "static QuranCrossSurahRange? fromAyahs",
    "_segmentsFromAyahs",
  ],
  "Connected open range engine",
);

const recitation = read("lib/screens/memorization/recitation_screen.dart");
requireText(
  recitation,
  [
    "QuranCrossSurahRangeService.toEnd",
    "_suggestedPlanRange",
    "تحديد الجلسة بالمقرر",
    "_surahRangeLabel",
    "saveRecitationSession",
    "progressRows",
    "grades",
    "? _stopHere",
    "SafeArea(",
  ],
  "Connected direct recitation UI",
);
if (recitation.includes("RecitationBoundaryService.endOf")) {
  throw new Error("Direct recitation boundaries must not stop at one surah");
}
if (recitation.includes("Future.delayed(const Duration(milliseconds: 300)")) {
  throw new Error("Ayah rating must not race the explicit next/stop controls");
}

const manual = read("lib/screens/memorization/add_memorization_screen.dart");
requireText(
  manual,
  [
    "QuranCrossSurahRange? _connectedRange",
    "_buildPlanRange",
    "range.segments",
    "saveRecitationSession",
    "updatedTotalMemorized",
  ],
  "Connected manual memorization",
);

const database = read("lib/services/database_service.dart") + read("lib/services/local_database_schema.dart");
requireText(
  database,
  [
    "Future<void> saveRecitationSession",
    "progress.length != grades.length",
    "لا يمكن حفظ تقييم ناجح دون نطاق تسميع",
    "updatedTotalMemorized",
    "db.transaction",
  ],
  "Atomic connected recitation persistence",
);

requireText(
  read("test/quran_cross_surah_range_service_test.dart"),
  [
    "open range continues",
    "teacher stop point is split",
  ],
  "Connected memorization tests",
);

console.log("P1.6 connected memorization and open-recitation contract passed.");
