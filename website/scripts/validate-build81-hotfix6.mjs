import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 81 Hotfix 6 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const pubspecBuild = Number(pubspec.match(/version:\s+[^+\s]+\+(\d+)/)?.[1] ?? 0);
const appBuild = Number(buildInfo.match(/buildNumber\s*=\s*(\d+)/)?.[1] ?? 0);
assert(pubspecBuild >= 81, 'pubspec must use Build 81 or newer');
assert(appBuild >= 81, 'AppBuildInfo must use Build 81 or newer');

const outbox = read('lib/services/local_sync_delete_outbox.dart');
for (const token of [
  'pruneRowsThatStillExist',
  'acknowledgeMany',
  'SELECT CAST(id AS TEXT)',
  "RegExp(r'^[A-Za-z0-9_]+$')",
]) {
  assert(outbox.includes(token), `local outbox optimization missing: ${token}`);
}

const database = read('lib/services/database_service.dart');
for (const token of [
  'pruneRestoredSyncDeletes',
  'acknowledgeSyncDeletes',
  "'sync_remote_delete_replay', 'value': '1'",
  "'remote_table': 'students'",
  'delete_student_for_sync()',
]) {
  assert(database.includes(token), `student delete/outbox compaction missing: ${token}`);
}

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  '_deleteRemoteIdOperations',
  '_deleteRemoteIdChunkWithIsolation',
  ".delete().inFilter('id', remoteIds)",
  ".inFilter('exam_id', remoteIds)",
  '.delete().or(clauses.join(','))',
  '_chunks(fallback, 6)',
  'رفع عمليات الحذف المحلية ($safeCompleted/$total)',
  "delete_outbox_pending:$remaining",
  ".delete().inFilter('exam_id', chunk)",
]) {
  assert(sync.includes(token), `delete sync batching missing: ${token}`);
}
assert(
  !sync.includes("await client.from('exam_scores').delete().eq('id', id);"),
  'legacy exam score delete must not compare exam_scores.id with exam id',
);

const releaseNotes = read('docs/release_notes.md');
assert(releaseNotes.includes('Build 81 Hotfix 6'), 'release notes must document Hotfix 6');
const doc = read('docs/P1.27_BUILD81_HOTFIX6_DELETE_SYNC.md');
for (const token of ['delete_outbox', '`inFilter`', 'لا توجد migration جديدة']) {
  assert(doc.includes(token), `Hotfix 6 documentation missing: ${token}`);
}

console.log('Build 81 Hotfix 6 delete-sync batching validation passed.');
