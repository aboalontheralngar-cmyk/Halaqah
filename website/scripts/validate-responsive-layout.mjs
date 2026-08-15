import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const widgets = read("lib/widgets/app_design_widgets.dart");
const recitation = read("lib/screens/memorization/recitation_screen.dart");
const revision = read("lib/screens/memorization/revision_screen.dart");
const notifications = read("lib/screens/notifications/notifications_screen.dart");
const points = read("lib/screens/behavior/points_history_screen.dart");
const reports = read("lib/screens/reports/reports_screen.dart");
const test = read("test/responsive_layout_test.dart");

for (const contract of [
  "class AppDialogTitle",
  "class AppResponsiveInfoRow",
  "class AppResponsiveButtonRow",
  "MediaQuery.textScalerOf(context)",
  "constraints.maxWidth < 360",
]) {
  requireText(widgets, contract, `responsive design component ${contract}`);
}

requireText(recitation, "AppResponsiveButtonRow", "recitation action wrapping");
requireText(recitation, "textScale > 1.2", "recitation progress adaptation");
requireText(revision, "WrapAlignment.spaceBetween", "revision summary wrapping");
requireText(notifications, "WrapAlignment.spaceBetween", "notification metadata wrapping");
requireText(points, "PopupMenuButton<String>", "compact behavior actions");
if (points.includes("trailing: Row(")) {
  throw new Error("Behavior history must not keep a wide action Row in ListTile.trailing");
}
requireText(reports, "AppDialogTitle", "responsive report dialog titles");

for (const contract of [
  "TextScaler.linear(2)",
  "responsive information row stacks with large system text",
  "responsive action buttons stack instead of overflowing",
  "dialog title keeps long Arabic title inside narrow width",
  "tester.takeException()",
]) {
  requireText(test, contract, `responsive regression test ${contract}`);
}

console.log(
  "P1.9 responsive-layout contract passed: large text, compact actions, reports, revision, recitation, and notifications.",
);
