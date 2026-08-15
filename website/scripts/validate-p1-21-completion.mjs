import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";
import ts from "typescript";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (path, fragments) => {
  const source = path === "lib/services/database_service.dart"
    ? read(path) + read("lib/services/local_database_schema.dart")
    : read(path);
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`P1.21 missing ${fragment} in ${path}`);
    }
  }
  return source;
};

requireAll("pubspec.yaml", ["version: 4.3.0-alpha.22+76"]);
requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.22'",
  "buildNumber = 76",
  "releaseLabel = 'P1.27'",
]);

const exchangePolicy = requireAll("lib/services/offline_exchange_policy.dart", [
  "Duration(minutes: 30)",
  "codeLength = 12",
  "ABCDEFGHJKMNPQRSTUVWXYZ23456789",
  "Random.secure()",
  "isWithinValidityWindow",
]);
if (/[ILO01]/.test(exchangePolicy.match(/_alphabet = '([^']+)'/)?.[1] || "")) {
  throw new Error("P1.21 exchange alphabet contains ambiguous characters");
}

const exchangeScreen = requireAll(
  "lib/screens/settings/offline_exchange_screen.dart",
  [
    "OfflineExchangePolicy.generateCode()",
    "exportDeviceExchange",
    "OfflineExchangePolicy.passphrase",
    "لا ترسل الكود مع الملف نفسه",
    "FilteringTextInputFormatter.allow",
  ],
);
if (exchangeScreen.includes("كود الربط: $code")) {
  throw new Error("P1.21 must not share the exchange code with the package");
}

requireAll("lib/services/backup_service.dart", [
  "purpose: 'device_exchange'",
  "'expires_at'",
  "OfflineExchangePolicy.isWithinValidityWindow",
  "exportDeviceExchangeTables",
  "هذا الملف نسخة احتياطية وليس حزمة تبادل بين الأجهزة",
]);
requireAll("lib/services/database_service.dart", [
  "exportDeviceExchangeTables",
  "table == 'settings'",
  "table == 'audit_events'",
  "table == 'message_templates'",
]);
if (read("lib/utils/constants.dart").includes("encryptionKey")) {
  throw new Error("P1.21 must not retain a hard-coded encryption key");
}
if (!existsSync(resolve(root, "test/offline_exchange_policy_test.dart"))) {
  throw new Error("P1.21 offline exchange policy tests are missing");
}

const migrationPath =
  "website/supabase/migrations/20260728000100_p1_21_guardian_automatic_reports.sql";
const migration = requireAll(migrationPath, [
  "guardian_report_subscriptions",
  "guardian_report_deliveries",
  "consent_at",
  "CREATE POLICY guardian_report_subscriptions_select",
  "CREATE POLICY guardian_report_deliveries_select",
  "get_guardian_report_subscription",
  "set_guardian_report_subscription",
  "publish_due_guardian_reports",
  "claim_guardian_report_deliveries",
  "complete_guardian_report_delivery",
  "family_portal_get_automatic_reports",
  "FOR UPDATE SKIP LOCKED",
  "attempt_count < 5",
  "TO service_role",
  "FROM PUBLIC, anon, authenticated",
  "halaqah-publish-guardian-reports",
  "COMMIT;",
]);
if (/\b(DROP TABLE|TRUNCATE)\b/i.test(migration)) {
  throw new Error("P1.21 migration contains a destructive table operation");
}
requireAll(
  "website/supabase/verification/20260728000100_p1_21_guardian_reports_readiness.sql",
  [
    "guardian_report_subscriptions_table",
    "guardian_report_deliveries_rls",
    "family_portal_automatic_reports_rpc",
    "guardian_report_public_execute_revoked",
  ],
);

const workerPath =
  "website/supabase/functions/guardian-report-worker/index.ts";
const worker = requireAll(workerPath, [
  "GUARDIAN_REPORT_WORKER_SECRET",
  "x-halaqah-report-secret",
  "GUARDIAN_REPORT_WEBHOOK_URL",
  "GUARDIAN_REPORT_WEBHOOK_SECRET",
  "parsedWebhookUrl.protocol !== 'https:'",
  "hmacHex",
  "claim_guardian_report_deliveries",
  "complete_guardian_report_delivery",
  "AbortSignal.timeout",
]);
const transpiled = ts.transpileModule(worker, {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
  },
  fileName: workerPath,
  reportDiagnostics: true,
});
const syntaxErrors = (transpiled.diagnostics || []).filter(
  (diagnostic) => diagnostic.category === ts.DiagnosticCategory.Error,
);
if (syntaxErrors.length > 0) {
  throw new Error(
    `P1.21 worker TypeScript is invalid: ${syntaxErrors
      .map((diagnostic) => diagnostic.messageText)
      .join("; ")}`,
  );
}

requireAll("website/src/app/parents/page.tsx", [
  "AutomaticReportsModal",
  "get_guardian_report_subscription",
  "set_guardian_report_subscription",
  "التقارير التلقائية",
  "موافقة ولي الأمر",
]);
requireAll("website/supabase/functions/student-portal/index.ts", [
  "family_portal_get_automatic_reports",
  "automatic_reports",
]);
requireAll("website/src/lib/studentPortal.ts", [
  "GuardianAutomaticReport",
  "automatic_reports",
]);
requireAll("website/src/app/portal/page.tsx", [
  "التقارير الدورية المنشورة",
  "automaticReports",
  "external_status",
]);
requireAll("website/supabase/config.toml", [
  "[functions.guardian-report-worker]",
  "verify_jwt = false",
]);

console.log(
  "P1.21 passed: consent-based automatic guardian reports and hardened expiring offline exchange are protected.",
);
