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
14. Apply the three P7.1 migrations for student identity, fund links, and revision amounts.
15. Apply `migrations/20260714000400_p7_student_portal_security.sql` before enabling the student portal.
16. Apply `migrations/20260714000500_p7_supervisory_hierarchy.sql` before enabling the multi-center supervisory dashboard.
17. Apply `migrations/20260714000600_p7_family_portal.sql` before enabling one guardian login for multiple children.
18. Apply `migrations/20260718000200_p1_connected_hizb_plans.sql` and `migrations/20260719000100_p1_web_connected_recitation.sql` for connected plans and atomic multi-surah Web recitation.
19. Apply **the contents** of `migrations/20260722000200_p1_14_atomic_web_daily_closing.sql` for cloud suspensions and atomic Web daily closing.
20. Run **the contents** of `verification/20260722000200_p1_14_atomic_daily_closing_readiness.sql`; every `passed` value must be `true`.
21. Deploy the `student-portal` Edge Function with JWT verification disabled as configured in `config.toml`.
22. Set a long random `PORTAL_RATE_LIMIT_PEPPER` secret and restrict `PORTAL_ALLOWED_ORIGINS` to the deployed web origin.
23. Deploy the matching Android/Web code in the same release as the migrations.
24. Test an owner and two teachers assigned to different halaqahs. Each teacher must only see their assigned students, families, records, and audit events.
25. Test two separate families and confirm a family session cannot select a child from the other family.
26. Test a supervisory owner, administrator, and analyst. The analyst must see aggregate reports but must not mutate center records.
27. Run one synchronization and verify a known student's memorized range, Mushaf map, QR attendance, family, exam template, and one-row-per-day attendance rule.
28. Create one encrypted cloud backup, download it on a second test device, and restore it with the same passphrase before enabling the feature in production.
29. Apply `migrations/20260727000100_p1_20_portal_supervision.sql` before enabling P1.20 review systems, family behavior history, and supervisory visits.
30. Apply `migrations/20260728000100_p1_21_guardian_automatic_reports.sql` before enabling scheduled guardian reports.
31. Run `verification/20260728000100_p1_21_guardian_reports_readiness.sql` and require every `passed` value to be `true`.
32. Redeploy the `student-portal` Edge Function so family sessions can read their published reports.
33. Deploy `guardian-report-worker`, set `GUARDIAN_REPORT_WORKER_SECRET`, and invoke it from a protected scheduler every 15 minutes.
34. For external delivery, also set an HTTPS `GUARDIAN_REPORT_WEBHOOK_URL` and `GUARDIAN_REPORT_WEBHOOK_SECRET`; leave them unset to publish inside the portal only.

The Android client contains a temporary compatibility fallback for databases that have not received the P0 migration. The fallback prevents local progress from being overwritten, but cloud preservation is only complete after the migration is applied.

The security migration removes the legacy invitation RPCs, makes invitations single-use and expiring, and scopes teachers to their assigned halaqah. Always test it on a staging copy before production.


### P1.22 build 66 compatibility
The P1.22 migration can bootstrap `public.student_holds` when the older P3 migration is missing. Run the P1.22 migration as one transaction, then run `verify_p1_22.sql`.

## P1.26 owner deployment — post-bootstrap path

The owner-provided Supabase schema is not a pristine Halaqah-only project: the same `public` schema contains unrelated operational tables. The guarded P1.26 base bootstrap has already been executed successfully and the supplied schema now contains the Halaqah base scope.

For this deployment, do **not** replay the historical migration chain above and do not rerun the base bootstrap. Use the state-aware path instead:

1. back up Supabase;
2. run `P1.26_POST_BOOTSTRAP_CORE.sql`;
3. after success, run `P1.26_POST_BOOTSTRAP_VERIFY.sql`;
4. require the final recommendation `READY_FOR_APP_SYNC_TEST`.

The post-bootstrap core script is additive and does not target the unrelated workload tables.

## P1.27 Build 75 — owner deployment path

For the current owner database, use the consolidated state-aware files instead of replaying historical P7.3 migrations:

1. back up Supabase;
2. run the **contents** of `P1.27_BUILD75_APPLY.sql`;
3. run the **contents** of `P1.27_BUILD75_VERIFY.sql`;
4. require every returned `passed` value to be `true`;
5. test supervisory owner/admin/analyst accounts and two-device deletion sync.

The APPLY file includes the Build 74 supervisory/family reconciliation first, then Build 75 direct center creation, safe backdated study-suspension rollback, monthly-plan exam type, and durable sync tombstones. Do not run `website/database_schema.sql` on the existing owner database and do not replay P7.3 manually.
