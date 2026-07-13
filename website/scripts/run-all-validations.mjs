import { spawnSync } from "node:child_process";

const validators = [
  "validate-quran-data.mjs",
  "validate-security-migration.mjs",
  "validate-period-reports.mjs",
  "validate-discipline-contract.mjs",
  "validate-recitation-records.mjs",
  "validate-smart-plans.mjs",
  "validate-open-recitation.mjs",
  "validate-revision-continuity.mjs",
  "validate-backup-settings.mjs",
  "validate-cloud-sync-direction.mjs",
  "validate-student-archive-behavior.mjs",
  "validate-daily-excellence.mjs",
  "validate-report-pdf-drawer.mjs",
  "validate-families-guardians.mjs",
  "validate-halaqah-period-reports.mjs",
  "validate-web-recitation-parity.mjs",
  "validate-advanced-exams.mjs",
  "validate-design-system.mjs",
  "validate-production-readiness.mjs",
  "validate-data-privacy.mjs",
  "validate-unified-identity.mjs",
];

for (const validator of validators) {
  const result = spawnSync(process.execPath, [`scripts/${validator}`], {
    cwd: process.cwd(),
    stdio: "inherit",
  });
  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

console.log(`All ${validators.length} release validators passed.`);
