import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");

const assertIncludes = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const pubspec = read("pubspec.yaml");
assertIncludes(
  pubspec,
  [
    "version: 3.7.0-alpha.1+37",
    "cryptography: ^2.9.0",
    "cryptography_flutter: ^2.3.4",
    "flutter_secure_storage: ^10.3.1",
  ],
  "Flutter backup security dependencies",
);

const cryptoService = read("lib/services/backup_crypto_service.dart");
assertIncludes(
  cryptoService,
  [
    "AesGcm.with256bits()",
    "PBKDF2-HMAC-SHA256",
    "defaultKdfIterations = 600000",
    "BackupAuthenticationException",
  ],
  "Authenticated backup encryption",
);

const backupService = read("lib/services/backup_service.dart");
assertIncludes(
  backupService,
  [
    "_payloadVersion = '3.0'",
    "'2.0', '2.1', _payloadVersion",
    "_maximumBackupBytes",
    "integrityDigest",
    ".halaqah",
  ],
  "Versioned backup and restore",
);

const database = read("lib/services/database_service.dart");
assertIncludes(
  database,
  [
    "version: 14",
    "CREATE TABLE IF NOT EXISTS audit_events",
    "_createAuditTriggers",
    "saveAuditEvent",
  ],
  "Local audit schema",
);

const manifest = read("android/app/src/main/AndroidManifest.xml");
assertIncludes(
  manifest,
  ['android:allowBackup="false"', 'android:fullBackupContent="false"'],
  "Android backup hardening",
);

const migration = read(
  "website/supabase/migrations/20260713000300_p6_data_privacy_cloud_backup.sql",
);
assertIncludes(
  migration,
  [
    "current_user_can_access_halaqa(",
    "CREATE TABLE IF NOT EXISTS public.audit_events",
    "write_audit_event(",
    "audit_sensitive_mutation()",
    "'halaqah-backups'",
    "storage.foldername(name)",
    "COMMIT;",
  ],
  "P6.2 cloud migration",
);
if (/progress\.halaqa_id/i.test(migration)) {
  throw new Error("P6.2 migration must not reference progress.halaqa_id");
}
if (/\b(DROP TABLE|TRUNCATE)\b/i.test(migration)) {
  throw new Error("P6.2 migration contains a destructive table operation");
}

for (const file of [
  "lib/screens/settings/privacy_policy_screen.dart",
  "lib/screens/settings/audit_log_screen.dart",
  "lib/services/cloud_backup_service.dart",
  "test/backup_crypto_service_test.dart",
  "website/src/app/privacy/page.tsx",
  "website/src/app/audit-log/page.tsx",
]) {
  read(file);
}

const webSettings = read("website/src/app/settings/page.tsx");
assertIncludes(
  webSettings,
  ['href="/audit-log"', 'href="/privacy"'],
  "Web privacy navigation",
);

console.log("P6.2 data privacy and encrypted backup contract passed.");
