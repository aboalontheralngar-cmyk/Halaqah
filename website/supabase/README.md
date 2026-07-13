# Supabase database changes

Use the files in `migrations/` for an existing Halaqah database. Apply them in filename order and take a database backup first.

`website/database_schema.sql` is a fresh-install baseline. It starts by removing existing tables and must never be executed on a database that contains real data.

## P0 migration order

1. Back up the Supabase database.
2. Apply `migrations/20260711000100_p0_student_progress_integrity.sql`.
3. Apply `migrations/20260711000200_p0_security_qr_attendance.sql`.
4. Apply `migrations/20260711000300_p2_exam_templates.sql` when deploying persistent generated exams.
5. Apply `migrations/20260711000400_p3_student_holds.sql` for temporary recitation holds.
6. Apply `migrations/20260712000100_p5_smart_plans.sql`.
7. Apply `migrations/20260712000200_p5_student_archive_behavior_audit.sql`.
8. Apply `migrations/20260712000300_p5_daily_excellence.sql`.
9. Apply `migrations/20260712000400_p5_families_guardians.sql`.
10. Apply `migrations/20260713000090_p5_memorization_halaqa_compat.sql` to add and backfill the missing recitation scope on older cloud schemas.
11. Apply `migrations/20260713000100_p5_web_recitation_parity.sql` before deploying the P5.6 web recitation screen.
12. Apply `migrations/20260713000200_p5_advanced_mushaf_exams.sql` before syncing P5.7 exam templates and digital assessment.
13. Apply `migrations/20260713000300_p6_data_privacy_cloud_backup.sql` before enabling encrypted cloud backups. It is self-contained and creates its required scope helpers.
14. Deploy the matching Android/Web code in the same release as the migrations.
15. Test an owner and two teachers assigned to different halaqahs. Each teacher must only see their assigned students, families, records, and audit events.
16. Run one synchronization and verify a known student's memorized range, Mushaf map, QR attendance, family, exam template, and one-row-per-day attendance rule.
17. Create one encrypted cloud backup, download it on a second test device, and restore it with the same passphrase before enabling the feature in production.

The Android client contains a temporary compatibility fallback for databases that have not received the P0 migration. The fallback prevents local progress from being overwritten, but cloud preservation is only complete after the migration is applied.

The security migration removes the legacy invitation RPCs, makes invitations single-use and expiring, and scopes teachers to their assigned halaqah. Always test it on a staging copy before production.
