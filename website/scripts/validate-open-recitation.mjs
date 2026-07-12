import fs from "node:fs";
import path from "node:path";

const root = path.resolve(process.cwd(), "..");
const read = (relative) => fs.readFileSync(path.join(root, relative), "utf8");
const requireText = (source, text, label) => {
  if (!source.includes(text)) throw new Error(`Missing ${label}: ${text}`);
};

const screen = read("lib/screens/memorization/recitation_screen.dart");
const picker = read("lib/widgets/ayah_range_picker.dart");
const boundary = read("lib/services/recitation_boundary_service.dart");
const test = read("test/recitation_boundary_service_test.dart");
const web = read("website/src/app/memorization/page.tsx");

for (const contract of [
  "bool _openEnded = true",
  "بدء التسميع المفتوح",
  "التوقف هنا",
  "void _stopHere()",
  "_ayahs.take(_currentAyahIndex + 1)",
  "_ayahRatings.removeWhere",
  "_setEndOfCurrentPage",
  "_setEndOfCurrentHizb",
]) {
  requireText(screen, contract, `open recitation contract ${contract}`);
}
requireText(picker, "final bool singleValue", "single start-ayah picker mode");
requireText(picker, "Slider(", "synchronized single ayah slider");
requireText(boundary, "endOfPage", "page boundary resolver");
requireText(boundary, "endOfHizb", "hizb boundary resolver");
requireText(test, "end of page stays", "page boundary regression test");
requireText(test, "end of hizb stays", "hizb boundary regression test");
requireText(web, 'setEndAtBoundary("page")', "web page boundary button");
requireText(web, 'setEndAtBoundary("hizb")', "web hizb boundary button");

console.log("Open recitation contract passed: start ayah, stop-here, page/hizb boundaries, and rating truncation.");
