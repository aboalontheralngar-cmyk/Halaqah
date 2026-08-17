import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const assertIncludes = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) throw new Error(`${label}: missing ${value}`);
  }
};

const pubspec = read("pubspec.yaml");
assertIncludes(
  pubspec,
  [
    "version: 4.3.0-alpha.25+82",
    "family: Tajawal",
    "assets/fonts/Tajawal-400.ttf",
    "assets/fonts/Tajawal-700.ttf",
  ],
  "Bundled Flutter typography",
);
if (pubspec.includes("google_fonts:")) {
  throw new Error("Flutter UI must not depend on runtime Google Fonts downloads");
}


const theme = read("lib/app/theme.dart");
assertIncludes(
  theme,
  [
    "Color(0xFF176B57)",
    "Color(0xFFF5F3ED)",
    "fontFamily: 'Tajawal'",
    "drawerTheme",
    "navigationBarTheme",
    "bottomSheetTheme",
  ],
  "Flutter unified theme",
);

const app = read("lib/app/app.dart");
assertIncludes(
  app,
  ["AnnotatedRegion<SystemUiOverlayStyle>", "systemNavigationBarIconBrightness", "child: SafeArea(", "top: false"],
  "Flutter system safe area",
);
assertIncludes(
  read("lib/main.dart"),
  ["SystemUiMode.edgeToEdge", "await SystemChrome.setPreferredOrientations"],
  "Flutter system chrome",
);
assertIncludes(
  read("lib/services/pdf_service.dart"),
  ["rootBundle.load('assets/fonts/Tajawal-400.ttf')", "rootBundle.load('assets/fonts/Tajawal-700.ttf')", "pw.ThemeData.withFont", "pw.Document(theme: _pdfTheme)"],
  "Offline static Arabic PDF font",
);

const dartSources = [
  read("lib/screens/home/home_screen.dart"),
  read("lib/screens/fund/fund_screen.dart"),
  read("lib/screens/honor_board/honor_board_screen.dart"),
  read("lib/screens/notifications/notifications_screen.dart"),
  read("lib/screens/settings/whats_new_screen.dart"),
].join("\n");
if (/GoogleFonts\./.test(dartSources)) {
  throw new Error("Flutter interface must inherit the bundled Tajawal font from the theme");
}

const layout = read("website/src/app/layout.tsx");
assertIncludes(
  layout,
  ["@fontsource/readex-pro/400.css", "@fontsource/readex-pro/700.css", "viewportFit: \"cover\""],
  "Web typography and viewport",
);

const globals = read("website/src/app/globals.css");
assertIncludes(
  globals,
  [
    'font-family: "Readex Pro"',
    "env(safe-area-inset-top)",
    "env(safe-area-inset-bottom)",
    ".safe-main-bottom",
    "--background: #f5f3ed",
  ],
  "Web identity and safe area",
);

const dashboard = read("website/src/components/DashboardLayout.tsx");
assertIncludes(dashboard, ["safe-top", "safe-bottom", "safe-main-bottom"], "Responsive shell safe area");

const packageJson = JSON.parse(read("website/package.json"));
if (packageJson.dependencies["@fontsource/readex-pro"] !== "5.3.0") {
  throw new Error("Web Readex Pro package must remain pinned to the reviewed version");
}

console.log("P6.2.1 unified identity, typography, and safe-area contract passed.");
