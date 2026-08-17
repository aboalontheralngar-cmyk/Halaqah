import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 80 Hotfix 5 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const pubspecBuild = Number(pubspec.match(/version:\s+[^+\s]+\+(\d+)/)?.[1] ?? 0);
const appBuild = Number(buildInfo.match(/buildNumber\s*=\s*(\d+)/)?.[1] ?? 0);
assert(pubspecBuild >= 80, 'pubspec must be Build 80 or newer');
assert(appBuild >= 80, 'AppBuildInfo must be Build 80 or newer');

const prerequisites = read('tools/verify_source_prerequisites.ps1');
for (const token of [
  'INSTALL_FAILED_VERSION_DOWNGRADE',
  'Android data-safety stop:',
  'installedVersionCode -gt $localVersionCode',
  'Do NOT let Flutter uninstall the newer app',
]) {
  assert(prerequisites.includes(token), `Android downgrade guard missing: ${token}`);
}

const backup = read('lib/services/cloud_backup_service.dart');
for (const token of [
  'Future<List<CloudBackupEntry>> listBackups()',
  "final rootObjects = await storage.list(path: userId);",
  "await collectPrefix('$userId/$childName');",
  '_validateEntryUserScope(entry, userId);',
]) {
  assert(backup.includes(token), `account-wide cloud recovery discovery missing: ${token}`);
}
assert(
  !backup.includes("entry.remotePath.startsWith('${scope.prefix}/')"),
  'recovery downloads must not be restricted to the newly configured center',
);

const settings = read('lib/screens/settings/settings_screen.dart');
for (const token of [
  'await CloudAutoSyncCoordinator.instance.pauseForRecovery();',
  'CloudAutoSyncCoordinator.instance.resumeAfterRecovery();',
  'restoredStudentCount',
  'restoredMemorizationCount',
  'لا تبدأ المزامنة قبل التأكد من الأعداد',
]) {
  assert(settings.includes(token), `restore safety UI missing: ${token}`);
}

const autoSync = read('lib/services/cloud_auto_sync_coordinator.dart');
for (const token of [
  '_pausedForRecovery',
  'recoveryGracePeriod = Duration(minutes: 15)',
  'automatic_sync_deferred:recent_restore',
  'waitForActiveSync()',
]) {
  assert(autoSync.includes(token), `recovery sync guard missing: ${token}`);
}

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  'Future<void> waitForActiveSync()',
  'last_cloud_memorization_skipped_count',
  'remoteUpdatedAtById',
  '_isMalformedRemoteMemorizationError',
  '_requiredRemoteInt',
  '_requiredRemoteDate',
]) {
  assert(sync.includes(token), `memorization recovery hardening missing: ${token}`);
}
const memorizationStart = sync.indexOf('Future<void> _syncMemorizationProgress(');
const memorizationEnd = sync.indexOf('Future<void> _syncDeletedRows(', memorizationStart);
const memorizationSection = sync.slice(memorizationStart, memorizationEnd);
assert(
  memorizationSection.includes('if (!direction.shouldDownload) return;'),
  'upload-only memorization sync must avoid decoding historical remote rows',
);
assert(
  memorizationSection.includes('remote_row_skipped:'),
  'malformed legacy cloud rows must be isolated instead of aborting recovery',
);

const database = read('lib/services/database_service.dart');
for (const table of ['students', 'memorization_progress', 'settings']) {
  assert(database.includes(`'${table}',`), `backup snapshot must include ${table}`);
}
assert(database.includes('Future<void> restoreFromBackup('), 'atomic backup restore must remain available');

const diagnostics = read('lib/services/diagnostic_center_service.dart');
assert(
  diagnostics.includes('سجلات حفظ سحابية تحتاج مراجعة'),
  'diagnostics must expose skipped malformed memorization rows',
);

const releaseNotes = read('docs/release_notes.md');
assert(releaseNotes.includes('Build 80 Hotfix 5'), 'release notes must document Hotfix 5');
const recoveryDoc = read('docs/P1.27_BUILD80_HOTFIX5_RECOVERY.md');
for (const token of [
  '`versionCode` إلى `80`',
  'استعادة من السحابة',
  'SYNC_MEMORIZATION_ARGUMENTERROR',
]) {
  assert(recoveryDoc.includes(token), `recovery documentation missing: ${token}`);
}

console.log('Build 80 Hotfix 5 disaster-recovery and memorization-sync validation passed.');
