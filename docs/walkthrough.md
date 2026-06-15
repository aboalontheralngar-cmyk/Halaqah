# Halaqah Features Implementation Walkthrough

This walkthrough details the design, technical details, and implementation of all advanced features built into the **Halaqah** Flutter application and the **Next.js** web application.

---

## 1. Configurable Center Fund Currency Symbol
*   **Web App**: Added the `currencySymbol` field to global settings in [useStore.ts](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/store/useStore.ts). A drop-down selection (e.g., ر.س, $, €, £, د.إ) has been integrated into the Settings page [settings/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/settings/page.tsx). The chosen symbol dynamically formats transaction cards and balances in the Center Fund view [fund/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/fund/page.tsx).
*   **Mobile App (Flutter)**: Added `currencySymbol` to the `Settings` model in [lib/models/settings.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/models/settings.dart), migrating database preferences. Updated the Settings screen [lib/screens/settings/settings_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/settings/settings_screen.dart) with a drop-down menu to pick the currency symbol globally. Applied this symbol dynamically across the Fund screen [lib/screens/fund/fund_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/fund/fund_screen.dart).

---

## 2. Memorization Direction
*   **Web App**: Added `memorizationDirection` (either `baqarah_to_nas` or `nas_to_baqarah`) to the `Student` interface. Implemented a drop-down selector in the Student addition/edit modal in [website/src/app/students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) to determine the memorization progress flow.
*   **Mobile App (Flutter)**: Upgraded SQLite Database to version 4 to include a `memorization_direction` column in the `students` table in [lib/services/database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart). Added the dropdown selection in [lib/screens/students/student_form_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_form_screen.dart).

---

## 3. Real-Time Memorization Statistics (Verses & Pages)
*   **Web App**: Formulated a `getStudentStats` utility in [website/src/app/students/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/students/page.tsx) that retrieves a student's grades and maps the memorized verses/surahs against `quranService`. It returns:
    1. **إجمالي الآيات المسموعة**: The number of unique verses memorized.
    2. **الصفحات الفريدة**: The number of unique pages of the Quran that have been memorized (based on standard page boundaries in `quranService`).
*   **Mobile App (Flutter)**: Created helper methods (`getAllHomeworkGrades`, `getAllMushafProgress`, `getAllDailyRecords`) in [lib/services/database_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/database_service.dart). Implemented dynamic calculations on the Student detail screen [lib/screens/students/student_detail_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/students/student_detail_screen.dart) to show the student's exact memorized verse and unique page statistics.

---

## 4. Beautiful Daily Report Image Card Generation & Sharing
*   **Web App**: Designed a premium card utilizing the HTML5 `<canvas>` API inside [website/src/app/memorization/page.tsx](file:///c:/Users/salman/Documents/flutter_App/Halaqah/website/src/app/memorization/page.tsx). It draws a beautifully styled card with a dark-teal gradient, gold calligraphy decoration, student information, recitation details, grade badge, mistakes count, and date. Teachers can share it directly or download it as a PNG image.
*   **Mobile App (Flutter)**: Implemented high-performance off-screen drawing using native Flutter `PictureRecorder` and `Canvas` APIs in [lib/screens/memorization/recitation_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/memorization/recitation_screen.dart). It compiles student data, draws custom text and gradients, saves the card to a temporary file, and triggers a system share panel to send the image directly to WhatsApp.

---

## 5. Supabase Cloud Sync & Authentication
*   **Supabase Client**: Configured and initialized the Supabase SDK in [lib/main.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/main.dart).
*   **Supabase Service**: Developed `SupabaseService` in [lib/services/supabase_service.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/services/supabase_service.dart) to perform two-way synchronization:
    *   Creates deterministic UUIDs for tables using MD5 hashes to prevent duplicate database rows.
    *   Synchronizes `students`, `daily_records`, and `homework_grades` bidirectionally.
    *   Tracks offline states and pushes pending updates to the cloud once connected.
*   **Login Flow**: Built a premium login screen [lib/screens/auth/login_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/auth/login_screen.dart) for teachers.
*   **AppBar Status & Sync Dialog**: Modified [lib/screens/home/home_screen.dart](file:///c:/Users/salman/Documents/flutter_App/Halaqah/lib/screens/home/home_screen.dart) to display dynamic indicators of cloud sync status in the header, letting teachers view authentication states and start manual synchronization sweeps.

---

## 6. Teacher Absence & Substitution Architecture Design
*   Documented a full system architecture proposal in [docs/teacher_absence_handling.md](file:///c:/Users/salman/Documents/flutter_App/Halaqah/docs/teacher_absence_handling.md).
*   It covers:
    1. **Absence Logging**: Teachers log a planned absence.
    2. **Substitution Requests**: The system prompts available substitutes or auto-assigns matching substitute teachers.
    3. **Substitute Temporary Access**: Configures a secure, read/write delegation session in Supabase, keeping student data isolated and audit-logged.
    4. **Smart Classroom Mode**: Fallback automated tasks and tests when no substitute is present.

---

## 7. Verification Results
*   **Web App**: Compiled successfully via `npm run build` with zero errors. All routes pre-rendered smoothly.
*   **Mobile App**: `flutter analyze` completed successfully with **zero errors**.
