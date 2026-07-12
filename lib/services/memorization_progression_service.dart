import '../models/ayah.dart';
import '../models/memorization.dart';
import '../models/student.dart';
import 'memorization_measure_service.dart';

typedef SurahLookup = Surah? Function(int surahId);

class MemorizationProgressionService {
  const MemorizationProgressionService._();

  static Map<String, int>? nextStartingPoint({
    required Student student,
    required List<MemorizationProgress> progress,
    required SurahLookup getSurah,
  }) {
    final memorizationRows = progress.where((row) => !row.isRevision).toList();
    if (memorizationRows.isNotEmpty) {
      final front = _frontRow(memorizationRows, student.memorizationDirection);
      return _afterPosition(
        student: student,
        surahId: front.surahId,
        toAyah: front.toAyah,
        getSurah: getSurah,
      );
    }

    final preEndSurah = student.preMemorizedEndSurah;
    if (preEndSurah != null) {
      return _afterPosition(
        student: student,
        surahId: preEndSurah,
        toAyah: student.preMemorizedEndAyah ?? 1,
        getSurah: getSurah,
      );
    }

    final defaultSurahId = student.memorizationDirection == 'desc' ? 114 : 1;
    return _rangeForPlan(
      student: student,
      surahId: defaultSurahId,
      fromAyah: 1,
      getSurah: getSurah,
    );
  }

  static MemorizationProgress _frontRow(
    List<MemorizationProgress> rows,
    String direction,
  ) {
    final isDescendingSurahNumber = direction == 'desc';
    rows.sort((a, b) {
      if (a.surahId != b.surahId) {
        return isDescendingSurahNumber
            ? a.surahId.compareTo(b.surahId)
            : b.surahId.compareTo(a.surahId);
      }
      return b.toAyah.compareTo(a.toAyah);
    });
    return rows.first;
  }

  static Map<String, int>? _afterPosition({
    required Student student,
    required int surahId,
    required int toAyah,
    required SurahLookup getSurah,
  }) {
    final currentSurah = getSurah(surahId);
    if (currentSurah == null) return null;

    if (toAyah < currentSurah.totalAyahs) {
      return _rangeForPlan(
        student: student,
        surahId: surahId,
        fromAyah: toAyah + 1,
        getSurah: getSurah,
      );
    }

    final nextSurahId = student.memorizationDirection == 'desc'
        ? surahId - 1
        : surahId + 1;
    if (nextSurahId < 1 || nextSurahId > 114) return null;
    return _rangeForPlan(
      student: student,
      surahId: nextSurahId,
      fromAyah: 1,
      getSurah: getSurah,
    );
  }

  static Map<String, int>? _rangeForPlan({
    required Student student,
    required int surahId,
    required int fromAyah,
    required SurahLookup getSurah,
  }) {
    final surah = getSurah(surahId);
    if (surah == null || fromAyah > surah.totalAyahs) return null;
    return {
      'surahId': surahId,
      'fromAyah': fromAyah,
      'toAyah': MemorizationMeasureService.calculateToAyah(
        surah: surah,
        fromAyah: fromAyah,
        planType: student.planType,
        planAmount: student.planAmount,
      ),
    };
  }
}
