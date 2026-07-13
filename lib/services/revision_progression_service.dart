import '../models/ayah.dart';
import '../models/memorization.dart';
import 'memorized_content_service.dart';

typedef RevisionSurahLookup = Surah? Function(int surahId);

class RevisionProgressionService {
  const RevisionProgressionService._();

  static Map<String, int>? nextStartingPoint({
    required List<int> memorizedSurahIds,
    required List<MemorizationProgress> progress,
    required bool ascending,
    required RevisionSurahLookup getSurah,
    Map<int, MemorizedAyahRange> memorizedRanges = const {},
  }) {
    if (memorizedSurahIds.isEmpty) return null;
    final ordered = memorizedSurahIds.toSet().toList()..sort();
    if (!ascending) {
      final descending = ordered.reversed.toList();
      ordered
        ..clear()
        ..addAll(descending);
    }

    final revisions = progress.where((row) => row.isRevision).toList()
      ..sort((a, b) {
        final byCreatedAt = b.createdAt.compareTo(a.createdAt);
        return byCreatedAt != 0 ? byCreatedAt : b.date.compareTo(a.date);
      });
    if (revisions.isEmpty) {
      final firstSurah = ordered.first;
      return {
        'surahId': firstSurah,
        'fromAyah': memorizedRanges[firstSurah]?.fromAyah ?? 1,
      };
    }

    final latest = revisions.first;
    final surahIndex = ordered.indexOf(latest.surahId);
    final surah = getSurah(latest.surahId);
    final latestRange = memorizedRanges[latest.surahId];
    final lastMemorizedAyah = latestRange?.toAyah ?? surah?.totalAyahs;
    if (surahIndex >= 0 &&
        lastMemorizedAyah != null &&
        latest.toAyah < lastMemorizedAyah) {
      return {
        'surahId': latest.surahId,
        'fromAyah': (latest.toAyah + 1)
            .clamp(latestRange?.fromAyah ?? 1, lastMemorizedAyah)
            .toInt(),
      };
    }

    final nextIndex = surahIndex < 0 || surahIndex == ordered.length - 1
        ? 0
        : surahIndex + 1;
    final nextSurah = ordered[nextIndex];
    return {
      'surahId': nextSurah,
      'fromAyah': memorizedRanges[nextSurah]?.fromAyah ?? 1,
    };
  }
}
