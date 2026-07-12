import '../models/ayah.dart';
import '../models/memorization.dart';

typedef RevisionSurahLookup = Surah? Function(int surahId);

class RevisionProgressionService {
  const RevisionProgressionService._();

  static Map<String, int>? nextStartingPoint({
    required List<int> memorizedSurahIds,
    required List<MemorizationProgress> progress,
    required bool ascending,
    required RevisionSurahLookup getSurah,
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
      return {'surahId': ordered.first, 'fromAyah': 1};
    }

    final latest = revisions.first;
    final surahIndex = ordered.indexOf(latest.surahId);
    final surah = getSurah(latest.surahId);
    if (surahIndex >= 0 &&
        surah != null &&
        latest.toAyah < surah.totalAyahs) {
      return {
        'surahId': latest.surahId,
        'fromAyah': latest.toAyah + 1,
      };
    }

    final nextIndex = surahIndex < 0 || surahIndex == ordered.length - 1
        ? 0
        : surahIndex + 1;
    return {'surahId': ordered[nextIndex], 'fromAyah': 1};
  }
}
