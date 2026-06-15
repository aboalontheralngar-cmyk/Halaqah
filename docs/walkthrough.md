# Halaqat Features Implementation in Halaqah - Walkthrough

This walkthrough details the design, technical details, and implementation of 5 advanced features inspired by the Angular/Ionic **Halaqat** system into our Flutter **Halaqah** application.

---

## 1. Advanced Recitation Grading & Homework Model
- **Database Upgrade (v2 → v3)**: Added the `homework_grades` table storing student grades (`grade_mark`), `mistakes_count`, `is_revision` status, and teacher `remark`.
- **Intelligent Recitation Setup**: Teachers select the surah and ayah range. The app dynamically calculates the number of verses, lines, and pages.
- **5-Level Colored Grading**:
  - **ممتاز** (excellent) - Green
  - **جيد جداً** (very_good) - Light Green
  - **جيد** (good) - Orange
  - **يحتاج تركيز** (needs_work) - Deep Orange
  - **غائب** (absent) - Red
- **Interactive Mistakes Counter**: Increment/decrement counter with +/- buttons.
- **Remarks Field**: Text field for recording student behavior, effort, or notes.
- **Recitation Toggle**: Supports selecting whether the homework is **حفظ جديد** (New memorization) or **مراجعة** (Revision).

---

## 2. Interactive Mushaf Visualizer (60 Hizb × 8 Thumun)
- **Cell Map**: Renders an interactive scrollable list of 60 rows (each representing one Hizb) containing 8 color-coded cells (representing 8 thumuns) for each student.
- **Dynamic Quran Mapping**: Matches graded surah/ayah ranges dynamically to the Quran's 240 global quarters, mapping each rub' to two corresponding thumun cells (480 total thumun resolution).
- **Decay Tracking (Active Review)**:
  - Cells are colored based on the age of their latest grading date:
    - **Fresh (Green)**: Graded < 14 days ago.
    - **Aging (Yellow)**: Graded 14-30 days ago (revision recommended).
    - **Stale (Red)**: Graded > 30 days ago (needs urgent revision).
    - **Grey**: Not started yet.
- **Manual Pre-memorization Toggle**: Allows teachers to mark a specific thumun as "محفوظ مسبقاً" (Pre-memorized) in the detail sheet so they can manually populate a student's map without creating grades (perfect for new students).

---

## 3. RTL Arabic CSV Reports Exporting & Sharing
- **UTF-8 BOM Support**: Encodes CSV reports with a standard UTF-8 Byte Order Mark (`0xEF, 0xBB, 0xBF`), enabling Microsoft Excel to open and read Arabic characters properly without garbling text.
- **Single Student Report**: Exports a student's complete daily record, detailed homework grades, behavior points log, and exam scores into a single shared file.
- **Circle-wide Report**: Exports a summary of all students' phone numbers, current plans, total memorized verses, status, and join dates.
- **General Sharing**: Integrates `share_plus` to allow direct sharing of reports to WhatsApp, email, or other storage services.

---

## 4. Customizable Parent Message Templates
- **Interactive Customizer Screen**: Added a screen in settings allowing teachers to write custom templates for **تكليف الواجب** (homework assignment notifications) and **تقييم التسميع** (recitation grade report notifications).
- **Dynamic Placeholders**: Offers variables like `{اسم_الطالب}`, `{السورة}`, `{من}`, `{إلى}`, `{التقييم}`, `{الأخطاء}`, and `{الملاحظة}` with interactive ActionChips that append them directly at the text cursor.
- **"Save & Send" Action**: After finishing recitation grading, teachers can choose "حفظ وإرسال لولي الأمر" which saves the grade and opens the system share panel pre-filled with the rendered template.

---

## 5. Optimized Bulk JSON Backup & Restore
- **Bulk Table Queries**: Redesigned the backup export from slow per-student loops to fast O(1) table-level bulk queries. Reduces DB operations from `5 * N` to a flat `11` queries total.
- **Full Database Sync**: Backs up all 12 database tables, including `fund_transactions`, `plans`, `notifications`, `homework_grades`, `mushaf_progress`, and `message_templates`.
- **System Share Export**: Automatically triggers sharing of the generated backup JSON file on creation.

---

## 6. Verification Results
- All files created, modified, and integrated successfully.
- Code compiles clean with no syntax errors.
- Verified database migration triggers properly.
