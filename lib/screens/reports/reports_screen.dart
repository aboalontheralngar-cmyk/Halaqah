import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../utils/helpers.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  List<Student> _students = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents();
      setState(() {
        _students = students;
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
        title: const Text('التقارير'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildReportTypeSection(),
                const SizedBox(height: 24),
                _buildStudentReportsSection(),
              ],
            ),
    );
  }

  Widget _buildReportTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'أنواع التقارير',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildReportCard(
              'تقرير يومي',
              Icons.today,
              Colors.blue,
              () => _generateDailyReport(),
            ),
            _buildReportCard(
              'تقرير أسبوعي',
              Icons.date_range,
              Colors.green,
              () => _generateWeeklyReport(),
            ),
            _buildReportCard(
              'تقرير شهري',
              Icons.calendar_month,
              Colors.orange,
              () => _generateMonthlyReport(),
            ),
            _buildReportCard(
              'إحصائيات الحلقة',
              Icons.analytics,
              Colors.purple,
              () => _showHalaqahStats(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تقارير الطلاب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (_students.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا يوجد طلاب')),
            ),
          )
        else
          ..._students.map((student) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      student.name.isNotEmpty ? student.name[0] : '؟',
                      style: TextStyle(
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  title: Text(student.name),
                  subtitle: Text('الحفظ: ${student.totalMemorized} آية'),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleStudentReport(student, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'full',
                        child: Text('تقرير شامل'),
                      ),
                      const PopupMenuItem(
                        value: 'receipt',
                        child: Text('سند استلام'),
                      ),
                      const PopupMenuItem(
                        value: 'attendance',
                        child: Text('تقرير الحضور'),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  void _generateDailyReport() {
    _showReportPreview('التقرير اليومي', _buildDailyReportContent(), _printDailyReport);
  }

  void _generateWeeklyReport() {
    _showReportPreview('التقرير الأسبوعي', _buildWeeklyReportContent(), _printWeeklyReport);
  }

  void _generateMonthlyReport() {
    _showReportPreview('التقرير الشهري', _buildMonthlyReportContent(), _printMonthlyReport);
  }

  void _showHalaqahStats() async {
    int totalStudents = _students.length;
    int activeStudents = _students.where((s) => s.status == 'active').length;
    int totalMemorized = _students.fold(0, (sum, s) => sum + s.totalMemorized);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إحصائيات الحلقة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow('إجمالي الطلاب', '$totalStudents'),
            _buildStatRow('الطلاب النشطين', '$activeStudents'),
            _buildStatRow('إجمالي الحفظ', '$totalMemorized آية'),
            _buildStatRow(
              'متوسط الحفظ',
              '${totalStudents > 0 ? (totalMemorized / totalStudents).round() : 0} آية/طالب',
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _handleStudentReport(Student student, String type) {
    switch (type) {
      case 'full':
        _showStudentFullReport(student);
        break;
      case 'receipt':
        _showStudentReceipt(student);
        break;
      case 'attendance':
        _showStudentAttendanceReport(student);
        break;
    }
  }

  void _showStudentFullReport(Student student) async {
    final stats = await _db.getStudentStatistics(student.id);
    final attendance = stats['attendance'] as Map<String, dynamic>? ?? {};

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقرير ${student.name}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatRow('الحفظ الكلي', '${student.totalMemorized} آية'),
              _buildStatRow('المقرر اليومي', '${student.planAmount} ${_getPlanLabel(student.planType)}'),
              _buildStatRow('أيام الحضور', '${attendance['present'] ?? 0}'),
              _buildStatRow('أيام الغياب', '${attendance['absent'] ?? 0}'),
              _buildStatRow('أيام التأخير', '${attendance['late'] ?? 0}'),
              const Divider(),
              const Text(
                'تعتمد صحة هذا التقرير على البيانات المدخلة',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _printStudentReport(student);
            },
            child: const Text('طباعة'),
          ),
        ],
      ),
    );
  }

  void _showStudentReceipt(Student student) async {
    final stats = await _db.getStudentStatistics(student.id);
    final points = await _db.getStudentTotalPoints(student.id);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سند استلام'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  student.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(),
              Text('التاريخ: ${Helpers.getFullHijriDate(DateTime.now())}'),
              const SizedBox(height: 8),
              _buildStatRow('الحفظ الكلي', '${student.totalMemorized} آية'),
              _buildStatRow('أيام الحضور', '${stats['presentDays'] ?? 0}'),
              _buildStatRow('أيام الغياب', '${stats['absentDays'] ?? 0}'),
              _buildStatRow('النقاط', '$points'),
              const Divider(),
              const Text(
                'توقيع ولي الأمر: _________________',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 16),
              const Text(
                'تعتمد صحة هذا التقرير على البيانات المدخلة',
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _printStudentReceipt(student);
            },
            child: const Text('طباعة'),
          ),
        ],
      ),
    );
  }

  void _showStudentAttendanceReport(Student student) async {
    final records = await _db.getStudentRecords(student.id, limit: 30);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حضور ${student.name}'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: records.isEmpty
              ? const Center(child: Text('لا يوجد سجلات'))
              : ListView.builder(
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final record = records[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        _getAttendanceIcon(record.attendance),
                        color: _getAttendanceColor(record.attendance),
                      ),
                      title: Text(Helpers.formatHijriDate(record.date)),
                      trailing: Text(_getAttendanceLabel(record.attendance)),
                    );
                  },
                ),
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

  void _showReportPreview(String title, Widget content, Future<void> Function() onPrint) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onPrint();
            },
            child: const Text('طباعة'),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('التاريخ: ${Helpers.getFullHijriDate(DateTime.now())}'),
        const Divider(),
        _buildStatRow('عدد الطلاب', '${_students.length}'),
        const Text(
          '\nتعتمد صحة هذا التقرير على البيانات المدخلة',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildWeeklyReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('الأسبوع المنتهي في: ${Helpers.getFullHijriDate(DateTime.now())}'),
        const Divider(),
        _buildStatRow('عدد الطلاب', '${_students.length}'),
        const Text(
          '\nتعتمد صحة هذا التقرير على البيانات المدخلة',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildMonthlyReportContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('الشهر: ${Helpers.getHijriMonthName(DateTime.now().month)}'),
        const Divider(),
        _buildStatRow('عدد الطلاب', '${_students.length}'),
        _buildStatRow(
          'إجمالي الحفظ',
          '${_students.fold(0, (sum, s) => sum + s.totalMemorized)} آية',
        ),
        const Text(
          '\nتعتمد صحة هذا التقرير على البيانات المدخلة',
          style: TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs': return 'آية';
      case 'lines': return 'سطر';
      case 'pages': return 'صفحة';
      default: return '';
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

  Color _getAttendanceColor(String status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      default: return Colors.grey;
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

  Future<void> _printStudentReport(Student student) async {
    try {
      final records = await _db.getStudentRecords(student.id, limit: 30);
      final points = await _db.getStudentTotalPoints(student.id);
      
      final data = {
        'records': records,
        'points': points,
      };
      
      final pdfBytes = await _pdf.generateStudentFullReport(student, data, 'حلقتي');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printStudentReceipt(Student student) async {
    try {
      final stats = await _db.getStudentStatistics(student.id);
      final qrData = student.qrCode;
      final pdfBytes = await _pdf.generateStudentReceipt(student, stats, 'حلقتي', 'المسجد', qrData);
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printDailyReport() async {
    try {
      final records = await _db.getDailyRecordsForDate(DateTime.now());
      final pdfBytes = await _pdf.generateDailyReport(DateTime.now(), records, _students, 'حلقتي');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printWeeklyReport() async {
    try {
      final startDate = DateTime.now().subtract(const Duration(days: 7));
      final weeklyRecords = <String, List<DailyRecord>>{};
      for (final student in _students) {
        final records = await _db.getStudentRecords(student.id, limit: 7);
        weeklyRecords[student.id] = records;
      }
      final pdfBytes = await _pdf.generateWeeklyReport(startDate, _students, weeklyRecords, 'حلقتي');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _printMonthlyReport() async {
    try {
      final stats = <String, dynamic>{
        'totalStudents': _students.length,
        'totalMemorized': _students.fold(0, (sum, s) => sum + s.totalMemorized),
      };
      final pdfBytes = await _pdf.generateMonthlyReport(DateTime.now(), _students, stats, 'حلقتي');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الطباعة: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
