import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../utils/helpers.dart';
import 'add_memorization_screen.dart';
import 'revision_screen.dart';
import 'student_memorization_view.dart';
import 'memorization_plan_screen.dart';
import 'recitation_screen.dart';

class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key});

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;
  List<Student> _students = [];
  Map<String, DailyRecord> _todayRecords = {};
  bool _isLoading = true;
  String _filter = 'all';
  String _sortBy = 'name';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final records = await _db.getDailyRecordsForDate(DateTime.now());

      final recordsMap = <String, DailyRecord>{};
      for (final record in records) {
        recordsMap[record.studentId] = record;
      }

      setState(() {
        _students = students;
        _todayRecords = recordsMap;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<Student> get _filteredStudents {
    List<Student> list;
    if (_filter == 'all') {
      list = List<Student>.from(_students);
    } else {
      list = _students.where((student) {
        final record = _todayRecords[student.id];
        if (_filter == 'completed') {
          return record?.memorizationDone == true;
        } else {
          return record?.memorizationDone != true;
        }
      }).toList();
    }

    if (_sortBy == 'name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'memorized') {
      list.sort((a, b) => b.totalMemorized.compareTo(a.totalMemorized));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ والمراجعة'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'الحفظ الجديد', icon: Icon(Icons.menu_book)),
            Tab(text: 'المراجعة', icon: Icon(Icons.replay)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemorizationPlanScreen()),
              );
            },
            tooltip: 'خطة الحفظ',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'ترتيب الطلاب',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: _sortBy == 'name' ? Theme.of(context).primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('ترتيب أبجدي (الاسم)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'memorized',
                child: Row(
                  children: [
                    Icon(Icons.star, color: _sortBy == 'memorized' ? Theme.of(context).primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('ترتيب حسب المحفوظ'),
                  ],
                ),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filter = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'completed', child: Text('مكتمل')),
              const PopupMenuItem(value: 'pending', child: Text('غير مكتمل')),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildDateHeader(),
            _buildStatsBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMemorizationTab(),
                  _buildRevisionTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddMemorization(null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, color: Theme.of(context).primaryColor),
          const SizedBox(width: 12),
          Text(
            Helpers.getFullHijriDate(DateTime.now()),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    int completed = 0;
    int pending = 0;
    for (final student in _students) {
      final record = _todayRecords[student.id];
      if (record?.memorizationDone == true) {
        completed++;
      } else {
        pending++;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatChip('إجمالي', '${_students.length}', Colors.blue),
          _buildStatChip('مكتمل', '$completed', Colors.green),
          _buildStatChip('متبقي', '$pending', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMemorizationTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredStudents.isEmpty) {
      return _buildEmptyState('لا يوجد طلاب');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          final record = _todayRecords[student.id];
          return _buildStudentMemorizationCard(student, record);
        },
      ),
    );
  }

  Widget _buildRevisionTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_students.isEmpty) {
      return _buildEmptyState('لا يوجد طلاب');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];
          final record = _todayRecords[student.id];
          return _buildStudentRevisionCard(student, record);
        },
      ),
    );
  }

  Widget _buildStudentMemorizationCard(Student student, DailyRecord? record) {
    final isDone = record?.memorizationDone == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToAddMemorization(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                    Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.pending,
                      size: 16,
                      color: isDone ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone ? 'مكتمل' : 'متبقي',
                      style: TextStyle(
                        color: isDone ? Colors.green : Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.mic),
                onPressed: () => _navigateToRecitation(student),
                tooltip: 'تسميع',
              ),
              IconButton(
                icon: const Icon(Icons.visibility),
                onPressed: () => _navigateToStudentView(student),
                tooltip: 'عرض المحفوظات',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentRevisionCard(Student student, DailyRecord? record) {
    final isDone = record?.revisionDone == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToRevision(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
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
                    Text(
                      student.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي الحفظ: ${student.totalMemorized} آية',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDone ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDone ? Icons.check_circle : Icons.replay,
                      size: 16,
                      color: isDone ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDone ? 'تمت' : 'مراجعة',
                      style: TextStyle(
                        color: isDone ? Colors.green : Colors.grey[700],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  void _navigateToAddMemorization(Student? student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemorizationScreen(student: student),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToRevision(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RevisionScreen(student: student),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToStudentView(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentMemorizationView(student: student),
      ),
    );
  }

  void _navigateToRecitation(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationScreen(student: student),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return planType;
    }
  }
}
