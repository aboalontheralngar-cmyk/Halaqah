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

requireText(
  read("lib/services/quran_cross_surah_range_service.dart"),
  [
    "enum QuranRangeUnit { ayahs, lines, pages, hizbs }",
    "static QuranCrossSurahRange? toAmount",
    "allowedRanges",
    "ascendingSurahs",
    "accumulatedLines",
  ],
  "Connected Quran range engine",
);

const revision = read("lib/screens/memorization/revision_screen.dart");
requireText(
  revision,
  [
    "QuranCrossSurahRangeService.toAmount",
    "مقرر جلسة المراجعة",
    "DropdownMenuItem(value: 'hizbs'",
    "تطبيق المقرر على موضع الاستئناف",
    "إلى نهاية الحزب",
    "allowedRanges: allowedRanges",
  ],
  "Connected revision UI",
);
if (revision.includes("RecitationBoundaryService.endOf")) {
  throw new Error("Revision boundaries must use the connected Quran range engine");
}

for (const [path, marker] of [
  ["lib/screens/students/student_form_screen.dart", "DropdownMenuItem(value: 'hizbs'"],
  ["lib/screens/plans/plans_screen.dart", "DropdownMenuItem(value: 'hizbs'"],
  ["lib/services/memorization_measure_service.dart", "planType == 'hizbs'"],
  ["lib/services/daily_excellence_service.dart", "unit == 'hizbs'"],
  ["website/src/app/students/page.tsx", "value=\"hizbs\""],
  ["website/src/app/plans/page.tsx", "'hizbs'"],
]) {
  requireText(read(path), [marker], `Hizb unit ${path}`);
}

const migration = read(
  "website/supabase/migrations/20260718000200_p1_connected_hizb_plans.sql",
);
requireText(
  migration,
  [
    "CHECK (plan_type IN ('ayahs', 'pages', 'lines', 'hizbs'))",
    "CHECK (unit IN ('ayahs', 'pages', 'lines', 'hizbs'))",
    "p_unit NOT IN ('ayahs', 'pages', 'lines', 'hizbs')",
    "CREATE OR REPLACE FUNCTION public.award_daily_achievement",
  ],
  "Hizb Supabase compatibility",
);
if (/\b(?:DROP\s+TABLE|DELETE\s+FROM\s+public\.students)\b/i.test(migration)) {
  throw new Error("P1.5 migration must not delete student data or tables");
}

requireText(
  read("test/quran_cross_surah_range_service_test.dart"),
  ["two-page amount", "line amount", "allowed memorized ranges", "descending surah order"],
  "Connected range tests",
);

console.log("P1.5 connected revision and hizb-plan contract passed.");
