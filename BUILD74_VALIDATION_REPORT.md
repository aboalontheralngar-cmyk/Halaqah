# P1.26 Build 74 - Validation Report

- Release: `4.3.0-alpha.20+74`
- SQLite schema: `24` (unchanged)
- Package date: `2026-08-12`
- Release gates: **56/56 passed**
- TypeScript/JavaScript syntax parse: **106 files passed**
- Build 74 runtime behavior tests: **passed**
  - `Asia/Aden` local business-date boundary around UTC midnight
  - supervision error classification and Build 74 repair guidance
- `git diff --check`: **passed**
- shell syntax (`build_lean_android.sh`, `verify_source_prerequisites.sh`): **passed**
- static security review of shipped SQL: every `SECURITY DEFINER` block checked includes a pinned `search_path` with `pg_temp`
- source scans: no business-date UTC extraction in `website/src`; no broad `useStore()` calls; no raw production console logging outside the privacy-safe logger; no Dart `print()`; no old P7.3 generic error text; no legacy QR HMAC secret in app source.

## Environment-limited checks

The following checks could not be executed in this sandbox and **must not be interpreted as passed**:

1. `flutter analyze` and `flutter test`: Flutter/Dart SDK is not installed here.
2. `npm ci`, ESLint, Next.js production build, and `npm audit`: npm registry resolution failed with `EAI_AGAIN registry.npmjs.org`.
3. Live Supabase migration execution: no owner database credentials/remote SQL session were provided. The Build 74 migrations and read-only verifier were prepared and statically audited, but must be applied to the confirmed production project by the owner.

## Database apply order

For the current P1.26 database, use:

1. `website/supabase/P1.26_BUILD74_APPLY.sql`
2. `website/supabase/P1.26_BUILD74_VERIFY.sql`

Every result row from the verification file is expected to report `passed = true`.
Do **not** run `website/database_schema.sql` on an existing database.

## Source package prerequisites

The source-upgrade archive intentionally contains no font binaries. Before a Flutter release build, retain the existing Tajawal font files in the full project and run the included source prerequisite check. The checker also generates/validates `pubspec.lock` using the installed Flutter SDK rather than shipping a fabricated lockfile.
