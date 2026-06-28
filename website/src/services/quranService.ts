export interface Ayah {
  number: number;
  page: number;
  text?: string;
  juz?: number;
  hizb?: number;
  quarter?: number;
  lines?: number;
  difficulty?: number;
}

export interface Surah {
  number: number;
  name: string;
  totalAyahs: number;
  ayahs: Ayah[];
}

class QuranService {
  private static instance: QuranService;
  private surahs: Surah[] = [];
  private isLoaded = false;

  private constructor() {}

  public static getInstance(): QuranService {
    if (!QuranService.instance) {
      QuranService.instance = new QuranService();
    }
    return QuranService.instance;
  }

  public async initialize(): Promise<void> {
    if (this.isLoaded) return;
    try {
      const response = await fetch('/quran_data.json');
      const data = await response.json();
      this.surahs = (data.surahs as any[]).map(s => ({
        number: s.number,
        name: s.name,
        totalAyahs: s.total_ayahs || s.ayahs?.length || 0,
        ayahs: (s.ayahs as any[] | undefined)?.map(a => ({
          number: a.number,
          page: a.page,
          text: a.text,
          juz: a.juz,
          hizb: a.hizb,
          quarter: a.quarter,
          lines: a.lines,
          difficulty: a.difficulty,
        })) || [],
      }));
      this.isLoaded = true;
    } catch (error) {
      console.error("Failed to load Quran data:", error);
    }
  }

  public getSurahs(): Surah[] {
    return this.surahs;
  }

  public getSurah(number: number): Surah | undefined {
    return this.surahs.find(s => s.number === number);
  }

  public getAyahRange(surahNumber: number, fromAyah: number, toAyah: number): Ayah[] {
    const surah = this.getSurah(surahNumber);
    if (!surah) return [];
    return surah.ayahs.filter(a => a.number >= fromAyah && a.number <= toAyah);
  }
}

export const quranService = QuranService.getInstance();
