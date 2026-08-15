import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/peer_level_grouping_service.dart';
import '../../widgets/app_design_widgets.dart';

class PeerLevelGroupsScreen extends StatefulWidget {
  const PeerLevelGroupsScreen({super.key});

  @override
  State<PeerLevelGroupsScreen> createState() => _PeerLevelGroupsScreenState();
}

class _PeerLevelGroupsScreenState extends State<PeerLevelGroupsScreen> {
  final DatabaseService _db = DatabaseService();
  List<PeerLevelStudent> _levels = [];
  List<PeerLevelGroup> _groups = [];
  int _groupCount = 3;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime _startOfCurrentWeek(DateTime now) {
    final day = DateTime(now.year, now.month, now.day);
    // Saturday is the start of the educational week in this workflow.
    final daysSinceSaturday = (day.weekday + 1) % 7;
    return day.subtract(Duration(days: daysSinceSaturday));
  }

  int _ayahCount(Iterable<dynamic> rows) {
    var total = 0;
    for (final row in rows) {
      total += (row.toAyah as int) - (row.fromAyah as int) + 1;
    }
    return total;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final weekStart = _startOfCurrentWeek(now);
    final students = await _db.getStudents(status: 'active');
    final savedGroupCount = int.tryParse(
      await _db.getSetting('peer_level_group_count') ?? '',
    );
    final levels = <PeerLevelStudent>[];
    for (final Student student in students) {
      final values = await Future.wait<dynamic>([
        _db.getStudentMemorizedRanges(student.id),
        _db.getStudentMemorizationInRange(student.id, weekStart, now),
        _db.getStudentBehaviorPointsInRange(student.id, weekStart, now),
      ]);
      final ranges = values[0] as Map;
      final total = _ayahCount(ranges.values);
      final progress = values[1] as List;
      final points = values[2] as List;
      levels.add(
        PeerLevelStudent(
          id: student.id,
          name: student.name,
          memorizedAyahs: total,
          weeklyNewAyahs: _ayahCount(progress.where((row) => !row.isRevision)),
          weeklyReviewAyahs: _ayahCount(progress.where((row) => row.isRevision)),
          weeklyBehaviorPoints: points.fold<int>(
            0,
            (sum, point) => sum + (point.points as int),
          ),
        ),
      );
    }
    if (!mounted) return;
    final preferred = savedGroupCount ?? _groupCount;
    final effective = preferred.clamp(1, levels.isEmpty ? 1 : levels.length).toInt();
    setState(() {
      _levels = levels;
      _groupCount = effective;
      _groups = PeerLevelGroupingService.group(
        students: levels,
        groupCount: effective,
      );
      _loading = false;
    });
  }

  Future<void> _regroup(int count) async {
    setState(() {
      _groupCount = count;
      _groups = PeerLevelGroupingService.group(
        students: _levels,
        groupCount: count,
      );
    });
    await _db.saveSetting('peer_level_group_count', '$count');
  }

  String _formatScore(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final maxGroups = _levels.length.clamp(1, 10).toInt();
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('مجموعات المستوى المتقارب')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : AppScreenBody(
              scrollable: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppPageIntro(
                    title: 'مجموعات التنافس بين الأقران',
                    subtitle: 'المجموعة تُبنى من مقدار المحفوظ الكلي، ثم يرتب النظام أفرادها أسبوعيًا حسب الإنجاز الجديد والمراجعة والنقاط السلوكية.',
                    icon: Icons.groups_2_outlined,
                  ),
                  const SizedBox(height: 16),
                  if (_levels.isEmpty)
                    const AppEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'لا يوجد طلاب نشطون',
                      message: 'أضف الطلاب أولًا ثم ارجع لتكوين مجموعات التنافس.',
                    )
                  else ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'عدد المجموعات',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DropdownButton<int>(
                              value: _groupCount,
                              items: [
                                for (var i = 1; i <= maxGroups; i++)
                                  DropdownMenuItem(value: i, child: Text('$i')),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  _regroup(value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    for (final group in _groups)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(child: Text('${group.index}')),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'مجموعة ${group.index}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  Text(
                                    '${group.minLevel}–${group.maxLevel} آية',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'الترتيب الأسبوعي',
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: scheme.primary,
                                    ),
                              ),
                              const Divider(height: 20),
                              for (var rank = 0; rank < group.weeklyRanking.length; rank++)
                                Builder(
                                  builder: (context) {
                                    final student = group.weeklyRanking[rank];
                                    final best = group.weeklyBestScore;
                                    final progress = best <= 0
                                        ? 0.0
                                        : (student.weeklyScore / best).clamp(0, 1).toDouble();
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        children: [
                                          ListTile(
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            leading: CircleAvatar(
                                              backgroundColor: rank == 0
                                                  ? scheme.secondaryContainer
                                                  : scheme.surfaceContainerHigh,
                                              foregroundColor: rank == 0
                                                  ? scheme.onSecondaryContainer
                                                  : scheme.onSurfaceVariant,
                                              child: Text('${rank + 1}'),
                                            ),
                                            title: Text(
                                              student.name,
                                              style: const TextStyle(fontWeight: FontWeight.w700),
                                            ),
                                            subtitle: Text(
                                              'هذا الأسبوع: ${student.weeklyNewAyahs} حفظ جديد • ${student.weeklyReviewAyahs} مراجعة • ${student.weeklyBehaviorPoints} نقاط',
                                            ),
                                            trailing: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  _formatScore(student.weeklyScore),
                                                  style: const TextStyle(fontWeight: FontWeight.w900),
                                                ),
                                                Text(
                                                  '${student.memorizedAyahs} آية محفوظة',
                                                  style: Theme.of(context).textTheme.labelSmall,
                                                ),
                                              ],
                                            ),
                                          ),
                                          LinearProgressIndicator(
                                            value: progress,
                                            minHeight: 5,
                                            borderRadius: BorderRadius.circular(8),
                                            backgroundColor: scheme.surfaceContainerHigh,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}
