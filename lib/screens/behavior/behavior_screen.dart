import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
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
  int _unresolvedViolationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final studentsWithPoints = <StudentWithPoints>[];
      int unresolvedCount = 0;

      for (final student in students) {
        final points = await _db.getStudentTotalPoints(student.id);
        final unresolved = await _db.getUnresolvedViolations(student.id);
        unresolvedCount += unresolved.length;

        studentsWithPoints.add(StudentWithPoints(
          student: student,
          totalPoints: points,
          hasUnresolvedViolations: unresolved.isNotEmpty,
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
    if (_filter == 'all') return _students;
    if (_filter == 'positive') {
      return _students.where((s) => s.totalPoints > 0).toList();
    }
    if (_filter == 'negative') {
      return _students.where((s) => s.totalPoints < 0).toList();
    }
    if (_filter == 'violations') {
      return _students.where((s) => s.hasUnresolvedViolations).toList();
    }
    return _students;
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
    final totalPoints = _students.fold<int>(0, (sum, s) => sum + s.totalPoints);

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip('إجمالي الطلاب', '${_students.length}', Colors.blue),
          _buildStatChip('إيجابي', '$positiveCount', Colors.green),
          _buildStatChip('سلبي', '$negativeCount', Colors.red),
          _buildStatChip('المجموع', '$totalPoints', totalPoints >= 0 ? Colors.green : Colors.red),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
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
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.emoji_events, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('لا يوجد طلاب', style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
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
    final isPositive = points >= 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToHistory(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (rank <= 3)
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _getRankColor(rank),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$rank',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  radius: 15,
                  backgroundColor: Colors.grey.withOpacity(0.1),
                  child: Text(
                    '$rank',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '؟',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (studentData.hasUnresolvedViolations) ...[
                          const SizedBox(width: 8),
                          Icon(Icons.warning, size: 16, color: Colors.orange[700]),
                        ],
                      ],
                    ),
                    Text(
                      'الحفظ: ${student.totalMemorized} آية',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: (isPositive ? Colors.green : Colors.red).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${isPositive ? '+' : ''}$points',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _navigateToAddPoint(student),
                tooltip: 'إضافة نقاط',
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
  final int totalPoints;
  final bool hasUnresolvedViolations;

  StudentWithPoints({
    required this.student,
    required this.totalPoints,
    required this.hasUnresolvedViolations,
  });
}
