import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const service = read("lib/services/operational_readiness_service.dart");
requireAll(
  service,
  [
    "OperationalReadinessState",
    "maximumBackupAge = Duration(days: 7)",
    "hasCriticalDataIssue",
    "cloudConnectionHealthy",
    "cloudAuthenticated",
    "two_device_sync",
    "encrypted_restore",
    "portal_isolation",
    "physical_printing",
    "qr_attendance",
    "release_acceptance_manual_${AppBuildInfo.versionName}",
    "toSafeReport",
  ],
  "Operational readiness engine",
);

requireAll(
  read("lib/screens/settings/operational_readiness_screen.dart"),
  [
    "جاهزية التشغيل والإطلاق",
    "الفحوص التلقائية",
    "اختبارات القبول الفعلية",
    "CheckboxListTile",
    "مشاركة التقرير",
    "لا يتضمن أسماء الطلاب",
  ],
  "Operational readiness UI",
);

requireAll(
  read("lib/screens/settings/settings_screen.dart"),
  [
    "OperationalReadinessScreen",
    "جاهزية التشغيل والإطلاق",
    "التشخيص الفني وتقرير الدعم",
  ],
  "Settings readiness navigation",
);

requireAll(
  read("test/operational_readiness_service_test.dart"),
  [
    "healthy automatic and completed manual checks are ready",
    "critical data, stale backup, and cloud failure block readiness",
    "manual checks remain pending for every new release",
    "warnings are visible but do not invalidate completed acceptance",
  ],
  "Operational readiness regression tests",
);

const sql = read(
  "website/supabase/verification/20260722000100_p1_12_portal_security_readiness.sql",
);
requireAll(
  sql,
  [
    "portal-deny-all",
    "portal-summary",
    "rls=true policies=0",
    "anon_direct=false",
    "authenticated_direct=false",
    "bool_and(passed)",
  ],
  "Unambiguous portal security readiness SQL",
);
if (/^\s*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/im.test(
  sql.replace(/^\s*--.*$/gm, ""),
)) {
  throw new Error("P1.12 portal readiness SQL must remain read-only");
}

console.log(
  "P1.12 operational readiness passed: automatic gates, versioned manual acceptance, safe report, and explicit portal deny-all verification.",
);
