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

const diagnostics = read("lib/services/cloud_connection_diagnostics.dart");
assertIncludes(
  diagnostics,
  [
    "CloudConnectionStatus.dnsFailure",
    "CloudConnectionStatus.timeout",
    "CloudConnectionStatus.tlsFailure",
    "CloudConnectionStatus.serverFailure",
    "InternetAddress.lookup",
    "HttpClient()",
  ],
  "Cloud connection diagnostics",
);

assertIncludes(
  read("lib/services/supabase_service.dart"),
  [
    "String.fromEnvironment(\n    'SUPABASE_URL'",
    "String.fromEnvironment(\n    'SUPABASE_PUBLISHABLE_KEY'",
    "diagnoseConnection()",
    "cloud_connection_diagnostics.dart",
  ],
  "Flutter Supabase configuration",
);

assertIncludes(
  read("lib/screens/settings/settings_screen.dart"),
  ["فحص اتصال Supabase", "_performCloudConnectionCheck", "دون رفع أو تنزيل بيانات"],
  "In-app connectivity check",
);

assertIncludes(
  read("test/cloud_connection_diagnostics_test.dart"),
  ["distinguishes DNS lookup failure", "distinguishes a connection timeout", "server-side failure"],
  "Diagnostic unit tests",
);

const gradle = read("android/app/build.gradle.kts");
assertIncludes(
  gradle,
  [
    "HALAQAH_REQUIRE_RELEASE_SIGNING",
    "HALAQAH_APPLICATION_ID",
    "android/key.properties is missing",
    'signingConfigs.getByName("release")',
  ],
  "Android release signing gate",
);

assertIncludes(
  read("android/app/src/main/AndroidManifest.xml"),
  ['<uses-permission android:name="android.permission.INTERNET"/>', 'android:label="حلقتي"'],
  "Android production networking",
);

assertIncludes(
  read("pubspec.yaml"),
  ["version: 4.1.0-alpha.1+41"],
  "Flutter staged-release version",
);

const workflow = read(".github/workflows/build-apk.yml");
assertIncludes(
  workflow,
  [
    "release_channel:",
    "ANDROID_KEYSTORE_BASE64",
    "ANDROID_APPLICATION_ID",
    "SUPABASE_PUBLISHABLE_KEY",
    "HALAQAH_REQUIRE_RELEASE_SIGNING",
    "apksigner",
    "sha256sum",
    "--split-debug-info=build/symbols",
  ],
  "Staged APK workflow",
);

assertIncludes(
  read(".github/workflows/quality.yml"),
  ["flutter analyze", "flutter test", "flutter build apk --debug"],
  "Flutter CI build gate",
);

assertIncludes(
  read("tools/staging_preflight.ps1"),
  [
    "flutter' -Arguments @('analyze')",
    "flutter' -Arguments @('test')",
    "flutter' -Arguments @('build', 'apk', '--release')",
    "Get-FileHash",
    "npm' -Arguments @('run', 'quality:ci')",
  ],
  "Windows staging preflight",
);

const readinessSql = read(
  "website/supabase/verification/20260718000100_p6_3_release_readiness_check.sql",
);
assertIncludes(
  readinessSql,
  ["to_regclass", "to_regprocedure", "relrowsecurity", "pg_policies", "pgcrypto"],
  "Read-only Supabase readiness check",
);
if (/^\s*(CREATE|ALTER|DROP|INSERT|UPDATE|DELETE|TRUNCATE|GRANT|REVOKE)\b/im.test(
  readinessSql.replace(/^\s*--.*$/gm, ""),
)) {
  throw new Error("P6.3 Supabase readiness check must remain read-only");
}

console.log("P6.3 staged-release contract passed.");
