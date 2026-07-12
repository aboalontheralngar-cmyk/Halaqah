import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/database_service.dart';
import '../../services/qr_service.dart';
import '../../services/quran_service.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../models/behavior_point.dart';
import '../../models/settings.dart';
import '../../models/homework_grade.dart';
import '../../models/student_hold.dart';
import '../../utils/helpers.dart';
import '../../utils/quran_data.dart';
import '../memorization/mushaf_visualizer_screen.dart';
import '../memorization/recitation_history_screen.dart';
import 'student_form_screen.dart';
import '../behavior/add_point_screen.dart';

class StudentDetailScreen extends StatefulWidget {
  final Student student;

  const StudentDetailScreen({super.key, required this.student});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;
  late Student _student;
  
  List<DailyRecord> _records = [];
  List<BehaviorPoint> _behaviorPoints = [];
  List<HomeworkGrade> _homeworkGrades = [];
  int _totalPoints = 0;
  Map<String, dynamic> _stats = {};
  int _uniquePagesCount = 0;
  int _uniqueAyahsCount = 0;
  HalaqahSettings _settings = HalaqahSettings();
  StudentHold? _activeHold;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _student = widget.student;
    _tabController = TabController(length: 4, vsync: this);
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
      final records = await _db.getStudentRecords(_student.id);
      final points = await _db.getStudentBehaviorPoints(_student.id);
      final totalPoints = await _db.getStudentTotalPoints(_student.id);
      final stats = await _db.getStudentStatistics(_student.id);
      final grades = await _db.getStudentHomeworkGrades(_student.id);
      final settings = await _db.getSettings();
      final activeHold = await _db.getActiveStudentHold(_student.id);
      
      await QuranService.instance.initialize();
      
      final uniquePages = <int>{};
      final uniqueAyahs = <String>{};
      
      for (final grade in grades) {
        if (grade.gradeMark == 'absent') continue;
        final range = QuranService.instance.getAyahRange(grade.surahId, grade.fromAyah, grade.toAyah);
        for (final ayah in range) {
          uniquePages.add(ayah.page);
          uniqueAyahs.add('${grade.surahId}_${ayah.number}');
        }
      }
      
      final updatedStudent = await _db.getStudent(_student.id);
      
      setState(() {
        if (updatedStudent != null) _student = updatedStudent;
        _records = records;
        _behaviorPoints = points;
        _homeworkGrades = grades;
        _totalPoints = totalPoints;
        _stats = stats;
        _uniquePagesCount = uniquePages.length;
        _uniqueAyahsCount = uniqueAyahs.length;
        _settings = settings;
        _activeHold = activeHold;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_student.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _editStudent,
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'qr',
                child: Row(
                  children: [
                    Icon(Icons.qr_code),
                    SizedBox(width: 8),
                    Text('عرض QR Code'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'recitation_history',
                child: const Row(
                  children: [
                    Icon(Icons.history),
                    SizedBox(width: 8),
                    Text('سجل التسميع والتعديل'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _activeHold == null ? 'hold' : 'end_hold',
                child: Row(
                  children: [
                    Icon(
                      _activeHold == null
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _activeHold == null
                          ? 'إيقاف التسميع مؤقتًا'
                          : 'إنهاء إيقاف التسميع',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const {'expelled', 'graduated', 'inactive'}
                        .contains(_student.status)
                    ? 'restore_student'
                    : 'archive_student',
                child: Row(
                  children: [
                    Icon(
                      const {'expelled', 'graduated', 'inactive'}
                              .contains(_student.status)
                          ? Icons.restore
                          : Icons.inventory_2_outlined,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      const {'expelled', 'graduated', 'inactive'}
                              .contains(_student.status)
                          ? 'إعادة تفعيل الطالب'
                          : 'نقل الطالب إلى الأرشيف',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'نظرة عامة'),
            Tab(text: 'الحضور'),
            Tab(text: 'الحفظ'),
            Tab(text: 'النقاط'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildAttendanceTab(),
                _buildMemorizationTab(),
                _buildPointsTab(),
              ],
            ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildProfileCard(),
          const SizedBox(height: 16),
          _buildStatsGrid(),
          const SizedBox(height: 16),
          _buildInfoCard(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                _student.name.isNotEmpty ? _student.name[0] : '؟',
                style: TextStyle(
                  fontSize: 40,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _student.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(_student.status).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getStatusLabel(_student.status),
                style: TextStyle(
                  color: _getStatusColor(_student.status),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_activeHold != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  border: Border.all(color: Colors.orange.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.pause_circle, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'التسميع موقوف مؤقتًا',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('السبب: ${_activeHold!.reason}'),
                    Text(
                      'حتى: ${Helpers.getFullHijriDate(_activeHold!.endDate)}',
                    ),
                    if (_activeHold!.notes?.isNotEmpty ?? false)
                      Text('ملاحظة: ${_activeHold!.notes}'),
                    const SizedBox(height: 4),
                    const Text(
                      'يبقى تسجيل الحضور متاحًا خلال الإيقاف.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _openMushafMap,
                icon: const Icon(Icons.grid_view_rounded),
                label: const Text('فتح خريطة الأحزاب والأثمان'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildStatChip(
                  'النقاط',
                  '$_totalPoints',
                  _totalPoints >= 0 ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 16),
                _buildStatChip(
                  'الحفظ',
                  '${_student.totalMemorized} آية',
                  Colors.blue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    final attendance = _stats['attendance'] as Map<String, dynamic>? ?? {};
    final totalDays = (attendance['total'] as int?) ?? 0;
    final presentDays = (attendance['present'] as int?) ?? 0;
    final attendanceRate = totalDays > 0 ? (presentDays / totalDays * 100).round() : 0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard('نسبة الحضور', '$attendanceRate%', Icons.calendar_today, Colors.green),
        _buildStatCard('أيام الحضور', '$presentDays', Icons.check_circle, Colors.blue),
        _buildStatCard('المقرر', '${_student.planAmount} ${_getPlanLabel(_student.planType)}', Icons.book, Colors.orange),
        _buildStatCard('النقاط', '$_totalPoints', Icons.stars, _totalPoints >= 0 ? Colors.amber : Colors.red),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'معلومات ${GenderHelper.student(_settings.gender)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(),
            _buildInfoRow('رقم الجوال', _student.phone.isEmpty ? 'غير محدد' : _student.phone),
            _buildInfoRow('رقم ولي الأمر', _student.guardianPhone.isEmpty ? 'غير محدد' : _student.guardianPhone),
            _buildInfoRow('تاريخ الانضمام', Helpers.getFullHijriDate(_student.joinDate)),
            if (_student.notes?.isNotEmpty ?? false)
              _buildInfoRow('ملاحظات', _student.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    if (_records.isEmpty) {
      return const Center(
        child: Text('لا يوجد سجلات حضور'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final record = _records[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getAttendanceColor(record.attendance).withOpacity(0.1),
              child: Icon(
                _getAttendanceIcon(record.attendance),
                color: _getAttendanceColor(record.attendance),
              ),
            ),
            title: Text(Helpers.getFullHijriDate(record.date)),
            subtitle: Row(
              children: [
                Text(_getAttendanceLabel(record.attendance)),
                if (record.memorizationDone) ...[
                  const SizedBox(width: 8),
                  const Chip(
                    label: Text('حفظ', style: TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
                if (record.revisionDone) ...[
                  const SizedBox(width: 4),
                  const Chip(
                    label: Text('مراجعة', style: TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            trailing: record.arrivalTime != null
                ? Text(
                    Helpers.formatTime(record.arrivalTime!, format: _settings.timeFormat, context: context),
                    style: TextStyle(color: Colors.grey[600]),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildMemorizationTab() {
    return FutureBuilder<List<int>>(
      future: _db.getMemorizedSurahs(_student.id),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final memorizedSurahs = snapshot.data!;
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${_student.totalMemorized}',
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text('آية محفوظة'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _student.totalMemorized / QuranData.totalAyahs,
                      backgroundColor: Colors.grey[200],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${(_student.totalMemorized / QuranData.totalAyahs * 100).toStringAsFixed(1)}% من القرآن',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.menu_book, color: Colors.teal),
                          const SizedBox(height: 8),
                          Text(
                            '$_uniquePagesCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('صفحات فريدة', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Icon(Icons.format_list_numbered, color: Colors.blue),
                          const SizedBox(height: 8),
                          Text(
                            '$_uniqueAyahsCount',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('آيات منجزة', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'السور المحفوظة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (memorizedSurahs.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('لم يتم تسجيل حفظ بعد')),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: memorizedSurahs.map((surahId) {
                  return Chip(
                    label: Text(QuranData.getSurahName(surahId)),
                  );
                }).toList(),
              ),
            const SizedBox(height: 24),
            const Text(
              'سجل المحفوظات اليومي التفصيلي 🗓️',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_homeworkGrades.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('لا يوجد سجل محفوظات يومي')),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _homeworkGrades.length,
                itemBuilder: (context, index) {
                  final grade = _homeworkGrades[index];
                  final surahName = QuranData.getSurahName(grade.surahId);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                Helpers.getFullHijriDate(grade.date),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blue),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: grade.isRevision ? Colors.orange.shade50 : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: grade.isRevision ? Colors.orange.shade200 : Colors.teal.shade200),
                                ),
                                child: Text(
                                  grade.isRevision ? 'مراجعة' : 'حفظ جديد',
                                  style: TextStyle(
                                    color: grade.isRevision ? Colors.orange.shade800 : Colors.teal.shade800,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'سورة $surahName (الآيات من ${grade.fromAyah} إلى ${grade.toAyah})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.workspace_premium, size: 16, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                'التقييم: ${grade.gradeMarkArabic}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(width: 16),
                              const Icon(Icons.error_outline, size: 16, color: Colors.red),
                              const SizedBox(width: 4),
                              Text(
                                'الأخطاء: ${grade.mistakesCount}',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          if (grade.remark != null && grade.remark!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'توصية الشيخ: ${grade.remark}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildPointsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  '$_totalPoints',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: _totalPoints >= 0 ? Colors.green : Colors.red,
                  ),
                ),
                const Text('إجمالي النقاط'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'سجل النقاط',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: const {'active', 'suspended'}.contains(_student.status)
                  ? _addBehaviorPoint
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
            ),
          ],
        ),
        if (_behaviorPoints.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا يوجد سجل نقاط')),
            ),
          )
        else
          ..._behaviorPoints.map((point) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: point.isPositive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    child: Icon(
                      point.isPositive ? Icons.add : Icons.remove,
                      color: point.isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(BehaviorReason.getLabel(point.reason)),
                  subtitle: Text(Helpers.getFullHijriDate(point.date)),
                  trailing: Text(
                    '${point.points > 0 ? '+' : ''}${point.points}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: point.isPositive ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              )),
      ],
    );
  }

  void _editStudent() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(student: _student),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _openMushafMap() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MushafVisualizerScreen(student: _student),
      ),
    );
    if (mounted) await _loadData();
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'qr':
        _showQrCode();
        break;
      case 'hold':
        _showStudentHoldDialog();
        break;
      case 'recitation_history':
        _openRecitationHistory();
        break;
      case 'end_hold':
        _endActiveHold();
        break;
      case 'archive_student':
        _showArchiveStudentDialog();
        break;
      case 'restore_student':
        _showRestoreStudentDialog();
        break;
    }
  }

  Future<void> _openRecitationHistory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationHistoryScreen(
          initialStudent: _student,
        ),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _showStudentHoldDialog() async {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    var startDate = DateTime.now();
    var endDate = DateTime.now().add(const Duration(days: 1));
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إيقاف التسميع مؤقتًا'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سيظل الطالب ظاهرًا في الحضور، ويُمنع فقط من تسجيل الحفظ والمراجعة خلال المدة.',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'سبب الإيقاف (إلزامي)',
                    prefixIcon: Icon(Icons.gavel_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDateRange: DateTimeRange(
                        start: startDate,
                        end: endDate,
                      ),
                    );
                    if (range != null) {
                      setDialogState(() {
                        startDate = range.start;
                        endDate = range.end;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'مدة الإيقاف',
                      prefixIcon: Icon(Icons.date_range),
                    ),
                    child: Text(
                      '${Helpers.formatHijriDate(startDate)} — '
                      '${Helpers.formatHijriDate(endDate)}',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات إضافية',
                    prefixIcon: Icon(Icons.notes),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('اكتب سبب الإيقاف')),
                  );
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('اعتماد الإيقاف'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true) {
      try {
        await _db.saveStudentHold(StudentHold(
          studentId: _student.id,
          startDate: startDate,
          endDate: endDate,
          reason: reasonController.text.trim(),
          notes: notesController.text.trim().isEmpty
              ? null
              : notesController.text.trim(),
        ));
        await _loadData();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حفظ الإيقاف: $error')),
          );
        }
      }
    }
    reasonController.dispose();
    notesController.dispose();
  }

  Future<void> _endActiveHold() async {
    final hold = _activeHold;
    if (hold == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء الإيقاف؟'),
        content: const Text('سيتمكن الطالب من تسجيل الحفظ والمراجعة فورًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء الإيقاف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _db.endStudentHold(hold.id);
      await _loadData();
    }
  }

  void _showQrCode() {
    final qrData = QrService.generateQrData(_student.qrCode);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_student.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: qrData,
              size: 200,
            ),
            const SizedBox(height: 16),
            const Text(
              'امسح هذا الكود للتحضير السريع',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حذف ${GenderHelper.student(_settings.gender)}'),
        content: Text('هل أنت متأكد من حذف ${_student.name}؟\nسيتم حذف جميع بياناته.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              await _db.deleteStudent(_student.id);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _addBehaviorPoint() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AddPointScreen(student: _student)),
    );
    if (saved == true && mounted) await _loadData();
  }

  Future<void> _showArchiveStudentDialog() async {
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    var status = 'expelled';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('نقل ${_student.name} إلى الأرشيف'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'ستبقى جميع بيانات الطالب وتقاريره محفوظة، وسيختفي من الحضور والتسميع والقوائم اليومية.',
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: const InputDecoration(labelText: 'حالة الأرشفة'),
                  items: const [
                    DropdownMenuItem(value: 'expelled', child: Text('مفصول')),
                    DropdownMenuItem(value: 'graduated', child: Text('متخرج/خاتم')),
                    DropdownMenuItem(value: 'inactive', child: Text('طالب سابق')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'السبب (إلزامي)',
                    hintText: 'مثال: تجاوز حد الغياب بعد التواصل مع ولي الأمر',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات إضافية'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('تأكيد النقل'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    final notes = notesController.text.trim();
    reasonController.dispose();
    notesController.dispose();
    if (accepted != true || reason.isEmpty) return;
    await _db.changeStudentStatus(
      studentId: _student.id,
      newStatus: status,
      reason: reason,
      notes: notes,
    );
    if (!mounted) return;
    await _loadData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نقل الطالب إلى الأرشيف مع حفظ سجله')),
    );
  }

  Future<void> _showRestoreStudentDialog() async {
    final controller = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعادة تفعيل ${_student.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'سبب إعادة التفعيل (إلزامي)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('إعادة تفعيل'),
          ),
        ],
      ),
    );
    final reason = controller.text.trim();
    controller.dispose();
    if (accepted != true || reason.isEmpty) return;
    await _db.changeStudentStatus(
      studentId: _student.id,
      newStatus: 'active',
      reason: reason,
    );
    if (mounted) await _loadData();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active': return Colors.green;
      case 'suspended': return Colors.orange;
      case 'expelled': return Colors.red;
      case 'graduated': return Colors.blue;
      case 'inactive': return Colors.grey;
      default: return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active': return 'نشط';
      case 'suspended': return 'موقوف';
      case 'expelled': return 'مفصول';
      case 'graduated': return 'متخرج';
      case 'inactive': return 'سابق';
      default: return status;
    }
  }

  Color _getAttendanceColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getAttendanceIcon(String status) {
    switch (status) {
      case 'present': return Icons.check_circle;
      case 'late': return Icons.access_time;
      case 'absent': return Icons.cancel;
      default: return Icons.help;
    }
  }

  String _getAttendanceLabel(String status) {
    switch (status) {
      case 'present': return 'حاضر';
      case 'late': return 'متأخر';
      case 'absent': return 'غائب';
      default: return status;
    }
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs': return 'آية';
      case 'lines': return 'سطر';
      case 'pages': return 'صفحة';
      default: return '';
    }
  }
}
