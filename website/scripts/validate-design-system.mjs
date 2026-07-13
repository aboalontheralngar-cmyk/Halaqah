import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = resolve(import.meta.dirname, "../..");
const read = (path) => readFileSync(resolve(root, path), "utf8");
const assertIncludes = (source, values, label) => {
  for (const value of values) {
    if (!source.includes(value)) {
      throw new Error(`${label}: missing ${value}`);
    }
  }
};

const flutterTheme = read("lib/app/theme.dart");
assertIncludes(
  flutterTheme,
  ["_buildTheme(Brightness.light)", "_buildTheme(Brightness.dark)", "inputDecorationTheme", "dialogTheme"],
  "Flutter theme",
);

const flutterWidgets = read("lib/widgets/app_design_widgets.dart");
assertIncludes(
  flutterWidgets,
  ["class AppPageIntro", "class AppSectionHeader", "class AppEmptyState", "class AppSearchField", "class AppMetricTile"],
  "Flutter shared widgets",
);

assertIncludes(read("lib/screens/students/students_screen.dart"), ["AppSearchField", "AppEmptyState", "StudentCard"], "Flutter students");
assertIncludes(read("lib/screens/reports/reports_screen.dart"), ["AppPageIntro", "AppSectionHeader", "StudentCard"], "Flutter reports");

const webDesign = read("website/src/components/ui/AppDesign.tsx");
assertIncludes(
  webDesign,
  ["function PageHeader", "function Surface", "function MetricCard", "function EmptyState", "function SearchField"],
  "Web shared components",
);

const dashboard = read("website/src/components/DashboardLayout.tsx");
assertIncludes(
  dashboard,
  ["mobileNavItems", '"memorization"', '"reports"', "aria-current", "فتح القائمة الرئيسية"],
  "Web navigation",
);

const globals = read("website/src/app/globals.css");
assertIncludes(globals, [".dark", ":focus-visible", "prefers-reduced-motion", ".page-enter"], "Web global styles");

for (const page of ["students", "attendance", "memorization"]) {
  const source = read(`website/src/app/${page}/page.tsx`);
  assertIncludes(source, ["PageHeader", "page-enter"], `Web ${page} page`);
}

console.log("Unified design-system validation passed.");
