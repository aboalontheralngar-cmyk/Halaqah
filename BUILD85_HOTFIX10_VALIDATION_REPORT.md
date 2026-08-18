# Build 85 Hotfix 10 validation report

## Passed

- `node website/scripts/validate-build85-hotfix10.mjs`: 23/23 checks passed.
- `node website/scripts/validate-cloud-sync-direction.mjs`: passed.
- `node website/scripts/validate-supervisory-hierarchy.mjs`: passed.
- `website/package.json` parses successfully as JSON.

## Source contracts covered

- Remote memorization rows validate the upper ayah boundary before local replay.
- A batch validation failure falls back to per-row replay and skips only the malformed row.
- Auth-created placeholder profiles no longer count as completed onboarding.
- Existing center owners, teachers/admin members, and supervisory members remain recognized.
- Google/password sign-in routes through the same post-auth profile decision.
- Onboarding completion is recorded only after center/supervisory creation succeeds.
- Account identity is visible in center selection and the desktop dashboard.
- Dashboard logout revokes the Supabase session.
- Build 85 SQL adds/backfills/verifies `profiles.onboarding_completed`.

## Environment limitations

- Flutter/Dart SDK is not installed in this review environment, so `flutter analyze` and `flutter test` must be run on the owner's Flutter workstation before `flutter run`.
- The uploaded source does not contain a complete `website/node_modules`. An attempted `npm ci --ignore-scripts` timed out, and `tsc --noEmit` therefore stopped on missing type-definition packages before project type-checking.
- The historical `validate-p7-student-platform.mjs` still pins SQLite schema 27 while the current application is schema 28; that historical version assertion is stale and is not a Build 85 regression.
