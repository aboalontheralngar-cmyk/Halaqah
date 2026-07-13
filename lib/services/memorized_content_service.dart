import '../models/ayah.dart';
import '../models/memorization.dart';
import '../models/mushaf_progress.dart';
import '../models/student.dart';

class MemorizedAyahRange {
  final int fromAyah;
  final int toAyah;

  const MemorizedAyahRange({
    required this.fromAyah,
    required this.toAyah,
  });

  bool containsRange(int from, int to) =>
      from >= fromAyah && to <= toAyah && from <= to;
}

/// Builds one revision-safe view of everything the student has memorized.
///
/// Older students may have their starting balance in the profile or Mushaf
/// map, while newer recitations are stored as detailed progress rows. Revision
/// must use all three sources instead of relying on daily rows alone.
class MemorizedContentService {
  const MemorizedContentService._();

  static Map<int, MemorizedAyahRange> buildRanges({
    required Student student,
    required List<MemorizationProgress> progress,
    required List<MushafProgress> mushafProgress,
    required List<Surah> surahs,
  }) {
    final surahById = {for (final surah in surahs) surah.number: surah};
    final ayahsBySurah = <int, Set<int>>{};

    void addAyah(int surahId, int ayah) {
      final surah = surahById[surahId];
      if (surah == null || ayah < 1 || ayah > surah.totalAyahs) return;
      ayahsBySurah.putIfAbsent(surahId, () => <int>{}).add(ayah);
    }

    void addRange(int surahId, int fromAyah, int toAyah) {
      final surah = surahById[surahId];
      if (surah == null) return;
      final safeFrom = fromAyah.clamp(1, surah.totalAyahs).toInt();
      final safeTo = toAyah.clamp(1, surah.totalAyahs).toInt();
      final first = safeFrom < safeTo ? safeFrom : safeTo;
      final last = safeFrom > safeTo ? safeFrom : safeTo;
      for (var ayah = first; ayah <= last; ayah++) {
        addAyah(surahId, ayah);
      }
    }

    for (final row in progress) {
      if (!row.isRevision) {
        addRange(row.surahId, row.fromAyah, row.toAyah);
      }
    }

    final startSurah = student.preMemorizedStartSurah;
    final endSurah = student.preMemorizedEndSurah;
    if (startSurah != null && endSurah != null) {
      final startAyah = student.preMemorizedStartAyah ?? 1;
      final endAyah = student.preMemorizedEndAyah ?? 1;
      if (startSurah == endSurah) {
        addRange(startSurah, startAyah, endAyah);
      } else {
        final start = surahById[startSurah];
        if (start != null) {
          addRange(startSurah, startAyah, start.totalAyahs);
        }
        final firstSurah = startSurah < endSurah ? startSurah : endSurah;
        final lastSurah = startSurah > endSurah ? startSurah : endSurah;
        for (var surahId = firstSurah + 1;
            surahId < lastSurah;
            surahId++) {
          final surah = surahById[surahId];
          if (surah != null) addRange(surahId, 1, surah.totalAyahs);
        }
        addRange(endSurah, 1, endAyah);
      }
    }

    final preMemorizedThumuns = mushafProgress
        .where((row) => row.isPreMemorized)
        .map((row) => '${row.hizbNumber}_${row.thumunNumber}')
        .toSet();
    if (preMemorizedThumuns.isNotEmpty) {
      for (final surah in surahs) {
        for (final ayah in surah.ayahs) {
          final quarterInHizb = ((ayah.quarter - 1) % 4) + 1;
          final firstThumun = (quarterInHizb - 1) * 2 + 1;
          final secondThumun = firstThumun + 1;
          if (preMemorizedThumuns.contains('${ayah.hizb}_$firstThumun') ||
              preMemorizedThumuns.contains('${ayah.hizb}_$secondThumun')) {
            addAyah(surah.number, ayah.number);
          }
        }
      }
    }

    final result = <int, MemorizedAyahRange>{};
    for (final entry in ayahsBySurah.entries) {
      if (entry.value.isEmpty) continue;
      final ordered = entry.value.toList()..sort();
      result[entry.key] = MemorizedAyahRange(
        fromAyah: ordered.first,
        toAyah: ordered.last,
      );
    }
    return result;
  }
}
