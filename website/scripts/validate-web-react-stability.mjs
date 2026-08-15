import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

function requireAll(source, values, label) {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
  }
}

const packageJson = read("website/package.json");
requireAll(
  packageJson,
  [
    '"lint:ci": "eslint --max-warnings 0"',
    '"validate:react-stability"',
  ],
  "Strict web quality gate",
);

requireAll(
  read("website/src/app/page.tsx"),
  ["useSyncExternalStore", "getServerSnapshot", "if (!mounted) return null"],
  "Hydration-safe dashboard",
);

requireAll(
  read("website/src/app/attendance/page.tsx"),
  ["useCallback", "getAttendanceStatus = useCallback", "isStudentOnVacation = useCallback"],
  "Stable attendance selectors",
);

requireAll(
  read("website/src/app/memorization/page.tsx"),
  [
    "resetSession = useCallback",
    "getMemorizedAyahCount = useCallback",
    "selectStudentForNewRecord = useCallback",
    "queueMicrotask",
  ],
  "Stable memorization prefill",
);

requireAll(
  read("website/src/app/students/raffle/page.tsx"),
  ["queueMicrotask", "setTimeout(() => settleDraw(targetId), 0)"],
  "Persistent raffle effects",
);

requireAll(
  read("website/src/components/MushafVisualizer.tsx"),
  ["queueMicrotask", "if (active) setLoading(false)"],
  "Cancellable Mushaf loading",
);

const readinessSql = read(
  "website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql",
);
requireAll(
  readinessSql,
  [
    "Sensitive portal tables intentionally have zero policies",
    "'deny-all'::text AS check_group",
    "policy_count = 0",
    "NOT anon_direct",
    "NOT authenticated_direct",
  ],
  "Portal deny-all verification",
);

console.log(
  "P1.10 web stability passed: zero-warning lint contract, stable React effects, and explicit portal deny-all verification.",
);
