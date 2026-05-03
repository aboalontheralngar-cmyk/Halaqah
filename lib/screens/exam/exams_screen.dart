import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/exam.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import 'add_exam_screen.dart';
import 'exam_result_screen.dart';
import 'exam_generator_screen.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  final DatabaseService _db = DatabaseService();
  List<ExamWithStudent> _exams = [];
  List<Student> _students = [];
  bool _isLoading = true;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final exams = <ExamWithStudent>[];

      for (final student in students) {
        final studentExams = await _db.getStudentExams(student.id);
        for (final exam in studentExams) {
          exams.add(ExamWithStudent(student: student, exam: exam));
        }
      }

      exams.sort((a, b) => b.exam.date.compareTo(a.exam.date));

      setState(() {
        _students = students;
        _exams = exams;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<ExamWithStudent> get _filteredExams {
    if (_selectedStudentId == null) return _exams;
    return _exams.where((e) => e.student.id == _selectedStudentId).toList();
  }

  double get _averageScore {
    if (_filteredExams.isEmpty) return 0;
    final total = _filteredExams.fold<int>(0, (sum, e) => sum + e.exam.score);
    return total / _filteredExams.length;
  }

  int get _highestScore {
    if (_filteredExams.isEmpty) return 0;
    return _filteredExams.map((e) => e.exam.score).reduce((a, b) => a > b ? a : b);
  }

  int get _lowestScore {
    if (_filteredExams.isEmpty) return 0;
    return _filteredExams.map((e) => e.exam.score).reduce((a, b) => a < b ? a : b);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الامتحانات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ExamGeneratorScreen()),
              );
            },
            tooltip: 'مولد نماذج الاختبارات',
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _selectedStudentId = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: null, child: Text('جميع الطلاب')),
              const PopupMenuDivider(),
              ..._students.map((s) => PopupMenuItem(
                    value: s.id,
                    child: Text(s.name),
                  )),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatsSection(),
                Expanded(
                  child: _filteredExams.isEmpty
                      ? _buildEmptyState()
                      : _buildExamsList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddExam(),
        icon: const Icon(Icons.add),
        label: const Text('امتحان جديد'),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_selectedStudentId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _students.firstWhere((s) => s.id == _selectedStudentId).name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('عدد الامتحانات', '${_filteredExams.length}'),
              _buildStatItem('المتوسط', '${_averageScore.round()}%'),
              _buildStatItem('الأعلى', '$_highestScore%'),
              _buildStatItem('الأقل', '$_lowestScore%'),
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
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('لا توجد امتحانات', style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => _navigateToAddExam(),
            icon: const Icon(Icons.add),
            label: const Text('إنشاء امتحان'),
          ),
        ],
      ),
    );
  }

  Widget _buildExamsList() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredExams.length,
        itemBuilder: (context, index) {
          final data = _filteredExams[index];
          return _buildExamCard(data);
        },
      ),
    );
  }

  Widget _buildExamCard(ExamWithStudent data) {
    final fromSurah = QuranData.getSurahName(data.exam.fromSurah);
    final toSurah = QuranData.getSurahName(data.exam.toSurah);
    final scoreColor = _getScoreColor(data.exam.score);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToResult(data),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      data.student.name.isNotEmpty ? data.student.name[0] : '؟',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.student.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          Helpers.formatHijriDate(data.exam.date),
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: scoreColor.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${data.exam.score}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: scoreColor,
                            ),
                          ),
                          Text(
                            '%',
                            style: TextStyle(
                              fontSize: 10,
                              color: scoreColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.exam.type == 'oral' ? 'شفهي' : 'تحريري',
                      style: const TextStyle(fontSize: 12, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fromSurah == toSurah
                          ? 'سورة $fromSurah'
                          : 'من $fromSurah إلى $toSurah',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 75) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  void _navigateToAddExam() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddExamScreen()),
    );
    if (result == true) _loadData();
  }

  void _navigateToResult(ExamWithStudent data) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamResultScreen(
          exam: data.exam,
          student: data.student,
        ),
      ),
    );
  }
}

class ExamWithStudent {
  final Student student;
  final Exam exam;

  ExamWithStudent({required this.student, required this.exam});
}
