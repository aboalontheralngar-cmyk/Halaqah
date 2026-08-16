import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/student.dart';
import '../../models/competition.dart';
import '../../services/pdf_service.dart';
import 'competition_judge_screen.dart';
import '../../services/database_service.dart';
import '../../services/peer_level_grouping_service.dart';
import '../../services/quran_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_design_widgets.dart';

class PeerLevelGroupsScreen extends StatefulWidget {
  const PeerLevelGroupsScreen({super.key});

  @override
  State<PeerLevelGroupsScreen> createState() => _PeerLevelGroupsScreenState();
}

class _PeerLevelGroupsScreenState extends State<PeerLevelGroupsScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  final PdfService _pdf = PdfService();
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
    await _quran.initialize();
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
      int? frontierSurahId;
      int? frontierAyah;
      if (ranges.isNotEmpty) {
        final ids = ranges.keys.map((value) => (value as num).toInt()).toList();
        ids.sort();
        frontierSurahId = student.memorizationDirection == 'desc'
            ? ids.first
            : ids.last;
        final frontierRange = ranges[frontierSurahId];
        frontierAyah = frontierRange == null
            ? null
            : (frontierRange.toAyah as num).toInt();
      }
      final frontierSurah = frontierSurahId == null
          ? null
          : _quran.getSurah(frontierSurahId);
      final frontierJuz = frontierSurahId == null || frontierAyah == null
          ? null
          : _quran.getAyah(frontierSurahId, frontierAyah)?.juz;
      final progress = values[1] as List;
      final points = values[2] as List;
      levels.add(
        PeerLevelStudent(
          id: student.id,
          name: student.name,
          memorizedAyahs: total,
          weeklyNewAyahs: _ayahCount(progress.where((row) => !row.isRevision)),
          weeklyReviewAyahs: _ayahCount(progress.where((row) => row.isRevision)),
          weeklyBehaviorPoints: points.fold<double>(
            0,
            (sum, point) => sum + (point.points as num).toDouble(),
          ),
          frontierSurahId: frontierSurahId,
          frontierSurahName: frontierSurah?.name,
          frontierJuz: frontierJuz,
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

  Future<void> _printGroup(PeerLevelGroup group) async {
    final settings = await _db.getSettings();
    final data = await _pdf.generatePeerGroupRoster(
      groupTitle: group.quranRangeTitle,
      rangeLabel: group.juzRangeLabel,
      halaqahName: settings.halaqahName,
      members: [
        for (final student in group.weeklyRanking)
          {
            'name': student.name,
            'memorized': student.memorizedAyahs,
            'new': student.weeklyNewAyahs,
            'review': student.weeklyReviewAyahs,
            'score': _formatScore(student.weeklyScore),
          },
      ],
    );
    await _pdf.sharePdf(
      data,
      'حلقتي_${group.quranRangeTitle.replaceAll(' ', '_')}.pdf',
    );
  }

  Future<void> _startGroupCompetition(PeerLevelGroup group) async {
    final event = CompetitionEvent(
      title: 'تحدي ${group.quranRangeTitle}',
      category: 'منافسة الأقران',
      maximumScore: 100,
    );
    await _db.saveCompetitionEvent(event);
    await _db.saveSetting(
      'competition_allowed_student_ids_${event.id}',
      jsonEncode(group.students.map((student) => student.id).toList()),
    );
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CompetitionJudgeScreen(
          event: event,
          allowedStudentIds: group.students.map((student) => student.id).toSet(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _createGroupActivity(
    PeerLevelGroup group, {
    String? suggestedTitle,
  }) async {
    final controller = TextEditingController(text: suggestedTitle ?? '');
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('إضافة فعالية — ${group.quranRangeTitle}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'اسم الفعالية',
            hintText: 'مثال: سرد متتابع أو تحدي مراجعة',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.isNotEmpty) Navigator.pop(dialogContext, value);
            },
            child: const Text('حفظ الفعالية'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (title == null || !mounted) return;

    await _db.saveCompetitionEvent(
      CompetitionEvent(
        title: '${group.quranRangeTitle} — $title',
        category: 'فعالية مجموعة',
        maximumScore: 100,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم حفظ فعالية «$title» لهذه المجموعة')),
    );
  }

  Future<void> _showGroupActivity(PeerLevelGroup group) async {
    const ideas = [
      'سرد متتابع: كل طالب يكمل من حيث توقف زميله.',
      'تحدي المراجعة: أقل أخطاء في مقطع متقارب.',
      'تحدي الثبات: إعادة نفس المقطع بعد 48 ساعة وقياس التحسن.',
      'تحدي الإنجاز الأسبوعي: حفظ + مراجعة + نقاط انضباط.',
    ];
    final savedActivities = (await _db.getCompetitionEvents())
        .where(
          (event) =>
              event.category == 'فعالية مجموعة' &&
              event.title.startsWith('${group.quranRangeTitle} — '),
        )
        .toList();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                group.quranRangeTitle,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(group.juzRangeLabel),
              if (savedActivities.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'فعاليات محفوظة',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                for (final event in savedActivities.take(6))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: Text(
                      event.title.replaceFirst('${group.quranRangeTitle} — ', ''),
                    ),
                    subtitle: Text(Helpers.formatPlanDate(event.createdAt)),
                  ),
              ],
              const SizedBox(height: 16),
              Text(
                'أفكار فعاليات جاهزة',
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              for (final idea in ideas)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lightbulb_outline),
                  title: Text(idea),
                  trailing: IconButton(
                    tooltip: 'حفظ كفعالية',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _createGroupActivity(group, suggestedTitle: idea.split(':').first);
                    },
                    icon: const Icon(Icons.add_circle_outline),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _createGroupActivity(group);
                },
                icon: const Icon(Icons.add_task_outlined),
                label: const Text('إضافة فعالية خاصة'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _startGroupCompetition(group);
                },
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('بدء مسابقة لهذه المجموعة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          group.quranRangeTitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          group.juzRangeLabel,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: scheme.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: scheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '${group.minLevel}–${group.maxLevel} آية',
                                      style: Theme.of(context).textTheme.labelSmall,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _printGroup(group),
                                    icon: const Icon(Icons.print_outlined),
                                    label: const Text('طباعة الأسماء'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showGroupActivity(group),
                                    icon: const Icon(Icons.local_activity_outlined),
                                    label: const Text('أنشطة وفعاليات'),
                                  ),
                                  FilledButton.tonalIcon(
                                    onPressed: () => _startGroupCompetition(group),
                                    icon: const Icon(Icons.emoji_events_outlined),
                                    label: const Text('مسابقة المجموعة'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
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
                                              'هذا الأسبوع: ${student.weeklyNewAyahs} حفظ جديد • ${student.weeklyReviewAyahs} مراجعة • ${Helpers.formatNumber(student.weeklyBehaviorPoints)} نقاط',
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
