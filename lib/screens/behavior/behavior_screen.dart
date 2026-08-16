import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../utils/helpers.dart';
import 'add_point_screen.dart';
import 'points_history_screen.dart';
import 'appearance_violations_screen.dart';

class BehaviorScreen extends StatefulWidget {
  const BehaviorScreen({super.key});

  @override
  State<BehaviorScreen> createState() => _BehaviorScreenState();
}

class _BehaviorScreenState extends State<BehaviorScreen> {
  final DatabaseService _db = DatabaseService();
  List<StudentWithPoints> _students = [];
  bool _isLoading = true;
  String _filter = 'all';
  String _searchQuery = '';
  int _unresolvedViolationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.getStudents(status: 'active'),
        _db.getBehaviorSummaries(),
      ]);
      final students = results[0] as List<Student>;
      final summaries =
          results[1] as Map<String, StudentBehaviorSummary>;
      final studentsWithPoints = <StudentWithPoints>[];
      var unresolvedCount = 0;

      for (final student in students) {
        final summary = summaries[student.id] ??
            const StudentBehaviorSummary(
              totalPoints: 0,
              unresolvedViolations: 0,
            );
        unresolvedCount += summary.unresolvedViolations;
        studentsWithPoints.add(StudentWithPoints(
          student: student,
          totalPoints: summary.totalPoints,
          hasUnresolvedViolations: summary.unresolvedViolations > 0,
        ));
      }

      studentsWithPoints.sort((a, b) => b.totalPoints.compareTo(a.totalPoints));

      setState(() {
        _students = studentsWithPoints;
        _unresolvedViolationsCount = unresolvedCount;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<StudentWithPoints> get _filteredStudents {
    Iterable<StudentWithPoints> result = _students;
    if (_filter == 'positive') {
      result = result.where((s) => s.totalPoints > 0);
    } else if (_filter == 'negative') {
      result = result.where((s) => s.totalPoints < 0);
    } else if (_filter == 'violations') {
      result = result.where((s) => s.hasUnresolvedViolations);
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((item) {
        final student = item.student;
        return student.name.toLowerCase().contains(query) ||
            student.studentCode.toLowerCase().contains(query) ||
            student.guardianPhone.toLowerCase().contains(query);
      });
    }
    return result.toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('النقاط والسلوك'),
        actions: [
          if (_unresolvedViolationsCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$_unresolvedViolationsCount'),
                child: const Icon(Icons.warning),
              ),
              onPressed: () => _navigateToViolations(),
              tooltip: 'مخالفات قائمة',
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'positive', child: Text('نقاط إيجابية')),
              const PopupMenuItem(value: 'negative', child: Text('نقاط سلبية')),
              const PopupMenuItem(value: 'violations', child: Text('مخالفات قائمة')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsBar(),
                if (_unresolvedViolationsCount > 0) _buildViolationsAlert(),
                _buildSearchAndFilter(),
                Expanded(
                  child: _filteredStudents.isEmpty
                      ? _buildEmptyState()
                      : _buildStudentList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddPoint(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة نقاط'),
      ),
    );
  }

  Widget _buildStatsBar() {
    final positiveCount = _students.where((s) => s.totalPoints > 0).length;
    final negativeCount = _students.where((s) => s.totalPoints < 0).length;
    final totalPoints = _students.fold<double>(0, (sum, s) => sum + s.totalPoints);

    final semantic = AppSemanticColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatChip('الطلاب', '${_students.length}', Theme.of(context).colorScheme.primary),
              _buildStatChip('إيجابي', '$positiveCount', semantic.success),
              _buildStatChip('سلبي', '$negativeCount', Theme.of(context).colorScheme.error),
              _buildStatChip(
                'المجموع',
                Helpers.formatNumber(totalPoints),
                totalPoints >= 0 ? semantic.success : Theme.of(context).colorScheme.error,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildViolationsAlert() {
    return InkWell(
      onTap: _navigateToViolations,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'مخالفات قائمة',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  Text(
                    'يوجد $_unresolvedViolationsCount مخالفة تحتاج متابعة',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: const InputDecoration(
                hintText: 'بحث عن طالب',
                prefixIcon: Icon(Icons.search, size: 19),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'تصفية القائمة',
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('الكل')),
              PopupMenuItem(value: 'positive', child: Text('إيجابي')),
              PopupMenuItem(value: 'negative', child: Text('سلبي')),
              PopupMenuItem(value: 'violations', child: Text('مخالفات قائمة')),
            ],
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tune, size: 18),
                  const SizedBox(width: 5),
                  Text(
                    switch (_filter) {
                      'positive' => 'إيجابي',
                      'negative' => 'سلبي',
                      'violations' => 'مخالفات',
                      _ => 'الكل',
                    },
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('لا يوجد طلاب', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 90),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final studentData = _filteredStudents[index];
          return _buildStudentCard(studentData, index + 1);
        },
      ),
    );
  }

  Widget _buildStudentCard(StudentWithPoints studentData, int rank) {
    final student = studentData.student;
    final points = studentData.totalPoints;
    final scheme = Theme.of(context).colorScheme;
    final semantic = AppSemanticColors.of(context);
    final pointColor = points >= 0 ? semantic.success : scheme.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _navigateToHistory(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank <= 3
                      ? _getRankColor(rank).withValues(alpha: 0.13)
                      : scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$rank',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: rank <= 3 ? _getRankColor(rank) : scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        student.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    if (studentData.hasUnresolvedViolations) ...[
                      const SizedBox(width: 5),
                      Icon(Icons.warning_amber_rounded, size: 16, color: semantic.warning),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 52),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: pointColor.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${points > 0 ? '+' : ''}${Helpers.formatNumber(points)}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pointColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline, size: 20),
                onPressed: () => _navigateToAddPoint(student),
                tooltip: 'إسناد نقاط',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  void _navigateToAddPoint(Student? student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddPointScreen(student: student)),
    );
    if (result == true) _loadData();
  }

  void _navigateToHistory(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PointsHistoryScreen(student: student)),
    );
  }

  void _navigateToViolations() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AppearanceViolationsScreen()),
    );
    if (result == true) _loadData();
  }
}

class StudentWithPoints {
  final Student student;
  final double totalPoints;
  final bool hasUnresolvedViolations;

  StudentWithPoints({
    required this.student,
    required this.totalPoints,
    required this.hasUnresolvedViolations,
  });
}
