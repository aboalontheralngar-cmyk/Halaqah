# P1.27 Build 76 — Validation Report

**Version:** `4.3.0-alpha.22+76`  
**SQLite:** `25`  
**Date:** 2026-08-14  
**Baseline:** P1.27 Build 75 Hotfix 3 (`4.3.0-alpha.21+75`, SQLite 24)

## Baseline already proven on the owner's device

The owner previously ran Build 75 Hotfix 3 on the real Flutter/Android toolchain and confirmed:

- `flutter pub get` succeeded;
- `flutter analyze` returned **No issues found**;
- `flutter test` returned **All tests passed (134 at that baseline)**;
- Android debug APK built, installed, and started on the device;
- Supabase Build 75 VERIFY returned `passed=true` for all shown checks.

These are baseline results and are not falsely attributed to Build 76.

## Build 76 checks executed in the editing environment

- **61/61 release validators passed.**
  - The three runtime validators that import TypeScript were executed with the globally installed TypeScript 5.8.3 exposed through a temporary `website/node_modules/typescript` symlink.
  - The temporary symlink was removed immediately after validation and is not shipped.
- **64 JavaScript/MJS/CJS files** passed `node --check`.
- **53 TypeScript/TSX files** passed parse/transpile diagnostics with TypeScript 5.8.3.
- `validate-build76-completion.mjs` passed after the final Build 76 changes.
- Build 74 hardening, Build 75 P1.27, Hotfix 2, Hotfix 3, and Build 75 runtime compatibility checks all still pass.
- The direct dependency and dev-dependency blocks in `pubspec.yaml` are unchanged from the known-good Hotfix 3 baseline; only the application version changed.
- `DatabaseService` remains at **5196 lines**, below the Build 74 anti-regression ceiling.
- `P1.27_BUILD76_APPLY.sql` is byte-identical to its source migration.

## Build 76 functional contracts covered by validators/source tests

- durable SQLite delete outbox and composite attendance/mushaf delete selectors;
- cloud tombstones are consumed before outbound deletes/upserts;
- guarded atomic cloud deletion of a student;
- retry after network recovery/resume/auth change;
- supervision center drill-down contract and UI route;
- weekly peer ranking metrics and UI;
- structured monthly exam template + six questions + template link + atomic local persistence;
- bidirectional exam template/question sync;
- Light/Dark semantic contrast tests and AppBar tab fixes;
- ErrorWidget source/operation/fingerprint diagnostics;
- configurable proportional-points rounding policy;
- incremental Build 76 SQL health contract and security-definer `search_path` protection.

## Checks that require the owner's environment

### Flutter / Android

Flutter/Dart SDK is not installed in this editing environment, so Build 76 still needs the real-device acceptance sequence:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
flutter run
```

Build 76 intentionally does **not** change the dependency versions that succeeded in Hotfix 3. Keep the owner's current `pubspec.lock`.

### Supabase live database

The Build 76 SQL was prepared and statically validated but was not executed against the owner's live project from this environment. Run:

1. `website/supabase/P1.27_BUILD76_APPLY.sql`
2. `website/supabase/P1.27_BUILD76_VERIFY.sql`

Every VERIFY row must return `passed=true`.

### Next.js full quality/build

The source package does not ship `website/node_modules`. TypeScript parsing and all release validators passed, but a full `npm ci && npm run quality:ci`/Next build still needs a machine with the npm dependency set available.

## Acceptance scenarios to run after installation

1. Device A creates/updates data offline, reconnects, and the cloud receives it automatically.
2. Device A deletes a synchronized record while Device B is offline; B reconnects and does not resurrect the deleted record.
3. Repeat the deletion test for `mushaf_progress` and, using test data, a student.
4. Supervisor owner/admin opens center → halaqat → student performance; analyst remains read-only.
5. Light and Dark mode QA on memorization/revision tabs, chips, status controls, and student details.
6. Monthly plan exam creates a template, six questions, result, and syncs them to a second device.
7. Peer groups show weekly ranking based on new memorization, review, and behavior points.
8. Verify nearest/floor/ceil recitation-point rounding from Settings.

## Packaging integrity

The final release packaging step uses two artifacts:

- modified-files-only patch over Build 75 Hotfix 3: **79 files**;
- full source upgrade without font binaries/runtime caches: **705 files**.

Both ZIP archives are checked with `unzip -t`, and the patch files are compared byte-for-byte against the Build 76 working tree before delivery. SHA-256 hashes are generated after the final repack.

## Build 76 Hotfix 1 follow-up

Owner-device acceptance exposed three Flutter compile regressions not detectable in the editing environment because Flutter/Dart SDK is unavailable here: an int/num assignment in peer grouping, invalid dropdown callback syntax, and a missing semantic-theme import. Hotfix 1 corrects all three and adds a dedicated regression validator. Supabase Build 76 VERIFY was reported fully green by the owner, so this hotfix contains no SQL changes.
