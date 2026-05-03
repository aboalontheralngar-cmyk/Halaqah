class Ayah {
  final int id;
  final int surahNumber;
  final int number;
  final String text;
  final int page;
  final int juz;
  final int hizb;
  final int quarter;
  final double lines;
  final int difficulty;

  Ayah({
    required this.id,
    required this.surahNumber,
    required this.number,
    required this.text,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.quarter,
    required this.lines,
    required this.difficulty,
  });

  factory Ayah.fromJson(Map<String, dynamic> json, int surahNumber) {
    return Ayah(
      id: json['id'] ?? 0,
      surahNumber: surahNumber,
      number: json['number'] ?? 0,
      text: json['text'] ?? '',
      page: json['page'] ?? 0,
      juz: json['juz'] ?? 0,
      hizb: json['hizb'] ?? 0,
      quarter: json['quarter'] ?? 0,
      lines: (json['lines'] ?? 0).toDouble(),
      difficulty: json['difficulty'] ?? 0,
    );
  }
}

class Surah {
  final int number;
  final String name;
  final int totalAyahs;
  final int juzStart;
  final int pageStart;
  final List<Ayah> ayahs;

  Surah({
    required this.number,
    required this.name,
    required this.totalAyahs,
    required this.juzStart,
    required this.pageStart,
    required this.ayahs,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    final surahNumber = json['number'] ?? 0;
    final ayahsList = (json['ayahs'] as List?)
        ?.map((a) => Ayah.fromJson(a, surahNumber))
        .toList() ?? [];
    
    return Surah(
      number: surahNumber,
      name: json['name'] ?? '',
      totalAyahs: json['total_ayahs'] ?? 0,
      juzStart: json['juz_start'] ?? 0,
      pageStart: json['page_start'] ?? 0,
      ayahs: ayahsList,
    );
  }

  Ayah? getAyah(int ayahNumber) {
    if (ayahNumber < 1 || ayahNumber > ayahs.length) return null;
    return ayahs.firstWhere((a) => a.number == ayahNumber, orElse: () => ayahs[0]);
  }

  List<Ayah> getAyahRange(int from, int to) {
    return ayahs.where((a) => a.number >= from && a.number <= to).toList();
  }

  double calculateLines(int fromAyah, int toAyah) {
    return getAyahRange(fromAyah, toAyah).fold(0.0, (sum, a) => sum + a.lines);
  }
}
