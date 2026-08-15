import '../models/ayah.dart';

class MandatoryRevisionChunk {
  final int dayNumber;
  final int totalDays;
  final int fromAyah;
  final int toAyah;
  final int fromPage;
  final int toPage;

  const MandatoryRevisionChunk({
    required this.dayNumber,
    required this.totalDays,
    required this.fromAyah,
    required this.toAyah,
    required this.fromPage,
    required this.toPage,
  });
}

/// يقسم نطاق السورة المحفوظ على أيام التثبيت بحسب صفحات المصحف.
///
/// السورة ذات خمس صفحات فأكثر توزع على خمسة أيام كحد أقصى، والسور الأقصر
/// توزع على عدد صفحاتها حتى لا نصنع أياماً فارغة أو نكرر الصفحة نفسها بلا داعٍ.
class MandatoryRevisionScheduleService {
  static MandatoryRevisionChunk? chunkForDay({
    required Surah surah,
    required int fromAyah,
    required int toAyah,
    required int completedDays,
    int maxDays = 5,
  }) {
    if (maxDays <= 0) return null;

    final ayahs = surah.ayahs
        .where(
          (ayah) =>
              ayah.number > 0 &&
              ayah.number >= fromAyah &&
              ayah.number <= toAyah,
        )
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    if (ayahs.isEmpty) return null;

    final pages = <int>[];
    for (final ayah in ayahs) {
      if (!pages.contains(ayah.page)) pages.add(ayah.page);
    }
    if (pages.isEmpty) return null;

    final totalDays = pages.length < maxDays ? pages.length : maxDays;
    if (completedDays < 0 || completedDays >= totalDays) return null;

    // قسمة متوازنة للصفحات مع إبقاء ترتيب الصفحات دون كسر صفحة بين يومين.
    final startPageIndex = (completedDays * pages.length) ~/ totalDays;
    final endPageIndex = (((completedDays + 1) * pages.length) ~/ totalDays) - 1;
    final safeEndIndex = endPageIndex < startPageIndex
        ? startPageIndex
        : endPageIndex;
    final selectedPages = pages.sublist(startPageIndex, safeEndIndex + 1);
    final selectedAyahs = ayahs
        .where((ayah) => selectedPages.contains(ayah.page))
        .toList();
    if (selectedAyahs.isEmpty) return null;

    return MandatoryRevisionChunk(
      dayNumber: completedDays + 1,
      totalDays: totalDays,
      fromAyah: selectedAyahs.first.number,
      toAyah: selectedAyahs.last.number,
      fromPage: selectedPages.first,
      toPage: selectedPages.last,
    );
  }
}
