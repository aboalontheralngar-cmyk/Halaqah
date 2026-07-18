# ملفات المرحلة P7.2.1

## قاعدة البيانات والخادم

- `website/supabase/migrations/20260714000400_p7_student_portal_security.sql` (تصحيح مسار `pgcrypto` للتثبيت النظيف)
- `website/supabase/migrations/20260714000600_p7_family_portal.sql`
- `website/supabase/functions/student-portal/index.ts`

## بوابة الويب وإدارة العائلات

- `website/src/lib/studentPortal.ts`
- `website/src/app/portal/page.tsx`
- `website/src/app/parents/page.tsx`

## Android والمزامنة المحلية

- `lib/models/family.dart`
- `lib/models/student.dart` (تابع توافقي لحزمة Hotfix)
- `lib/models/fund_transaction.dart` (تابع توافقي لحزمة Hotfix)
- `lib/services/database_service.dart`
- `lib/services/recitation_points_policy.dart` (تابع توافقي لحزمة Hotfix)
- `lib/services/supabase_service.dart`
- `lib/screens/students/families_screen.dart`
- `test/family_model_test.dart`

## التحقق والتوثيق

- `website/scripts/validate-family-portal.mjs`
- `website/scripts/run-all-validations.mjs`
- `website/scripts/validate-advanced-exams.mjs`
- `website/scripts/validate-daily-excellence.mjs`
- `website/scripts/validate-data-privacy.mjs`
- `website/scripts/validate-discipline-contract.mjs`
- `website/scripts/validate-families-guardians.mjs`
- `website/scripts/validate-p7-student-platform.mjs`
- `website/scripts/validate-student-archive-behavior.mjs`
- `website/scripts/validate-web-recitation-parity.mjs`
- `website/package.json`
- `docs/phase7_2_1_handoff.md`
- `docs/phase7_2_1_hotfix_2026-07-18.md`
- `docs/phase7_2_1_files.md`
- `docs/student_portal_architecture.md`
- `docs/release_notes.md`
- `docs/remaining_phases_2026-07-12.md`
- `docs/master_backlog.md`
- `CHANGELOG.md`
- `README.md`
- `website/README.md`
- `website/supabase/README.md`
