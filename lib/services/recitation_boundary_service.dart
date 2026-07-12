import '../models/ayah.dart';

class RecitationBoundaryService {
  static int endOfPage(Surah surah, int startAyah) {
    final start = surah.getAyah(_clampAyah(surah, startAyah));
    if (start == null) return _clampAyah(surah, startAyah);
    return surah.ayahs
        .where((ayah) => ayah.number >= start.number && ayah.page == start.page)
        .fold<int>(start.number, (last, ayah) => ayah.number > last ? ayah.number : last);
  }

  static int endOfHizb(Surah surah, int startAyah) {
    final start = surah.getAyah(_clampAyah(surah, startAyah));
    if (start == null) return _clampAyah(surah, startAyah);
    return surah.ayahs
        .where((ayah) => ayah.number >= start.number && ayah.hizb == start.hizb)
        .fold<int>(start.number, (last, ayah) => ayah.number > last ? ayah.number : last);
  }

  static int _clampAyah(Surah surah, int ayah) =>
      ayah.clamp(1, surah.totalAyahs).toInt();
}
