import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 78 Hotfix 1 validation failed: ${message}`);
    process.exit(1);
  }
};

const addPoint = read('lib/screens/behavior/add_point_screen.dart');
assert(addPoint.includes('FutureBuilder<double>'), 'point balance FutureBuilder must accept decimal totals');
assert(addPoint.includes('Helpers.formatNumber(snapshot.data ?? 0)'), 'point balance must format decimals safely');

const honor = read('lib/screens/honor_board/honor_board_screen.dart');
assert(honor.includes('final num score;'), 'honor board score must accept decimal points');
assert(honor.includes('String _formatScore(num score)'), 'honor board formatter must accept decimal points');

const aggregate = read('lib/screens/reports/halaqah_period_report_screen.dart');
assert(aggregate.includes("import '../../utils/helpers.dart';"), 'halaqah report is missing Helpers import');

const reconciliation = read('lib/services/legacy_memorized_reconciliation_service.dart');
assert(reconciliation.includes("saveSetting(_completedKey, '1')"), 'legacy reconciliation must use DatabaseService.saveSetting');
assert(!reconciliation.includes('setSetting(_completedKey'), 'removed DatabaseService.setSetting call returned');

const pdf = read('lib/services/pdf_service.dart');
assert(pdf.includes('String label,\n    num value,\n    PdfColor color,'), 'PDF aggregate values must accept decimal points');
assert(pdf.includes('Helpers.formatNumber(value)'), 'PDF decimal points must be formatted without trailing noise');

const reportTest = read('test/halaqah_period_report_service_test.dart');
assert(reportTest.includes('positivePoints: positive.toDouble()'), 'period report fixture must pass decimal positive points');
assert(reportTest.includes('negativePoints: negative.toDouble()'), 'period report fixture must pass decimal negative points');

const sync = read('lib/services/supabase_service.dart');
for (const token of [
  "import 'dart:async';",
  '_ensureCloudReachable()',
  '_syncRpcTimeout = Duration(seconds: 12)',
  '_callIdempotentSyncRpc',
  '_studySuspensionFingerprint',
  '_studySuspensionFingerprintKey',
  "client.rpc(functionName, params: params)",
  "'connection abort'",
]) {
  assert(sync.includes(token), `sync hardening token missing: ${token}`);
}
assert(sync.includes("await _ensureCloudReachable();"), 'sync must preflight cloud reachability');
assert(sync.includes(".timeout(\n      _syncRpcTimeout"), 'study suspension download must have a bounded timeout');

const home = read('lib/screens/home/home_screen.dart');
const settings = read('lib/screens/settings/settings_screen.dart');
assert(home.includes('supabase.describeSyncFailure(e)'), 'home sync must show a safe network message');
assert(settings.includes('SupabaseService.instance.describeSyncFailure(error)'), 'settings sync must show a safe network message');
assert(!home.includes("content: Text('فشلت المزامنة: $e')"), 'raw sync exception is still exposed on Home');

const apply = read('website/supabase/P1.27_BUILD78_APPLY.sql');
const migration = read('website/supabase/migrations/20260815000100_build78_reports_plans_supervisor_competitions.sql');
assert(apply === migration, 'Hotfix must not change Build78 SQL');

console.log('Build 78 Hotfix 1 compile and sync regression validation passed.');
