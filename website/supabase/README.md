# Supabase database changes

Use the files in `migrations/` for an existing Halaqah database. Apply them in filename order and take a database backup first.

`website/database_schema.sql` is a fresh-install baseline. It starts by removing existing tables and must never be executed on a database that contains real data.

## P0 migration order

1. Back up the Supabase database.
2. Apply `migrations/20260711000100_p0_student_progress_integrity.sql`.
3. Apply `migrations/20260711000200_p0_security_qr_attendance.sql`.
4. Apply `migrations/20260711000300_p2_exam_templates.sql` when deploying persistent generated exams.
5. Apply `migrations/20260711000400_p3_student_holds.sql` for temporary recitation holds.
5. Deploy the matching Android/Web code in the same release as migrations 2 and 3.
6. Test an owner and two teachers assigned to different halaqahs. Each teacher must only see their assigned students and exam templates.
7. Run one synchronization and verify a known student's memorized range, Mushaf map, QR attendance, and one-row-per-day attendance rule.

The Android client contains a temporary compatibility fallback for databases that have not received the P0 migration. The fallback prevents local progress from being overwritten, but cloud preservation is only complete after the migration is applied.

The security migration removes the legacy invitation RPCs, makes invitations single-use and expiring, and scopes teachers to their assigned halaqah. Always test it on a staging copy before production.
