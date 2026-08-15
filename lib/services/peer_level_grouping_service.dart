class PeerLevelStudent {
  final String id;
  final String name;
  final int memorizedAyahs;
  final int weeklyNewAyahs;
  final int weeklyReviewAyahs;
  final int weeklyBehaviorPoints;

  const PeerLevelStudent({
    required this.id,
    required this.name,
    required this.memorizedAyahs,
    this.weeklyNewAyahs = 0,
    this.weeklyReviewAyahs = 0,
    this.weeklyBehaviorPoints = 0,
  });

  /// Weekly competition score among peers.
  ///
  /// New memorization is the main driver, review contributes at quarter weight,
  /// and the existing behavior point balance is included so consistency and
  /// discipline still matter without overpowering Quran progress.
  double get weeklyScore => PeerLevelGroupingService.weeklyScore(
        newAyahs: weeklyNewAyahs,
        reviewAyahs: weeklyReviewAyahs,
        behaviorPoints: weeklyBehaviorPoints,
      );
}

class PeerLevelGroup {
  final int index;
  final List<PeerLevelStudent> students;

  const PeerLevelGroup({required this.index, required this.students});

  int get minLevel => students.isEmpty ? 0 : students.first.memorizedAyahs;
  int get maxLevel => students.isEmpty ? 0 : students.last.memorizedAyahs;
  int get spread => maxLevel - minLevel;

  List<PeerLevelStudent> get weeklyRanking {
    final ranked = List<PeerLevelStudent>.from(students)
      ..sort((a, b) {
        final byScore = b.weeklyScore.compareTo(a.weeklyScore);
        if (byScore != 0) return byScore;
        final byNew = b.weeklyNewAyahs.compareTo(a.weeklyNewAyahs);
        if (byNew != 0) return byNew;
        final byReview = b.weeklyReviewAyahs.compareTo(a.weeklyReviewAyahs);
        if (byReview != 0) return byReview;
        return a.name.compareTo(b.name);
      });
    return ranked;
  }

  double get weeklyBestScore =>
      weeklyRanking.isEmpty ? 0 : weeklyRanking.first.weeklyScore;
}

/// Groups students by nearest memorization level and ranks progress inside each
/// peer group. Grouping stays based on total memorized Quran so students compete
/// with genuinely similar peers; weekly movement is only used for ranking.
class PeerLevelGroupingService {
  const PeerLevelGroupingService._();

  static double weeklyScore({
    required int newAyahs,
    required int reviewAyahs,
    required int behaviorPoints,
  }) {
    final score = newAyahs + (reviewAyahs * 0.25) + behaviorPoints;
    return score < 0 ? 0 : score;
  }

  static List<PeerLevelGroup> group({
    required List<PeerLevelStudent> students,
    required int groupCount,
  }) {
    if (students.isEmpty) return const [];
    final count = groupCount.clamp(1, students.length).toInt();
    final ordered = List<PeerLevelStudent>.from(students)
      ..sort((a, b) {
        final byLevel = a.memorizedAyahs.compareTo(b.memorizedAyahs);
        return byLevel != 0 ? byLevel : a.name.compareTo(b.name);
      });
    final baseSize = ordered.length ~/ count;
    final extra = ordered.length % count;
    var cursor = 0;
    final groups = <PeerLevelGroup>[];
    for (var i = 0; i < count; i++) {
      final size = baseSize + (i < extra ? 1 : 0);
      final chunk = ordered.sublist(cursor, cursor + size);
      groups.add(PeerLevelGroup(index: i + 1, students: chunk));
      cursor += size;
    }
    return groups;
  }
}
