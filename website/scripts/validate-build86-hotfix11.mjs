import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../..');
const read = (relative) => fs.readFileSync(path.join(root, relative), 'utf8');
const exists = (relative) => fs.existsSync(path.join(root, relative));
let checks = 0;
const assert = (condition, message) => {
  checks += 1;
  if (!condition) {
    console.error(`Build 86 Hotfix 11 validation failed: ${message}`);
    process.exit(1);
  }
};

const pubspec = read('pubspec.yaml');
const buildInfo = read('lib/app/build_info.dart');
const plans = read('lib/screens/plans/plans_screen.dart');
const db = read('lib/services/database_service.dart');
const recitation = read('lib/screens/memorization/memorization_screen.dart');
const home = read('lib/screens/home/home_screen.dart');
const hijri = read('lib/widgets/dual_calendar_date_picker.dart');
const report = read('lib/screens/reports/halaqah_period_report_screen.dart');
const incidents = read('lib/services/operational_incident_service.dart');
const main = read('lib/main.dart');

assert(pubspec.includes('version: 4.3.0-alpha.29+86'), 'pubspec version is not Build 86');
assert(buildInfo.includes("versionName = '4.3.0-alpha.29'") && buildInfo.includes('buildNumber = 86'), 'AppBuildInfo is stale');
assert(plans.includes('_selectedPlanIds') && plans.includes('_deleteSelectedPlans'), 'plan selection/bulk delete missing');
assert(plans.includes("tooltip: 'طباعة المحدد'") && plans.includes("tooltip: 'طباعة جميع الخطط الحالية'"), 'selected/all printing actions missing');
assert(plans.includes('_printPlans(_selectedPlans)') && plans.includes('_printPlans(_plans)'), 'bulk print routing missing');
assert(db.includes('Future<void> deleteSmartPlans(Iterable<SmartPlan> plans)'), 'atomic bulk plan delete missing');
assert(db.includes("where: 'id IN ($placeholders)'"), 'bulk plan delete is not batched');
assert(recitation.includes("package:flutter_slidable/flutter_slidable.dart"), 'slidable package not used');
assert(recitation.includes('startActionPane: canMemorize') && recitation.includes('endActionPane: canRevise'), 'memorization/revision swipe panes missing');
assert(recitation.includes("label: memorizationDone ? 'تعديل الحفظ' : 'الحفظ'") && recitation.includes("label: revisionDone ? 'تعديل المراجعة' : 'المراجعة'"), 'swipe labels missing');
assert(recitation.includes("value: 'talaqqin'") && recitation.includes("value: 'session'") && recitation.includes("value: 'view'"), 'overflow student actions missing');
assert(!recitation.includes('TabController') && !recitation.includes('TabBarView'), 'legacy recitation tabs still present');
assert(!exists('lib/screens/memorization/memorization_plan_screen.dart'), 'obsolete memorization plan page still exists');
assert(!recitation.includes('MemorizationPlanScreen'), 'obsolete plan route still referenced');
assert(home.includes('AppCompactActionGrid(children: [') && home.match(/_buildCompactActionItem\(/g)?.length >= 18, 'advanced home tools are not compact grid tiles');
assert(hijri.includes('childAspectRatio: 0.84') && hijri.includes('FittedBox('), 'Hijri compact-phone overflow hardening missing');
assert(report.includes('childAspectRatio: compact ? 1.35 : 1.40') && report.includes('maxLines: 2'), 'aggregate report overflow hardening missing');
assert(incidents.includes('[halaqah.incident] code=') && incidents.includes('kDebugMode'), 'privacy-safe debug incident trace missing');
assert(main.includes("label: const Text('العودة بأمان')"), 'safe ErrorWidget back action missing');
assert(read('docs/release_notes.md').startsWith('# Build 86 Hotfix 11'), 'release notes not updated');
assert(exists('docs/P1.27_BUILD86_HOTFIX11_UI_WORKFLOWS.md'), 'Build 86 documentation missing');
assert(exists('P1.27_BUILD86_HOTFIX11_INSTALL_NOTE.md'), 'Build 86 install note missing');

console.log(`Build 86 Hotfix 11 validation passed: ${checks}/${checks} checks.`);
