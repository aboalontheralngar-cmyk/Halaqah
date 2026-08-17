# Build 81 Hotfix 6 Validation Report

Date: 2026-08-17

## Scope

Hotfix 6 targets the long-running `delete_outbox` stage during device-to-cloud upload.

## Static release validation

- `validate-build81-hotfix6.mjs`: PASS.
- `validate-build80-hotfix5.mjs`: PASS after making historical version checks forward-compatible.
- `validate-build78-hotfix4.mjs`: PASS.
- `validate-build78-hotfix3.mjs`: PASS.
- `validate-build78-completion.mjs`: PASS.
- `run-all-validations.mjs`: the first 48 validators passed. Execution then stopped at `validate-p1-21-completion.mjs` because the uploaded source does not contain `website/node_modules/typescript`. This is an environment/dependency absence, not a Hotfix 6 assertion failure.

## Code-path checks

- Outbox false-delete pruning is bulk SQLite per table.
- Direct UUID deletes are batched with Supabase `inFilter`.
- Attendance/Mushaf composite deletes are batched with PostgREST `or(...)` clauses.
- Batch isolation only splits row-specific PostgreSQL failures (`23503`, `23514`, `22P02`) and does not explode a network/table-wide failure into one request per row.
- Student deletion suppresses cascade-generated outbox rows and enqueues one student delete operation.
- Legacy exam-score deletion now filters by `exam_id` rather than comparing the exam id with `exam_scores.id`.
- No SQL migration and no SQLite schema version change.

## Environment limitation

Flutter/Dart SDK is not installed in this review environment, so `flutter analyze` and `flutter test` must be run on the owner's Flutter workstation before `flutter run`.
