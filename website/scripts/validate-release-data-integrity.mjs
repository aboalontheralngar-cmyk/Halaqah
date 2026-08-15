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

const integrityService = read(
  "lib/services/local_data_integrity_service.dart",
);
requireAll(
  integrityService,
  [
    "PRAGMA foreign_key_check",
    "duplicate_attendance",
    "duplicate_identity",
    "invalid_student_code",
    "invalid_student_plan",
    "invalid_vacation_range",
    "invalid_quran_range",
    "getSurahAyahCount",
    "toSafeSummary",
  ],
  "Read-only local data integrity audit",
);
if (/\.(delete|update|insert)\s*\(/.test(integrityService)) {
  throw new Error("Local data integrity audit must remain read-only");
}

requireAll(
  read("lib/services/diagnostic_center_service.dart"),
  [
    "LocalDataIntegrityReport dataIntegrity",
    "LocalDataIntegrityService",
    "dataIntegrity.toSafeSummary()",
  ],
  "Diagnostic integrity integration",
);

requireAll(
  read("lib/screens/settings/diagnostics_screen.dart"),
  [
    "سلامة البيانات المحلية",
    "report.checkedRules",
    "DataIntegritySeverity.critical",
    "هذا الفحص للقراءة فقط",
  ],
  "Diagnostic integrity UI",
);

for (const testPath of [
  "test/local_data_integrity_service_test.dart",
  "test/diagnostic_center_service_test.dart",
]) {
  requireAll(read(testPath), ["test(", "expect("], `Integrity test ${testPath}`);
}

const preflight = read("tools/staging_preflight.ps1");
requireAll(
  preflight,
  [
    "ValidateSet('release', 'debug')",
    "SupabaseReadinessCsv",
    "Import-Csv",
    "apksigner",
    "halaqah-acceptance-",
    "APK SHA-256",
  ],
  "Release-candidate preflight",
);

const readinessSql = read(
  "website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql",
);
if (/^\s*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/im.test(
  readinessSql.replace(/^\s*--.*$/gm, ""),
)) {
  throw new Error("Supabase release-readiness verification must remain read-only");
}

console.log(
  "P1.11 release data-integrity passed: read-only SQLite audit, safe diagnostics, APK preflight, and Supabase CSV gate.",
);
