import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireAll = (path, fragments) => {
  const source = read(path);
  for (const fragment of fragments) {
    if (!source.includes(fragment)) {
      throw new Error(`P1.23 missing ${fragment} in ${path}`);
    }
  }
  return source;
};
const requireFile = (path) => {
  if (!existsSync(resolve(root, path))) {
    throw new Error(`P1.23 missing required file: ${path}`);
  }
};
const filesBelow = (relative, extension) => {
  const result = [];
  const visit = (absolute) => {
    for (const name of readdirSync(absolute)) {
      const path = resolve(absolute, name);
      if (statSync(path).isDirectory()) visit(path);
      else if (path.endsWith(extension)) result.push(path);
    }
  };
  visit(resolve(root, relative));
  return result;
};

requireAll("pubspec.yaml", [
  "version: 4.3.0-alpha.22+76",
  "assets/fonts/Tajawal-400.ttf",
  "assets/fonts/Tajawal-700.ttf",
  "family: Tajawal",
]);
requireAll("lib/app/build_info.dart", [
  "versionName = '4.3.0-alpha.22'",
  "buildNumber = 76",
  "releaseLabel = 'P1.27'",
]);
requireAll("lib/utils/constants.dart", ["appVersion = '4.3.0-alpha.22'"]);

const pdf = requireAll("lib/services/pdf_service.dart", [
  "rootBundle.load('assets/fonts/Tajawal-400.ttf')",
  "rootBundle.load('assets/fonts/Tajawal-700.ttf')",
  "pw.ThemeData.withFont",
  "base: _pdfRegularFont",
  "bold: _pdfBoldFont",
  "pw.Document(theme: _pdfTheme)",
]);
if (/Font\.helvetica\s*\(/.test(pdf)) {
  throw new Error("P1.23 PDF generation must never fall back to Helvetica for Arabic");
}
if ((pdf.match(/pw\.Document\(theme: _pdfTheme\)/g) ?? []).length < 10) {
  throw new Error("P1.23 PDF theme must cover every exported document family");
}

requireAll("lib/app/design_tokens.dart", [
  "static const double md = 14",
  "static const double lg = 18",
  "static const Duration normal = Duration(milliseconds: 170)",
]);
const theme = requireAll("lib/app/theme.dart", [
  "Color(0xFF176B57)",
  "Color(0xFF9B6C2F)",
  "Color(0xFFF5F3ED)",
  "fontFamily: 'Tajawal'",
  "WidgetStateProperty.resolveWith",
  "toolbarHeight: 52",
  "height: 62",
]);
const chipThemeBlock = theme.match(/chipTheme:\s*base\.chipTheme\.copyWith\(([\s\S]*?)\n\s*\),\n\s*badgeTheme:/)?.[1] ?? "";
if (/\bvisualDensity\s*:/.test(chipThemeBlock)) {
  throw new Error("P1.23 ChipThemeData must not use unsupported visualDensity; rely on ThemeData.visualDensity instead");
}
requireAll("lib/widgets/app_design_widgets.dart", [
  "class AppFocusPanel",
  "class AppCompactActionTile",
  "class AppCompactActionGrid",
  "width: 36",
  "height: 36",
]);
requireAll("lib/screens/home/home_screen.dart", [
  "WidgetsBinding.instance.addPostFrameCallback",
  "Icon(Icons.dashboard_outlined)",
  "Icon(Icons.assessment_outlined)",
  "Icons.notifications_none_rounded",
]);
requireAll("website/src/app/globals.css", [
  "--background: #f5f3ed",
  "--foreground: #17241f",
  "--primary: #176b57",
  "--focus: #176b57",
  "--shadow-soft: 0 1px 2px",
]);

const dartFiles = [
  ...filesBelow("lib/screens", ".dart"),
  ...filesBelow("lib/widgets", ".dart"),
  ...filesBelow("lib/services", ".dart"),
  resolve(root, "lib/app/theme.dart"),
];
for (const path of dartFiles) {
  const source = readFileSync(path, "utf8");
  if (source.includes("LinearGradient(") || source.includes("BoxShadow(")) {
    throw new Error(`P1.23 flat Flutter UI must not reintroduce heavy gradients/shadows in ${path}`);
  }
  if (source.includes(".withOpacity(")) {
    throw new Error(`Deprecated withOpacity remains in ${path}`);
  }
  if (/\bMaterialState(Property)?\b/.test(source)) {
    throw new Error(`Deprecated MaterialState API remains in ${path}`);
  }
  if (/\banonKey\s*:/.test(source)) {
    throw new Error(`Deprecated Supabase anonKey remains in ${path}`);
  }
}

const radioListTilePattern = /RadioListTile(?:<[^>]+>)?\s*\(([\s\S]*?)\n\s*\)/g;
for (const path of filesBelow("lib", ".dart")) {
  const source = readFileSync(path, "utf8");
  let match;
  while ((match = radioListTilePattern.exec(source)) !== null) {
    if (/\b(groupValue|onChanged)\s*:/.test(match[1])) {
      throw new Error(`Deprecated RadioListTile group state remains in ${path}`);
    }
  }
}

for (const path of [
  "docs/P1.23_IMPLEMENTATION_LOG.md",
  "docs/ui_ux_reference_gordah_2026-08-08.md",
]) {
  requireFile(path);
}

console.log(
  "P1.23 UI contracts remain protected; P1.26 unifies the compact flat UI and PDF on the static Tajawal Arabic font while keeping the current release identity.",
);
