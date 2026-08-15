import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/peer_level_grouping_service.dart';

void main() {
  test('creates balanced contiguous peer groups', () {
    final students = List.generate(
      8,
      (i) => PeerLevelStudent(
        id: '$i',
        name: 'S$i',
        memorizedAyahs: (i + 1) * 100,
      ),
    );
    final groups = PeerLevelGroupingService.group(
      students: students,
      groupCount: 3,
    );
    expect(groups.map((g) => g.students.length).toList(), [3, 3, 2]);
    expect(groups[0].maxLevel, lessThan(groups[1].minLevel));
    expect(groups[1].maxLevel, lessThan(groups[2].minLevel));
  });

  test('never creates more groups than students', () {
    const students = [
      PeerLevelStudent(id: '1', name: 'A', memorizedAyahs: 10),
    ];
    expect(
      PeerLevelGroupingService.group(students: students, groupCount: 8).length,
      1,
    );
  });

  test('weekly ranking rewards progress inside the same peer group', () {
    const students = [
      PeerLevelStudent(
        id: '1',
        name: 'A',
        memorizedAyahs: 500,
        weeklyNewAyahs: 8,
        weeklyReviewAyahs: 20,
        weeklyBehaviorPoints: 2,
      ),
      PeerLevelStudent(
        id: '2',
        name: 'B',
        memorizedAyahs: 510,
        weeklyNewAyahs: 4,
        weeklyReviewAyahs: 8,
        weeklyBehaviorPoints: 0,
      ),
    ];
    final group = PeerLevelGroupingService.group(
      students: students,
      groupCount: 1,
    ).single;
    expect(group.weeklyRanking.first.id, '1');
    expect(group.weeklyRanking.first.weeklyScore, 15);
  });

  test('negative behavior does not produce a negative competition score', () {
    expect(
      PeerLevelGroupingService.weeklyScore(
        newAyahs: 0,
        reviewAyahs: 0,
        behaviorPoints: -20,
      ),
      0,
    );
  });
}
