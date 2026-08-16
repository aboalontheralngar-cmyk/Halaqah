# P1.27 Build 80 Hotfix 5 — Validation Report

Date: 2026-08-16

## Validated in review environment

- `validate-build78-completion.mjs`: PASS
- `validate-build78-hotfix1.mjs`: PASS
- `validate-build78-hotfix2.mjs`: PASS
- `validate-build78-hotfix3.mjs`: PASS
- `validate-build78-hotfix4.mjs`: PASS
- `validate-build80-hotfix5.mjs`: PASS
- `test-build78-runtime.mjs`: PASS

## Environment limitation

Flutter/Dart SDK is not installed in the review container, so `flutter analyze` and `flutter test` must be executed on the owner's Flutter workstation before `flutter run`.

The historical full validator chain currently stops at `validate-build74-hardening.mjs` because `database_service.dart` is already 5206 lines in the incoming Hotfix 4 source while that older validator asserts fewer than 5200 lines. This pre-existing validator threshold is unrelated to Hotfix 5. The targeted Build 78/80 release gates listed above pass.

## Recovery assertions

- Build/versionCode is 80, preventing the observed 79 -> 78 downgrade path.
- Prerequisite script refuses a connected Android device whose installed versionCode is newer than the local source when ADB is discoverable.
- Cloud backup discovery scans all center folders below the authenticated user's Storage root, not only the locally remembered center.
- Restore pauses auto-sync and adds a 15-minute post-restore grace window.
- Full backup snapshots include students and memorization progress.
- Memorization upload no longer decodes every historical cloud row; malformed download rows are isolated and counted instead of aborting the whole stage.
