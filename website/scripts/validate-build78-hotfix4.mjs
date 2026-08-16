import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 78 Hotfix 4 validation failed: ${message}`);
    process.exit(1);
  }
};

const sync = read('lib/services/supabase_service.dart');
const templatesStage = sync.indexOf("runStage('exam_templates'");
const examsStage = sync.indexOf("runStage('exams'");
const cleanupStage = sync.indexOf("'exam_template_cleanup'");
assert(templatesStage >= 0, 'exam template stage is missing');
assert(examsStage > templatesStage, 'exam templates must synchronize before exams');
assert(cleanupStage > examsStage, 'deleted template cleanup must run after exam upserts');
assert(
  sync.includes('ExamSyncPolicy.cloudTemplateId('),
  'exam payload must sanitize stale template references',
);
assert(
  sync.includes("cause.code == '23503'"),
  'foreign-key failures need a privacy-safe actionable message',
);
const templateFunctionStart = sync.indexOf('Future<void> _syncExamTemplates(');
const templateFunctionEnd = sync.indexOf('Future<void> _syncDeletedExamTemplates()', templateFunctionStart);
const templateFunction = sync.slice(templateFunctionStart, templateFunctionEnd);
assert(
  !templateFunction.includes('await _syncDeletedExamTemplates();'),
  'template deletion must not run before exam references are reconciled',
);

const database = read('lib/services/database_service.dart');
assert(
  database.includes("await txn.update(\n        'exams',\n        {'template_id': null}"),
  'local template deletion must clear exam.template_id transactionally',
);

const autoSync = read('lib/services/cloud_auto_sync_coordinator.dart');
for (const token of [
  "import 'backup_service.dart';",
  'final canProtectDownload = await BackupService().passphrases.isConfigured;',
  '? CloudSyncDirection.bidirectional',
  ': CloudSyncDirection.uploadOnly',
  'automatic_sync_upload_only:no_backup_passphrase',
]) {
  assert(autoSync.includes(token), `automatic sync fallback missing: ${token}`);
}

const diagnostics = read('lib/services/diagnostic_center_service.dart');
assert(
  diagnostics.includes('this.lastCloudSyncFailedStage,'),
  'diagnostic snapshot sync failure fields should remain backwards compatible',
);
assert(
  !diagnostics.includes('required this.lastCloudSyncFailedStage'),
  'diagnostic snapshot new nullable fields must not break existing callers',
);

const policyTest = read('test/exam_sync_policy_test.dart');
assert(policyTest.includes('drops a stale template reference'), 'exam FK regression test missing');
const diagnosticTest = read('test/diagnostic_center_service_test.dart');
assert(diagnosticTest.includes('SYNC_EXAMS_23503'), 'diagnostic failure-code regression coverage missing');

const releaseNotes = read('docs/release_notes.md');
assert(releaseNotes.includes('Build 78 Hotfix 4'), 'release notes must document Hotfix 4');
const docsIndex = read('docs/INDEX.md');
assert(docsIndex.includes('Build 78 Hotfix 4'), 'documentation index must point to Hotfix 4');

console.log('Build 78 Hotfix 4 exam-FK, auto-sync fallback, and diagnostics validation passed.');
