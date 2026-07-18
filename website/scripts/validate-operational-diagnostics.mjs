import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const assertIncludes = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
  }
};

const main = read("lib/main.dart");
assertIncludes(
  main,
  [
    "FlutterError.onError",
    "PlatformDispatcher.instance.onError",
    "OperationalIncidentService",
    "HalaqahStartupFailureApp",
    "source: 'startup'",
  ],
  "Flutter global error capture",
);

const incidents = read("lib/services/operational_incident_service.dart");
assertIncludes(
  incidents,
  [
    "stackFingerprint",
    "sha256.convert",
    "runtime.error",
    "runtime.fatal",
    "Error capture must never cause a second application failure",
    "const Duration(minutes: 5)",
  ],
  "Sanitized operational incidents",
);
if (incidents.includes("'error_message'") || incidents.includes("'stack_trace'")) {
  throw new Error("Operational incidents must not persist raw messages or stack traces");
}

const center = read("lib/services/diagnostic_center_service.dart");
assertIncludes(
  center,
  [
    "class DiagnosticSnapshot",
    "toSupportReport()",
    "database.getVersion()",
    "last_cloud_upload_at",
    "last_cloud_download_at",
    "لا يحتوي هذا التقرير أسماء الطلاب",
  ],
  "Diagnostic snapshot",
);
if (center.includes("technicalDetails}")) {
  throw new Error("Support report must not interpolate raw cloud technical details");
}

assertIncludes(
  read("lib/screens/settings/diagnostics_screen.dart"),
  [
    "مركز التشخيص والدعم",
    "مشاركة تقرير الدعم",
    "Clipboard.setData",
    "الحوادث البرمجية المنقحة",
    "لا يتضمن أسماء الطلاب",
  ],
  "Diagnostics screen",
);

assertIncludes(
  read("lib/screens/settings/settings_screen.dart"),
  ["('diagnostics', 'التشخيص'", "DiagnosticsScreen", "AppBuildInfo.displayVersion"],
  "Diagnostics navigation",
);

for (const test of [
  "test/operational_incident_service_test.dart",
  "test/diagnostic_center_service_test.dart",
]) {
  assertIncludes(read(test), ["test("], `Operational test ${test}`);
}

assertIncludes(
  read("lib/app/build_info.dart"),
  ["4.1.0-alpha.2", "buildNumber = 42", "releaseLabel = 'RC2'"],
  "Central build identity",
);

console.log("P6.4 operational diagnostics contract passed.");
