import { readFileSync } from "node:fs";
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

const screenBody = read("lib/widgets/app_design_widgets.dart");
requireText(
  screenBody,
  ["final content = Align(", "alignment: Alignment.topCenter"],
  "Flutter shared screen alignment",
);
if (screenBody.includes("final content = Center(\n      alignment:")) {
  throw new Error("Center does not accept the alignment named parameter");
}

const examResult = read("lib/screens/exam/exam_result_screen.dart");
requireText(
  examResult,
  [
    "Widget _buildDetailRow(\n    BuildContext context,",
    "Theme.of(context).colorScheme.onSurfaceVariant",
  ],
  "Exam result themed detail rows",
);
const contextCalls = examResult.match(
  /_buildDetailRow\(\s*context,\s*/g,
);
if (contextCalls?.length !== 3) {
  throw new Error(
    `Exam result must pass BuildContext to all 3 detail rows; found ${contextCalls?.length ?? 0}`,
  );
}

requireText(
  read("pubspec.yaml"),
  ["version: 4.3.0-alpha.25+82"],
  "P1.19.1 package version",
);
requireText(
  read("lib/app/build_info.dart"),
  [
    "versionName = '4.3.0-alpha.25'",
    "buildNumber = 82",
    "releaseLabel = 'P1.27'",
  ],
  "P1.19.1 build identity",
);

console.log(
  "P1.19.1 passed: Flutter screen alignment and exam detail context build regressions are fixed.",
);
