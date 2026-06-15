export interface Surah {
  number: number;
  name: string;
  totalAyahs: number;
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
}

export const quranService = QuranService.getInstance();
