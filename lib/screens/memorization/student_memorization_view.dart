import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/database_service.dart';
import '../../services/memorized_content_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/quality_rating.dart';

class StudentMemorizationView extends StatefulWidget {
  final Student student;

  const StudentMemorizationView({super.key, required this.student});

  @override
  State<StudentMemorizationView> createState() => _StudentMemorizationViewState();
}

class _StudentMemorizationViewState extends State<StudentMemorizationView> {
  final DatabaseService _db = DatabaseService();
  List<MemorizationProgress> _allProgress = [];
  Map<int, SurahProgress> _surahsProgress = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final values = await Future.wait<dynamic>([
        _db.getStudentMemorization(widget.student.id),
        _db.getStudentMemorizedRanges(widget.student.id),
      ]);
      final progress = values[0] as List<MemorizationProgress>;
      final inferredRanges = values[1] as Map<int, MemorizedAyahRange>;
      final surahsProgress = <int, SurahProgress>{};

      // The profile view uses the same canonical inferred memorized frontier as
      // revision and exams. A student no longer needs a manually maintained
      // "previous memorized" range just to make their true balance visible.
      for (final entry in inferredRanges.entries) {
        final surahData = QuranData.surahs.firstWhere(
          (s) => s['id'] == entry.key,
          orElse: () => {},
        );
        if (surahData.isEmpty) continue;
        final range = entry.value;
        final item = SurahProgress(
          surahId: entry.key,
          surahName: surahData['name'],
          totalAyahs: surahData['ayahs'],
          juz: surahData['juz'],
        );
        item.addMemorization(range.fromAyah, range.toAyah);
        surahsProgress[entry.key] = item;
      }

      setState(() {
        _allProgress = progress;
        _surahsProgress = surahsProgress;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  int get _totalMemorizedAyahs {
    int total = 0;
    for (final sp in _surahsProgress.values) {
      total += sp.memorizedAyahs;
    }
    return total;
  }

  double get _totalPages => _totalMemorizedAyahs / 15;
  double get _totalJuz => _totalMemorizedAyahs / 604 * 30;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('محفوظات ${widget.student.name}'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildStatsSection()),
                  SliverToBoxAdapter(child: _buildProgressOverview()),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: _buildSurahGrid(),
                  ),
                  SliverToBoxAdapter(child: _buildRecentActivity()),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            widget.student.name,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('آية', '$_totalMemorizedAyahs'),
              _buildStatItem('صفحة', _totalPages.toStringAsFixed(1)),
              _buildStatItem('جزء', _totalJuz.toStringAsFixed(2)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.85),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressOverview() {
    final completedSurahs = _surahsProgress.values
        .where((sp) => sp.completionPercentage >= 100)
        .length;
    final partialSurahs = _surahsProgress.values
        .where((sp) => sp.completionPercentage > 0 && sp.completionPercentage < 100)
        .length;

    final semantic = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildProgressCard(
              'سور مكتملة',
              '$completedSurahs',
              semantic.success,
              Icons.check_circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              'قيد الحفظ',
              '$partialSurahs',
              semantic.warning,
              Icons.hourglass_bottom,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildProgressCard(
              'نسبة الإتمام',
              '${(_totalMemorizedAyahs / 6236 * 100).toStringAsFixed(1)}%',
              Theme.of(context).primaryColor,
              Icons.pie_chart,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahGrid() {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final surah = QuranData.surahs[index];
          final surahId = surah['id'] as int;
          final progress = _surahsProgress[surahId];
          return _buildSurahCell(surah, progress);
        },
        childCount: QuranData.surahs.length,
      ),
    );
  }

  Widget _buildSurahCell(Map<String, dynamic> surah, SurahProgress? progress) {
    final percentage = progress?.completionPercentage ?? 0;
    Color bgColor;
    Color textColor;

    final semantic = AppSemanticColors.of(context);
    final scheme = Theme.of(context).colorScheme;
    if (percentage >= 100) {
      bgColor = semantic.successContainer;
      textColor = semantic.success;
    } else if (percentage > 0) {
      bgColor = semantic.warningContainer;
      textColor = semantic.warning;
    } else {
      bgColor = scheme.surfaceContainerLow;
      textColor = scheme.onSurfaceVariant;
    }

    return InkWell(
      onTap: progress != null ? () => _showSurahDetails(surah, progress) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${surah['id']}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: textColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              surah['name'],
              style: TextStyle(
                fontSize: 8,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (percentage > 0 && percentage < 100) ...[
              const SizedBox(height: 4),
              Text(
                '${percentage.round()}%',
                style: TextStyle(
                  fontSize: 8,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recentProgress = _allProgress.take(10).toList();
    if (recentProgress.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'آخر النشاط',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...recentProgress.map((p) => _buildActivityItem(p)),
        ],
      ),
    );
  }

  Widget _buildActivityItem(MemorizationProgress progress) {
    final surah = QuranData.surahs.firstWhere(
      (s) => s['id'] == progress.surahId,
      orElse: () => {'name': 'غير معروف'},
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: progress.isRevision
              ? AppSemanticColors.of(context).infoContainer
              : AppSemanticColors.of(context).successContainer,
          child: Icon(
            progress.isRevision ? Icons.replay : Icons.menu_book,
            color: progress.isRevision
                ? AppSemanticColors.of(context).info
                : AppSemanticColors.of(context).success,
            size: 20,
          ),
        ),
        title: Text(
          surah['name'],
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${progress.isRevision ? 'مراجعة' : 'حفظ'} - الآيات ${progress.fromAyah}-${progress.toAyah}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            QualityBadge(rating: progress.qualityRating),
            const SizedBox(height: 4),
            Text(
              Helpers.formatHijriDate(progress.date),
              style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }

  void _showSurahDetails(Map<String, dynamic> surah, SurahProgress progress) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    '${surah['id']}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        surah['name'],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'الجزء ${surah['juz']} - ${surah['ayahs']} آية',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: progress.completionPercentage / 100,
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress.completionPercentage >= 100
                    ? AppSemanticColors.of(context).success
                    : AppSemanticColors.of(context).warning,
              ),
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${progress.memorizedAyahs} من ${progress.totalAyahs} آية'),
                Text(
                  '${progress.completionPercentage.round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: progress.completionPercentage >= 100
                        ? AppSemanticColors.of(context).success
                        : AppSemanticColors.of(context).warning,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SurahProgress {
  final int surahId;
  final String surahName;
  final int totalAyahs;
  final int juz;
  final Set<int> _memorizedAyahs = {};

  SurahProgress({
    required this.surahId,
    required this.surahName,
    required this.totalAyahs,
    required this.juz,
  });

  void addMemorization(int from, int to) {
    for (int i = from; i <= to; i++) {
      _memorizedAyahs.add(i);
    }
  }

  int get memorizedAyahs => _memorizedAyahs.length;
  double get completionPercentage => (memorizedAyahs / totalAyahs * 100);
}
