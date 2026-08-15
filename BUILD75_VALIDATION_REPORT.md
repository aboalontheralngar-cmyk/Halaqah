# Build 75 Validation Report

**Halaqati / حلقتي — P1.27 Build 75**  
**Version:** `4.3.0-alpha.21+75`  
**SQLite:** `24`  
**Date:** 2026-08-12

## Passed in the packaging environment

- Release validators: **58 / 58 passed**.
- TypeScript/TSX syntax/transpile check: **49 files passed**.
- JavaScript syntax (`node --check`): **59 files passed, 0 failed**.
- Changed Dart structural scan: **38 files passed**.
- JSON, Android XML and iOS plist parse checks: passed.
- Build 75 SQL static transaction/function/read-only checks: passed.
- Secret/package scan: no production `.env`, private key, JWT value or keystore included.
- Current version identity check: `4.3.0-alpha.21+75 / P1.27` passed.
- Old generic P7.3 application message: not present in current application source.

## Important execution limits

This environment does not contain Flutter/Dart SDK or `psql`, so `flutter analyze`, `flutter test`, device execution and live Supabase migration were **not** run here.

A complete `npm ci` could not be completed in this environment: offline mode was missing one locked package (`zustand@5.0.12`), while registry access did not complete within the execution environment. Therefore `npm run quality:ci`, full Next.js build, ESLint and npm audit must be run in the owner's connected development/CI environment.

## Required owner acceptance

1. Back up the existing project and Supabase database.
2. Apply `website/supabase/P1.27_BUILD75_APPLY.sql` to the correct existing database.
3. Run `website/supabase/P1.27_BUILD75_VERIFY.sql`; every `passed` row must be `true`.
4. Run `flutter analyze` and `flutter test`.
5. Run `cd website && npm ci && npm run quality:ci`.
6. Test supervisory owner/admin center creation, analyst read-only access, dark/light UI, three-day backdating, holiday rollback, and two-device offline deletion convergence.

Detailed Arabic validation notes: `docs/P1.27_VALIDATION.md`.

## Packaging integrity

- Full source package contents: **685 files** before final report refresh; generated dependency/build directories and font binaries are excluded by policy.
- Modified-files-only package: **87 files** (`25 added + 62 modified + 0 deleted` versus Build 74).
- The modified package files were SHA-256 compared byte-for-byte to the Build 75 working tree: **87 / 87 matched**.
- `unzip -t` reported no compressed-data errors for both package types.
- The user-provided database context export is not copied into either package.
- Final archive SHA-256 values are distributed separately in `Halaqah-P1.27-build75-SHA256.txt` so the checksums do not recursively change the archives themselves.

## Build 75 Hotfix 1 — Flutter dependency resolution

- Owner runtime evidence: `flutter_test` from the installed Flutter SDK requires `path 1.9.1`; the previous project pin `path 1.8.3` made Pub version solving impossible.
- `pubspec.yaml` is corrected to the exact direct dependency `path: 1.9.1`, preserving the Build 74 no-caret direct-dependency policy.
- `validate-build74-hardening.mjs`: **PASS** after the correction.
- `validate-build75-p127.mjs`: **PASS** after the correction.
- Full `run-all-validations.mjs` progressed successfully through P1.20 in this sandbox, then stopped at P1.21 because `website/node_modules/typescript` is not installed in the packaged source. This is an environment/dependency absence, not a validator failure caused by the hotfix.
- Flutter SDK is not installed in this sandbox, so the authoritative acceptance for this hotfix is the owner's rerun of `flutter pub get`, followed by `flutter analyze` and `flutter test`.
- No SQL or SQLite migration is introduced by Hotfix 1.
## Build 75 Hotfix 2 — Owner compile evidence and dependency repair

- Live Supabase acceptance: owner ran `P1.27_BUILD75_VERIFY.sql`; all displayed checks returned `passed = true`. No database re-apply is required.
- Owner `flutter pub get`: succeeded after Hotfix 1, but reported **41 dependency changes/downgrades**.
- Owner `flutter analyze`: identified the compile blockers corrected by Hotfix 2 (`publishableKey`, three invalid `saveText` arguments, `FontWeight.black`) plus minor analyzer cleanup.
- Owner `flutter test`/`flutter run`: additionally exposed `printing 5.11.1` incompatibility with the current Flutter `ViewConfiguration` API. Hotfix 2 pins `printing 5.14.3` and restores the newer direct dependency set.
- Static Hotfix 2 validator: **PASS**; it checks dependency pins and prevents regression of the exact compile traps from the owner log.
- Flutter SDK is still not installed in the packaging sandbox, so the owner's rerun remains the authoritative compile/test acceptance.
- No SQL or SQLite migration is introduced by Hotfix 2.
## Build 75 Hotfix 3 — Pub solver compatibility

- Live Supabase acceptance remains complete: the owner's VERIFY screenshot reports every Build 75 check as `passed = true`; no database re-apply is required.
- Owner `flutter pub get` on Hotfix 2 exposed a deterministic dependency conflict: `share_plus 9.0.0` requires `web ^0.5.0`, while `printing 5.14.3` is on the `web 1.x` generation.
- Hotfix 3 pins `share_plus 10.0.3`, whose 10.x line migrated to `package:web ^1.0.0` while preserving the static Share APIs used by this codebase.
- Static Hotfix 3 validator: **PASS**. Build 74 hardening, Build 75 feature guard, Hotfix 2 compile-regression guard, and Hotfix 3 dependency-pair guard all passed after the final pin change.
- Flutter SDK is not installed in the packaging sandbox, so the owner's `flutter pub get/analyze/test/run` remains the authoritative runtime acceptance.
- No SQL or SQLite migration is introduced by Hotfix 3.

