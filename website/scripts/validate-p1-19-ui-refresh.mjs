import { readdirSync, readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const requireText = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
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

const tokens = read("lib/app/design_tokens.dart");
requireText(
  tokens,
  [
    "static EdgeInsets pageFor",
    "static const double md = 14",
    "static const Duration normal = Duration(milliseconds: 170)",
    "static const double maxContentWidth = 1120",
  ],
  "Flutter design tokens",
);

const theme = read("lib/app/theme.dart");
requireText(
  theme,
  [
    "Color(0xFF176B57)",
    "Color(0xFFF5F3ED)",
    "class AppSemanticColors",
    "expansionTileTheme",
    "segmentedButtonTheme",
    "dataTableTheme",
    "textSelectionTheme",
  ],
  "Flutter unified theme",
);

const widgets = read("lib/widgets/app_design_widgets.dart");
requireText(
  widgets,
  [
    "class AppScreenBody",
    "class AppFocusPanel",
    "class AppStatusPill",
    "class AppActionTile",
    "class AppAdaptiveGrid",
  ],
  "Flutter shared workflow components",
);

requireText(
  read("lib/screens/home/home_screen.dart"),
  [
    "Future.wait<dynamic>",
    "AppFocusPanel(",
    "AppAdaptiveGrid(",
    "مساحة العمل اليومية جاهزة",
  ],
  "Flutter task-first home",
);
requireText(
  read("lib/screens/memorization/add_memorization_screen.dart"),
  [
    "AppScreenBody(",
    "اعتماد الحفظ المنفّذ",
    "AppFocusPanel(",
    "اعتماد وحفظ التسجيل",
  ],
  "Flutter direct memorization flow",
);

for (const path of [
  ...filesBelow("lib/screens", ".dart"),
  ...filesBelow("lib/widgets", ".dart"),
]) {
  const source = readFileSync(path, "utf8");
  if (/Colors\.grey\[(?:100|200|300|400|500|600|700)\]/.test(source)) {
    throw new Error(`Non-adaptive indexed grey remains in ${path}`);
  }
}

const globals = read("website/src/app/globals.css");
requireText(
  globals,
  [
    "--background: #f5f3ed",
    "--foreground: #17241f",
    "--muted: #596861",
    "--primary: #176b57",
    "--radius-md: 14px",
    ".app-main",
    ".rounded-\\[3rem\\]",
    ".dark :where(.text-gray-400, .text-gray-500)",
  ],
  "Web global design system",
);

const dashboardLayout = read("website/src/components/DashboardLayout.tsx");
requireText(
  dashboardLayout,
  [
    'section: "daily" | "people" | "learning" | "management"',
    "const navGroups = useMemo",
    'className="app-main safe-main-bottom flex-1"',
    "useShallow",
  ],
  "Web grouped navigation and render isolation",
);

const webHome = read("website/src/app/page.tsx");
requireText(
  webHome,
  [
    "<PageStack>",
    "<ProgressPanel",
    "<ActionLinkCard",
    "useShallow",
    "مساحة عمل الحلقة",
  ],
  "Web task-first home",
);

requireText(
  read("website/src/app/memorization/page.tsx"),
  ["<PageStack", "<MetricCard", "useShallow", "الحفظ والمراجعة"],
  "Web memorization workspace",
);

for (const path of filesBelow("website/src", ".tsx")) {
  const source = readFileSync(path, "utf8");
  if (/(?:gray-(?:150|250|750|850)|rose-405|emerald-450)/.test(source)) {
    throw new Error(`Invalid Tailwind shade remains in ${path}`);
  }
}

requireText(
  read("docs/ui_ux_research_2026-07-27.md"),
  ["Tarteel", "Quranly", "آية", "Quran.com", "السرعة المحسوسة"],
  "UI/UX research record",
);

requireText(
  read("pubspec.yaml"),
  ["version: 4.3.0-alpha.26+83"],
  "P1.19 package version",
);
requireText(
  read("lib/app/build_info.dart"),
  [
    "versionName = '4.3.0-alpha.26'",
    "buildNumber = 83",
    "releaseLabel = 'P1.27'",
  ],
  "P1.19 build identity",
);

console.log(
  "P1.19 passed: researched identity, task-first layouts, dark contrast, responsive spacing, and render isolation are protected.",
);
