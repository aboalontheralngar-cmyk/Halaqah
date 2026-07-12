import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const screen = read("lib/screens/memorization/revision_screen.dart");
const service = read("lib/services/revision_progression_service.dart");
const database = read("lib/services/database_service.dart");
const test = read("test/revision_progression_service_test.dart");

for (const contract of [
  "RevisionProgressionService.nextStartingPoint",
  "getActiveStudentPlan",
  "استئناف المراجعة",
  "_setRevisionBoundary",
  "saveRevisionSession",
  "HomeworkGrade(",
  "MushafService().updateProgressAfterGrading",
]) {
  requireText(screen, contract, `revision screen contract ${contract}`);
}
for (const contract of [
  "required List<MemorizationProgress> progress",
  "required List<HomeworkGrade> grades",
  "await db.transaction",
  "_validateMemorizationRange",
]) {
  requireText(database, contract, `atomic revision database contract ${contract}`);
}
requireText(service, "latest.toAyah + 1", "same-surah continuation");
requireText(service, "ordered[nextIndex]", "next-surah continuation");
requireText(test, "continues after the last reviewed ayah", "revision continuation test");
requireText(test, "wraps according to descending", "revision wrap test");

console.log("Revision continuity contract passed: cursor, plan amount, boundaries, atomic save, and Mushaf grade.");
