# Build 78 Hotfix 3 — Validation Report

Date: 2026-08-16

## Scope

Hotfix 3 repairs the current Supabase upsert contract, makes cloud synchronization stage-aware and diagnosable, reduces foreground/background network work, and starts a low-risk modularization of synchronization UI/policies.

## Automated validation in the review environment

- `validate-build78-hotfix1.mjs`: passed.
- `validate-build78-hotfix2.mjs`: passed.
- `validate-build78-hotfix3.mjs`: passed.
- Cloud sync direction, P1.16, P1.22–P1.26, Build74 hardening, Build75, Build76, Build77 and Build78 source validators: passed.
- Full release list contains 69 validators. **66 validators passed** in this source-only environment.
- Three validators were not executable because the submitted source does not contain `website/node_modules/typescript` and this environment did not install web dependencies:
  - `validate-p1-21-completion.mjs`
  - `test-build74-runtime.mjs`
  - `test-build75-runtime.mjs`

This is an environment/dependency limitation, not a reported assertion failure. Run `tools/setup_web.ps1` or `npm ci` on the owner machine before the complete web validation suite.

## Flutter validation

The owner confirmed Hotfix 2 passed `flutter analyze`, all 146 tests, Android debug build, installation, and startup before this Hotfix 3 change set. Flutter/Dart SDK is not installed in the review container, therefore Hotfix 3 must still be checked on the owner machine with:

```text
flutter analyze
flutter test
flutter run
```

Two new pure regression tests were added for adaptive retry and privacy-safe sync progress metadata.

## SQL safety gates

`P1.27_BUILD78_HOTFIX3_APPLY.sql`:

- contains no `DELETE FROM` data cleanup;
- aborts if duplicate business keys are present;
- adds the missing unique conflict-target indexes;
- adds read-path indexes used by synchronization;
- is identical to its timestamped migration copy.

`P1.27_BUILD78_HOTFIX3_VERIFY.sql` is read-only and is identical to its timestamped verification copy. It checks the new unique indexes, duplicate business keys, required synchronization RPCs, and core tables.

## Live acceptance still required

1. Supabase backup.
2. APPLY Hotfix 3.
3. VERIFY: every row must show `passed=true`.
4. Flutter analyze/test/run.
5. Manual **upload-only** sync.
6. Bidirectional sync.
7. Two-device create/update/delete acceptance.
