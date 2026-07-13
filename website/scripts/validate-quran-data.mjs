import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { resolve } from "node:path";
import { fileURLToPath } from "node:url";

const scriptDirectory = fileURLToPath(new URL(".", import.meta.url));
const projectRoot = resolve(scriptDirectory, "../..");
const mobilePath = resolve(projectRoot, "assets/quran_data.json");
const webPath = resolve(projectRoot, "website/public/quran_data.json");

const [mobileBuffer, webBuffer] = await Promise.all([
  readFile(mobilePath),
  readFile(webPath),
]);

const sha256 = value => createHash("sha256").update(value).digest("hex");
const failures = [];

if (sha256(mobileBuffer) !== sha256(webBuffer)) {
  failures.push("Mobile and web Quran data files are not identical.");
}

const data = JSON.parse(mobileBuffer.toString("utf8"));
if (data.total_surahs !== 114 || data.surahs?.length !== 114) {
  failures.push("Expected exactly 114 surahs.");
}

const numberedAyahs = [];
const basmalaRows = [];
const pages = [];

for (const surah of data.surahs || []) {
  const numbered = (surah.ayahs || []).filter(ayah => ayah.number > 0);
  const basmalas = (surah.ayahs || []).filter(ayah => ayah.number === 0);
  const expectedNumbers = Array.from({ length: numbered.length }, (_, index) => index + 1);
  const actualNumbers = numbered.map(ayah => ayah.number);

  if (JSON.stringify(actualNumbers) !== JSON.stringify(expectedNumbers)) {
    failures.push(`Surah ${surah.number} has a missing, duplicate, or unordered ayah number.`);
  }
  if (surah.total_ayahs !== numbered.length) {
    failures.push(
      `Surah ${surah.number} declares ${surah.total_ayahs} ayahs but contains ${numbered.length} numbered ayahs.`,
    );
  }

  numberedAyahs.push(...numbered);
  basmalaRows.push(...basmalas);
  pages.push(...(surah.ayahs || []).map(ayah => ayah.page));
}

if (data.total_ayahs !== 6236 || numberedAyahs.length !== 6236) {
  failures.push(`Expected 6236 numbered ayahs, found ${numberedAyahs.length}.`);
}
if (basmalaRows.length !== 112) {
  failures.push(`Expected 112 separate basmala rows, found ${basmalaRows.length}.`);
}
if (Math.min(...pages) !== 1 || Math.max(...pages) !== 604) {
  failures.push("Expected page numbers to cover pages 1 through 604.");
}
if (numberedAyahs.some(ayah => typeof ayah.text !== "string" || ayah.text.trim() === "")) {
  failures.push("One or more numbered ayahs have empty text.");
}
const invalidQuarterRows = numberedAyahs.filter(ayah => {
  const firstQuarterInHizb = (ayah.hizb - 1) * 4 + 1;
  return ayah.quarter < firstQuarterInHizb ||
    ayah.quarter > firstQuarterInHizb + 3;
});
if (invalidQuarterRows.length > 0) {
  failures.push(
    `${invalidQuarterRows.length} ayahs have a quarter outside their hizb.`,
  );
}
const availableQuarters = new Set(numberedAyahs.map(ayah => ayah.quarter));
const missingQuarters = Array.from(
  { length: 240 },
  (_, index) => index + 1,
).filter(quarter => !availableQuarters.has(quarter));
if (missingQuarters.length > 0) {
  failures.push(`Missing Quran quarters: ${missingQuarters.join(", ")}.`);
}

if (failures.length > 0) {
  console.error(failures.map(message => `- ${message}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log(
    "Quran data integrity check passed: 114 surahs, 6236 numbered ayahs, 604 pages, and 240 consistent quarters.",
  );
}
