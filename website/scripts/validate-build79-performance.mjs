import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.cwd(), '..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const exists = (relative) => fs.existsSync(path.join(root, relative));
const assert = (condition, message) => {
  if (!condition) {
    console.error(`Build 79 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
assert(pubspec.includes('version: 4.3.0-alpha.25+79'), 'pubspec is not Build 79');
assert(
  buildInfo.includes("versionName = '4.3.0-alpha.25'") &&
    buildInfo.includes('buildNumber = 79') &&
    buildInfo.includes("releaseLabel = 'P1.27'"),
  'AppBuildInfo is not P1.27 Build 79',
);
assert(read('lib/services/local_database_schema.dart').includes('static const int version = 26'), 'Build 79 must not change SQLite schema');

// Build78 compile regressions from the owner's real Flutter analyzer output.
const addPoint = read('lib/screens/behavior/add_point_screen.dart');
assert(addPoint.includes('FutureBuilder<double>'), 'point balance FutureBuilder still truncates decimal totals');
const honor = read('lib/screens/honor_board/honor_board_screen.dart');
assert(honor.includes('final double score;') && honor.includes('Helpers.formatNumber(score)'), 'honor board is not decimal-safe');
const halaqahReport = read('lib/screens/reports/halaqah_period_report_screen.dart');
assert(halaqahReport.includes("../../utils/helpers.dart"), 'halaqah report Helpers import is missing');
const reconciliation = read('lib/services/legacy_memorized_reconciliation_service.dart');
assert(reconciliation.includes("saveSetting(_completedKey, '1')") && !reconciliation.includes('setSetting(_completedKey'), 'legacy reconciliation uses a nonexistent settings API');
const pdf = read('lib/services/pdf_service.dart');
assert(pdf.includes('String label,\n    num value,') && pdf.includes('Helpers.formatNumber(value)'), 'PDF aggregate helper is not decimal-safe');
const reportTest = read('test/halaqah_period_report_service_test.dart');
assert(reportTest.includes('required double positive') && reportTest.includes('required double negative'), 'period report tests still force integer points');

// Safe size reductions only: unused direct packages are removed, accelerated
// crypto and the known-good production dependencies stay pinned.
for (const removed of ['cupertino_icons:', 'image_picker:', 'flutter_slidable:']) {
  assert(!pubspec.includes(removed), `unused direct dependency remains: ${removed}`);
}
for (const kept of [
  'cryptography_flutter: 2.3.4',
  'supabase_flutter: 2.14.2',
  'printing: 5.14.3',
  'share_plus: 10.0.3',
]) {
  assert(pubspec.includes(kept), `known-good dependency changed or removed: ${kept}`);
}

const gradle = read('android/app/build.gradle.kts');
const gradleProps = read('android/gradle.properties');
assert(gradle.includes('isMinifyEnabled = true'), 'R8 minification is not enabled');
assert(gradle.includes('isShrinkResources = true'), 'Android resource shrinking is not enabled');
assert(gradle.includes('proguard-android-optimize.txt'), 'optimized ProGuard defaults are not used');
assert(gradleProps.includes('android.r8.optimizedResourceShrinking=true'), 'AGP 8.7 optimized resource shrinking is not enabled');

for (const file of [
  'tools/android_release_size_report.dart',
  'tools/build_lean_android.ps1',
  'tools/build_lean_android.sh',
  '.github/workflows/build-apk.yml',
]) {
  assert(exists(file), `performance artifact missing: ${file}`);
}
const shellBuild = read('tools/build_lean_android.sh');
const psBuild = read('tools/build_lean_android.ps1');
for (const source of [shellBuild, psBuild]) {
  assert(source.includes('flutter analyze') && source.includes('flutter test'), 'lean release skips quality gates');
  assert(source.includes('--split-per-abi'), 'lean release does not split APKs by ABI');
  assert(source.includes('flutter build appbundle'), 'lean release does not produce an AAB');
  assert(source.includes('android_release_size_report.dart'), 'lean release does not measure artifacts');
}
const workflow = read('.github/workflows/build-apk.yml');
assert(workflow.includes('--split-per-abi'), 'GitHub Android release still builds a universal-only APK');
assert(workflow.includes('flutter build appbundle'), 'GitHub Android release does not build AAB');
assert(workflow.includes('android-size-report.md'), 'GitHub Android release does not publish size reporting');

// A slow/failed study-suspension RPC must no longer hold the entire sync.
const sync = read('lib/services/supabase_service.dart');
assert(sync.includes('Duration(seconds: 12)') && sync.includes('study_suspension_upload_timeout'), 'study-suspension sync timeout/defer policy is missing');
assert(sync.includes('jsonEncode(failedDeletedDates)'), 'failed suspension deletes are not retained for retry');
const home = read('lib/screens/home/home_screen.dart');
assert(!home.includes("Text('فشلت المزامنة: $e')"), 'home still exposes raw cloud exceptions');
assert(home.includes('ستُعاد المحاولة تلقائيًا'), 'home sync failure does not explain offline retry');

assert(read('lib/screens/settings/whats_new_screen.dart').includes('P1.27 Build 79'), "What's New missing Build79");
console.log('Build 79 Android performance, compile hotfix, and sync resilience validation passed.');
