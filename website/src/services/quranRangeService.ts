import type { Ayah, Surah } from "@/services/quranService";

export type QuranRangeUnit = "ayahs" | "lines" | "pages" | "hizbs";

export interface QuranRangeAyah extends Ayah {
  surahNumber: number;
  surahName: string;
}

export interface QuranRangeSegment {
  surahNumber: number;
  surahName: string;
  fromAyah: number;
  toAyah: number;
}

export interface QuranConnectedRange {
  ayahs: QuranRangeAyah[];
  segments: QuranRangeSegment[];
}

interface BuildRangeOptions {
  surahs: Surah[];
  startSurah: number;
  startAyah: number;
  direction?: "asc" | "desc";
  unit?: QuranRangeUnit;
  amount?: number;
}

const numberedAyahs = (surahs: Surah[], direction: "asc" | "desc") => {
  const orderedSurahs = [...surahs].sort((left, right) =>
    direction === "asc"
      ? left.number - right.number
      : right.number - left.number,
  );

  return orderedSurahs.flatMap((surah) =>
    surah.ayahs
      .filter((ayah) => ayah.number > 0)
      .sort((left, right) => left.number - right.number)
      .map((ayah) => ({
        ...ayah,
        surahNumber: surah.number,
        surahName: surah.name,
      })),
  );
};

const splitIntoSegments = (ayahs: QuranRangeAyah[]): QuranRangeSegment[] => {
  const segments: QuranRangeSegment[] = [];
  for (const ayah of ayahs) {
    const previous = segments.at(-1);
    if (!previous || previous.surahNumber !== ayah.surahNumber) {
      segments.push({
        surahNumber: ayah.surahNumber,
        surahName: ayah.surahName,
        fromAyah: ayah.number,
        toAyah: ayah.number,
      });
      continue;
    }
    previous.toAyah = ayah.number;
  }
  return segments;
};

const fromAyahs = (ayahs: QuranRangeAyah[]): QuranConnectedRange | null => {
  if (ayahs.length === 0) return null;
  return { ayahs, segments: splitIntoSegments(ayahs) };
};

/**
 * Builds a continuous range which may cross surah boundaries. The range is
 * split into per-surah segments only when it is persisted to the existing
 * database schema.
 */
const buildToAmount = ({
  surahs,
  startSurah,
  startAyah,
  direction = "asc",
  unit = "ayahs",
  amount = 1,
}: BuildRangeOptions): QuranConnectedRange | null => {
  const allAyahs = numberedAyahs(surahs, direction);
  const startIndex = allAyahs.findIndex(
    (ayah) => ayah.surahNumber === startSurah && ayah.number === startAyah,
  );
  if (startIndex < 0) return null;

  const safeAmount = Math.max(1, Math.trunc(amount));
  const selected: QuranRangeAyah[] = [];
  const boundaries = new Set<number>();
  let accumulatedLines = 0;

  for (let index = startIndex; index < allAyahs.length; index += 1) {
    const ayah = allAyahs[index];
    if (unit === "pages" || unit === "hizbs") {
      const boundary = unit === "pages" ? ayah.page : ayah.hizb;
      if (boundary == null) break;
      if (!boundaries.has(boundary) && boundaries.size >= safeAmount) break;
      boundaries.add(boundary);
    }

    selected.push(ayah);
    if (unit === "ayahs" && selected.length >= safeAmount) break;
    if (unit === "lines") {
      accumulatedLines += Math.max(1, Number(ayah.lines) || 1);
      if (accumulatedLines >= safeAmount) break;
    }
  }

  return fromAyahs(selected);
};

const buildToEnd = (options: Omit<BuildRangeOptions, "unit" | "amount">) => {
  const totalAyahs = options.surahs.reduce(
    (sum, surah) => sum + surah.totalAyahs,
    0,
  );
  return buildToAmount({ ...options, unit: "ayahs", amount: totalAyahs });
};

const truncateAt = (
  range: QuranConnectedRange,
  inclusiveIndex: number,
): QuranConnectedRange | null => {
  const safeIndex = Math.min(
    Math.max(0, Math.trunc(inclusiveIndex)),
    range.ayahs.length - 1,
  );
  return fromAyahs(range.ayahs.slice(0, safeIndex + 1));
};

const amountOf = (range: QuranConnectedRange, unit: QuranRangeUnit): number => {
  if (unit === "ayahs") return range.ayahs.length;
  if (unit === "pages") {
    return new Set(range.ayahs.map((ayah) => ayah.page)).size;
  }
  if (unit === "hizbs") {
    return new Set(range.ayahs.map((ayah) => ayah.hizb)).size;
  }
  return range.ayahs.reduce(
    (sum, ayah) => sum + Math.max(1, Number(ayah.lines) || 1),
    0,
  );
};

export const quranRangeService = {
  buildToAmount,
  buildToEnd,
  truncateAt,
  amountOf,
};
