import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/behavior_point.dart';
import '../../models/student.dart';
import '../../models/student_period_report.dart';
import '../../models/vacation.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/quran_service.dart';
import '../../services/student_period_report_service.dart';

class StudentPeriodReportScreen extends StatefulWidget {
  final Student? initialStudent;
  final String initialPeriod;

  const StudentPeriodReportScreen({
    super.key,
    this.initialStudent,
    this.initialPeriod = 'month',
  });

  @override
  State<StudentPeriodReportScreen> createState() =>
      _StudentPeriodReportScreenState();
}

class _StudentPeriodReportScreenState extends State<StudentPeriodReportScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  late final StudentPeriodReportService _reports;

  List<Student> _students = [];
  Student? _student;
  late DateTime _startDate;
  late DateTime _endDate;
  StudentPeriodReport? _report;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _reports = StudentPeriodReportService(database: _db);
    _setInitialPeriod();
    _loadStudents();
  }

  void _setInitialPeriod() {
    final today = _dateOnly(DateTime.now());
    _endDate = today;
    if (widget.initialPeriod == 'week') {
      _startDate = today.subtract(const Duration(days: 6));
    } else {
      _startDate = DateTime(today.year, today.month, 1);
    }
  }

  Future<void> _loadStudents() async {
    final students = await _db.getStudents();
    Student? selected;
    if (widget.initialStudent != null) {
      for (final student in students) {
        if (student.id == widget.initialStudent!.id) {
          selected = student;
          break;
        }
      }
    }
    if (selected == null && students.isNotEmpty) selected = students.first;
    if (!mounted) return;
    setState(() {
      _students = students;
      _student = selected;
      _isLoading = false;
    });
    if (selected != null) await _generate();
  }

  Future<void> _generate() async {
    final student = _student;
    if (student == null) return;
    setState(() => _isLoading = true);
    try {
      final report = await _reports.generate(
        student: student,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء التقرير: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقرير الطالب لفترة محددة')),
      body: _students.isEmpty && !_isLoading
          ? const Center(child: Text('لا يوجد طلاب لإنشاء تقرير'))
          : RefreshIndicator(
              onRefresh: _generate,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilters(),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_report != null) ...[
                    _buildSummary(_report!),
                    const SizedBox(height: 16),
                    _buildPerformance(_report!),
                    const SizedBox(height: 16),
                    _buildDailyDetails(_report!),
                    const SizedBox(height: 16),
                    _buildActions(_report!),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات التقرير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Student>(
              value: _student,
              decoration: const InputDecoration(
                labelText: 'الطالب',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
              items: _students
                  .map((student) => DropdownMenuItem(
                        value: student,
                        child: Text(student.name),
                      ))
                  .toList(),
              onChanged: (student) {
                setState(() {
                  _student = student;
                  _report = null;
                });
                _generate();
              },
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.view_week_outlined, size: 18),
                  label: const Text('آخر 7 أيام'),
                  onPressed: () {
                    final today = _dateOnly(DateTime.now());
                    setState(() {
                      _startDate = today.subtract(const Duration(days: 6));
                      _endDate = today;
                    });
                    _generate();
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('الشهر الحالي'),
                  onPressed: () {
                    final today = _dateOnly(DateTime.now());
                    setState(() {
                      _startDate = DateTime(today.year, today.month, 1);
                      _endDate = today;
                    });
                    _generate();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickRange,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'الفترة المخصصة',
                  prefixIcon: Icon(Icons.date_range),
                  border: OutlineInputBorder(),
                ),
                child: Text('من ${_formatDate(_startDate)} إلى ${_formatDate(_endDate)}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(StudentPeriodReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ملخص ${report.student.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 3),
            SelectableText(
              'كود الطالب: ${report.student.displayCode}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${_formatDate(report.startDate)} — ${_formatDate(report.endDate)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: [
                _statTile('الحفظ', '${report.memorizedAyahs} آية', Colors.green),
                _statTile('المراجعة', '${report.revisedAyahs} آية', Colors.blue),
                _statTile('الصفحات', report.memorizedPages.toStringAsFixed(1), Colors.purple),
                _statTile('الأجزاء', report.memorizedJuz.toStringAsFixed(2), Colors.indigo),
                _statTile('الحضور', '${report.attendanceRate}%', Colors.teal),
                _statTile('لم يسمّع', '${report.noRecitationDays} يوم', Colors.orange),
                _statTile('الإيجابيات', '+${report.positivePoints}', Colors.green),
                _statTile('السلبيات', '-${report.negativePoints}', Colors.red),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                Text('حاضر: ${report.presentDays}'),
                Text('متأخر: ${report.lateDays}'),
                Text('غائب: ${report.absentDays}'),
                Text('مستأذن: ${report.excusedDays}'),
                Text('متوسط الجودة: ${report.averageQuality.toStringAsFixed(1)}/5'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildPerformance(StudentPeriodReport report) {
    final color = report.performanceScore >= 80
        ? Colors.green
        : report.performanceScore >= 60
            ? Colors.orange
            : Colors.red;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الأداء العام خلال الفترة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: report.performanceScore / 100,
                      minHeight: 14,
                      color: color,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text('${report.performanceScore}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'المؤشر يجمع المواظبة والتسميع والمراجعة والجودة والنقاط اليومية.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyDetails(StudentPeriodReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            const ListTile(
              leading: Icon(Icons.view_timeline_outlined),
              title: Text('تفاصيل الأيام', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('اضغط على اليوم لعرض الحفظ والمراجعة والملاحظات'),
            ),
            ...report.days.map(_buildDayTile),
          ],
        ),
      ),
    );
  }

  Widget _buildDayTile(StudentPeriodDay day) {
    final status = _attendanceLabel(day);
    final color = _attendanceColor(day);
    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.12),
        child: Icon(_attendanceIcon(day), color: color, size: 20),
      ),
      title: Text(_formatDate(day.date)),
      subtitle: Text(status),
      trailing: day.isRecitationRequiredDay && day.record != null
          ? Text('${day.performanceScore}%')
          : null,
      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      children: [
        _detailRow('الحفظ', _progressText(day.memorization)),
        _detailRow('المراجعة', _progressText(day.revision)),
        _detailRow('النقاط', '+${day.positivePoints} / -${day.negativePoints}'),
        if (_dayNote(day).isNotEmpty) _detailRow('الملاحظات', _dayNote(day)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 75, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildActions(StudentPeriodReport report) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _shareWhatsApp(report),
            icon: const Icon(Icons.share_outlined),
            label: const Text('مشاركة قالب WhatsApp'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _print(report, PdfPageFormat.a4),
                icon: const Icon(Icons.print),
                label: const Text('طباعة A4'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _print(report, PdfPageFormat.a5),
                icon: const Icon(Icons.print_outlined),
                label: const Text('طباعة A5'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'اختر فترة التقرير',
      saveText: 'اعتماد الفترة',
    );
    if (range == null) return;
    setState(() {
      _startDate = _dateOnly(range.start);
      _endDate = _dateOnly(range.end);
    });
    await _generate();
  }

  Future<void> _print(StudentPeriodReport report, PdfPageFormat format) async {
    final settings = await _db.getSettings();
    final bytes = await _pdf.generateStudentPeriodReport(
      report: report,
      pageFormat: format,
      halaqahName: settings.halaqahName,
      mosqueName: settings.mosqueName,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareWhatsApp(StudentPeriodReport report) async {
    final text = _whatsAppText(report);
    await Share.share(text, subject: 'تقرير ${report.student.name}');
  }

  String _whatsAppText(StudentPeriodReport report) {
    final buffer = StringBuffer()
      ..writeln('🕌 *تقرير الطالب خلال الفترة*')
      ..writeln('👤 *${report.student.name}*')
      ..writeln('🪪 كود الطالب: ${report.student.displayCode}')
      ..writeln('📅 ${_formatDate(report.startDate)} — ${_formatDate(report.endDate)}')
      ..writeln()
      ..writeln('📖 *الحفظ والمراجعة*')
      ..writeln('✅ الحفظ الجديد: ${report.memorizedAyahs} آية (${report.memorizedPages.toStringAsFixed(1)} صفحة)')
      ..writeln('🔁 المراجعة: ${report.revisedAyahs} آية (${report.revisedPages.toStringAsFixed(1)} صفحة)')
      ..writeln('⭐ متوسط الجودة: ${report.averageQuality.toStringAsFixed(1)}/5')
      ..writeln()
      ..writeln('📅 *الحضور والمواظبة*')
      ..writeln('✅ حاضر: ${report.presentDays} | ⏰ متأخر: ${report.lateDays}')
      ..writeln('❌ غائب: ${report.absentDays} | 📝 مستأذن: ${report.excusedDays}')
      ..writeln('🔕 لم يسمّع وهو حاضر: ${report.noRecitationDays}')
      ..writeln('📊 نسبة الحضور: ${report.attendanceRate}%')
      ..writeln()
      ..writeln('🏆 إيجابيات: +${report.positivePoints} (${report.positiveEvents})')
      ..writeln('⚠️ سلبيات: -${report.negativePoints} (${report.negativeEvents})')
      ..writeln('📈 الأداء العام: ${report.performanceScore}%')
      ..writeln();

    final notes = report.days
        .where((day) =>
            day.isSuspended || day.vacation != null || day.hold != null)
        .map((day) => '• ${_formatDate(day.date)}: ${_dayNote(day)}')
        .where((line) => !line.endsWith(': '))
        .toList();
    if (notes.isNotEmpty) {
      buffer.writeln('🗒️ *ملاحظات الفترة*');
      for (final note in notes) {
        buffer.writeln(note);
      }
      buffer.writeln();
    }
    buffer.writeln(_encouragement(report.performanceScore));
    buffer.writeln('جزاكم الله خيرًا على المتابعة والتعاون 🌿');
    return buffer.toString();
  }

  String _progressText(List<dynamic> items) {
    if (items.isEmpty) return 'لا يوجد';
    return items.map((dynamic item) {
      final name = QuranService.instance.getSurahName(item.surahId as int);
      return 'سورة $name: ${item.fromAyah}–${item.toAyah}';
    }).join('، ');
  }

  String _dayNote(StudentPeriodDay day) {
    if (day.isSuspended) return day.suspensionReason ?? 'تعليق الدراسة';
    if (day.isWeeklyHoliday) return 'الإجازة الأسبوعية';
    if (day.hold != null) {
      final note = day.hold!.notes?.trim();
      return 'إيقاف التسميع: ${day.hold!.reason}'
          '${note == null || note.isEmpty ? '' : ' — $note'}';
    }
    if (day.vacation != null) {
      final vacation = day.vacation!;
      final note = vacation.notes?.trim();
      return '${VacationReason.getLabel(vacation.reason)}${note == null || note.isEmpty ? '' : ': $note'}';
    }
    final values = <String?>[
      day.record?.absenceNote,
      day.record?.memorizationNote,
      day.record?.revisionNote,
      day.record?.notes,
      ...day.points.map((point) => BehaviorReason.getLabel(point.reason)),
    ];
    return values
        .where((value) => value != null && value.trim().isNotEmpty)
        .cast<String>()
        .join('، ');
  }

  String _attendanceLabel(StudentPeriodDay day) {
    if (day.isSuspended) return 'الدراسة معلقة';
    if (day.isWeeklyHoliday) return 'إجازة أسبوعية';
    if (day.hold != null) return 'الحضور متاح — التسميع موقوف';
    switch (day.record?.attendance) {
      case 'present': return day.memorizationDone ? 'حاضر وسمّع' : 'حاضر ولم يسمّع';
      case 'late': return day.memorizationDone ? 'متأخر وسمّع' : 'متأخر ولم يسمّع';
      case 'absent': return 'غائب';
      case 'excused': return 'مستأذن';
      default: return 'لا يوجد سجل';
    }
  }

  Color _attendanceColor(StudentPeriodDay day) {
    if (day.isSuspended || day.isWeeklyHoliday) return Colors.blueGrey;
    if (day.hold != null) return Colors.deepOrange;
    switch (day.record?.attendance) {
      case 'present': return Colors.green;
      case 'late': return Colors.orange;
      case 'absent': return Colors.red;
      case 'excused': return Colors.blue;
      default: return Colors.grey;
    }
  }

  IconData _attendanceIcon(StudentPeriodDay day) {
    if (day.isSuspended) return Icons.pause_circle_outline;
    if (day.isWeeklyHoliday) return Icons.weekend_outlined;
    if (day.hold != null) return Icons.gavel_outlined;
    switch (day.record?.attendance) {
      case 'present': return Icons.check_circle_outline;
      case 'late': return Icons.schedule;
      case 'absent': return Icons.cancel_outlined;
      case 'excused': return Icons.info_outline;
      default: return Icons.remove_circle_outline;
    }
  }

  String _encouragement(int score) {
    if (score >= 85) return '🌟 أداء متميز، بارك الله فيه وزاده ثباتًا وتوفيقًا.';
    if (score >= 65) return '👍 أداء جيد، ومع مزيد من المواظبة سيصل إلى مستوى أجمل بإذن الله.';
    return '🤝 نأمل زيادة المواظبة والتسميع، ونسعد بتعاونكم في رفع مستواه.';
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}
