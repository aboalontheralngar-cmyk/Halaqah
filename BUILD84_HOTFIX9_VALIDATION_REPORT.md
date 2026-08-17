# Build 84 Hotfix 9 validation report

Build: `4.3.0-alpha.27+84`  
SQLite: `28`

## Focused source contract

`node website/scripts/validate-build84-hotfix9.mjs`

Result: **PASS — 46/46 checks**.

The focused contract covers:

- incremental sync watermarks and no-change stage skipping;
- tombstone max-id short-circuiting;
- incremental attendance, homework and memorization paths;
- cloud-replay dirty-trigger suppression;
- sync indexes and authoritative cloud `updated_at` triggers;
- supervisory onboarding RPC recovery and PostgREST schema reload;
- Google OAuth PKCE callback/session hydration and Site-URL fallback;
- connected cross-surah revision selection;
- progressive extra-memorization reward tiers;
- printed above-target marker and khatm-remaining indicator.

## Regression source contracts

The following source validators also passed:

- `website/scripts/validate-cloud-sync-direction.mjs`
- `website/scripts/validate-connected-revision.mjs`
- `website/scripts/validate-period-reports.mjs`
- `website/scripts/validate-supervisory-hierarchy.mjs`
- `website/scripts/validate-student-portal.mjs`

## Environment limitations

This review environment does not contain the Flutter/Dart SDK, so `flutter analyze` and `flutter test` cannot be executed here. The uploaded website source also does not contain a usable TypeScript/Next toolchain package set, so a production Next.js compile cannot be executed here.

Before installing on a device, run locally:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter test
```

Do not proceed to `flutter run` unless analyze and tests are fully green.
