# ملفات المرحلة P1.19

## نظام التصميم المشترك

- `lib/app/app.dart`
- `lib/app/design_tokens.dart`
- `lib/app/theme.dart`
- `lib/widgets/app_design_widgets.dart`
- `website/src/app/globals.css`
- `website/src/components/ui/AppDesign.tsx`
- `website/src/components/DashboardLayout.tsx`

## الواجهات والتجربة

- `lib/screens/home/home_screen.dart`
- `lib/screens/memorization/memorization_screen.dart`
- `lib/screens/memorization/add_memorization_screen.dart`
- `lib/screens/settings/settings_screen.dart`
- `lib/screens/settings/whats_new_screen.dart`
- شاشات Flutter تحت `lib/screens/**` وودجات `lib/widgets/**`: تحويل الرماديات
  الثابتة إلى ألوان تتبع الثيم.
- `website/src/app/page.tsx`
- `website/src/app/memorization/page.tsx`
- مسارات React تحت `website/src/**`: توحيد السطح والنص والحدود وإزالة درجات
  Tailwind غير الموجودة.

## الإصدار والجودة والتوثيق

- `lib/app/build_info.dart`
- `pubspec.yaml`
- `website/scripts/validate-p1-19-ui-refresh.mjs`
- `website/scripts/run-all-validations.mjs`
- `website/package.json`
- `CHANGELOG.md`
- `docs/release_notes.md`
- `docs/design_identity_guide.md`
- `docs/ui_ux_research_2026-07-27.md`
- `docs/phase1_19_handoff.md`

لا يوجد ملف SQL أو migration جديد في P1.19.
