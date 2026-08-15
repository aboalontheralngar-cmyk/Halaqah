# ملفات المرحلة P7.1

## الهوية والبيانات

- `lib/models/student.dart`
- `lib/models/settings.dart`
- `lib/models/behavior_point.dart`
- `lib/models/fund_transaction.dart`
- `lib/services/database_service.dart`
- `lib/services/supabase_service.dart`
- `lib/services/recitation_points_policy.dart`

## التقارير والخطط والواجهات

- `lib/services/pdf_service.dart`
- `lib/services/student_period_report_service.dart`
- `lib/screens/reports/reports_screen.dart`
- `lib/screens/reports/student_period_report_screen.dart`
- `lib/screens/reports/halaqah_period_report_screen.dart`
- `lib/screens/plans/plans_screen.dart`
- `lib/screens/students/student_form_screen.dart`
- `lib/screens/students/student_raffle_screen.dart`
- `lib/screens/fund/fund_screen.dart`
- `lib/screens/home/home_screen.dart`
- `lib/screens/settings/usage_guide_screen.dart`
- `lib/utils/helpers.dart`

## SQL

- `website/database_schema.sql`
- `website/database_schema_extensions.sql`
- `website/supabase/migrations/20260714000100_p7_student_identity_foundation.sql`
- `website/supabase/migrations/20260714000200_p7_fund_penalty_link.sql`
- `website/supabase/migrations/20260714000300_p7_student_review_plan.sql`

## الاختبارات والتوثيق

- `website/src/store/useStore.ts`
- `test/student_display_code_test.dart`
- `test/student_period_report_service_test.dart`
- `test/recitation_points_policy_test.dart`
- `test/settings_points_balance_test.dart`
- `docs/phase7_1_handoff.md`
- `docs/student_portal_architecture.md`
- `docs/release_notes.md`
- `CHANGELOG.md`
- `README.md`
