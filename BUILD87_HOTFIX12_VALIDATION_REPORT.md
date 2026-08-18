# Build 87 Hotfix 12 — Validation report

Date: 2026-08-18
Version: `4.3.0-alpha.30+87`
SQLite schema: 28 (unchanged)

## Automated source-contract checks

- `node website/scripts/validate-build87-hotfix12.mjs` — **PASS 29/29**.
- `validate-student-portal.mjs` — **PASS** after updating the validator to the same-origin proxy architecture.
- `validate-family-portal.mjs` — **PASS**; validator now accepts SQLite schema 27 or newer instead of hard-coding the historical v27.
- `validate-supervisory-hierarchy.mjs` — **PASS**.
- `validate-responsive-layout.mjs` — **PASS**.
- `validate-web-react-stability.mjs` — **PASS**.
- `validate-release-integrity.mjs` — **PASS**.
- `validate-operational-readiness.mjs` — **PASS**.
- `validate-open-recitation.mjs` — **PASS**.
- `validate-revision-continuity.mjs` — **PASS**.
- `validate-connected-revision.mjs` — **PASS**.

## Syntax / structural checks

- Modified Dart files passed a lexical delimiter/string/comment balance scan.
- Modified TypeScript/TSX files passed a global `tsc --noResolve` syntax-class scan with **no parser errors**. Full type/module resolution cannot run from this source archive because `website/node_modules` is intentionally absent.
- `flutter`/`dart` SDK is not installed in the review container, so `flutter analyze` and `flutter test` must be run on the owner's Windows environment before `flutter run`.

## Database / deployment

`P1.27_BUILD87_HOTFIX12_APPLY.sql` is additive/idempotent and:

- reasserts pgcrypto-aware search paths for student portal RPCs;
- repairs all four supervision invitation RPC search paths;
- restores authenticated EXECUTE grants for invitation RPCs;
- installs a service-role-only `student_portal_runtime_health()` probe;
- notifies PostgREST to reload schema metadata.

`P1.27_BUILD87_HOTFIX12_VERIFY.sql` is read-only and checks the portal contract, pgcrypto, invitation functions, their search paths and execute privileges.

The Edge Function must be redeployed after SQL using `tools/deploy_student_portal.ps1`; otherwise the live function remains on its old code even if the website is redeployed.

## Acceptance tests required on owner device / production

1. Vertical and slightly diagonal scrolling in the recitation student list never launches memorization/revision.
2. A deliberate horizontal swipe still opens the intended action.
3. Overflow menu displays memorization, revision, talaqqin, session, memorized view and history.
4. Expandable FAB exposes quick memorization/revision/talaqqin.
5. `/api/student-portal` returns an `ok: true` health response after Vercel + Edge deployment.
6. Student code + PIN can log in and load the dashboard.
7. Supervision center/member invitation generation succeeds.
8. Light/dark switching does not mix dark text variants into a light surface.
9. Points such as `90.86000000000001` render as `90.86`.
