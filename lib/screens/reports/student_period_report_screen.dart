import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/behavior_point.dart';
import '../../models/daily_record.dart';
import '../../models/student.dart';
import '../../models/student_period_report.dart';
import '../../models/vacation.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/quran_service.dart';
import '../../services/qr_service.dart';
import '../../services/student_period_report_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_design_widgets.dart';
import '../../widgets/dual_calendar_date_picker.dart';

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
  String? _selectedHijriMonthKey;

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
      final candidates = _students
          .where((item) => item.status == 'active' || item.id == student.id)
          .toList();
      final rankedReports = await _reports.generateForStudents(
        students: candidates,
        startDate: _startDate,
        endDate: _endDate,
      );
      final report = rankedReports.firstWhere(
        (item) => item.student.id == student.id,
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
                    if (_report!.payments.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildPayments(_report!),
                    ],
                    if (_report!.exams.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildExams(_report!),
                    ],
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
    final hijriRanges = Helpers.recentHijriMonths();
    final hijriRangeByKey = {
      for (final range in hijriRanges) range.key: range,
    };
    final selectedHijriMonthKey =
        hijriRangeByKey.containsKey(_selectedHijriMonthKey)
            ? _selectedHijriMonthKey
            : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات التقرير', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Student>(
              initialValue: _student,
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
            DropdownButtonFormField<String>(
              initialValue: selectedHijriMonthKey,
              decoration: const InputDecoration(
                labelText: 'تقرير شهر هجري',
                prefixIcon: Icon(Icons.brightness_2_outlined),
                border: OutlineInputBorder(),
              ),
              hint: const Text('اختر محرم أو أي شهر هجري'),
              isExpanded: true,
              items: hijriRanges
                  .map(
                    (range) => DropdownMenuItem(
                      value: range.key,
                      child: Text(range.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (rangeKey) {
                final range = hijriRangeByKey[rangeKey];
                if (range == null) return;
                setState(() {
                  _selectedHijriMonthKey = range.key;
                  _startDate = range.startDate;
                  _endDate = range.endDate;
                });
                _generate();
              },
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                QrImageView(
                  data: QrService.generateQrData(report.student.qrCode),
                  size: 72,
                  padding: const EdgeInsets.all(4),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ملخص ${report.student.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
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
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                      if (report.rankLabel != null) ...[
                        const SizedBox(height: 5),
                        Chip(
                          avatar: const Icon(Icons.emoji_events_outlined, size: 17),
                          label: Text(report.rankLabel!),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
                _statTile('إجمالي الصفحات', report.totalCompletedPages.toStringAsFixed(1), Colors.purple),
                _statTile('صفحات حفظ', report.memorizedPages.toStringAsFixed(1), Colors.green),
                _statTile('صفحات مراجعة', report.revisedPages.toStringAsFixed(1), Colors.blue),
                _statTile('صفحات سرد', report.recitedPages.toStringAsFixed(1), Colors.indigo),
                _statTile('المدفوعات', report.paidAmount.toStringAsFixed(2), Colors.teal),
                _statTile('الأجزاء', report.memorizedJuz.toStringAsFixed(2), Colors.indigo),
                _statTile('الحضور', '${report.attendanceRate}%', Colors.teal),
                _statTile('لم يسمّع', '${report.noRecitationDays} يوم', Colors.orange),
                _statTile('الإيجابيات', '+${Helpers.formatNumber(report.positivePoints)}', Colors.green),
                _statTile('السلبيات', '-${Helpers.formatNumber(report.negativePoints)}', Colors.red),
                _statTile('المخالفات', '${report.violationEvents}', Colors.deepOrange),
                _statTile('متبقي سلبي', '-${report.outstandingNegativePoints}', Colors.red),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 14,
              runSpacing: 8,
              children: [
                Text('حاضر: ${report.presentDays}'),
                Text('متأخر: ${report.lateDays}'),
                Text('إجمالي التأخر: ${report.totalLateMinutes} دقيقة'),
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
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.35)),
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
            Text(
              'المؤشر يجمع المواظبة والتسميع والمراجعة والجودة والنقاط اليومية.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPayments(StudentPeriodReport report) {
    final payments = List.of(report.payments)
      ..sort((a, b) => b.date.compareTo(a.date));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, size: 20),
                const SizedBox(width: 7),
                const Expanded(
                  child: Text(
                    'مدفوعات الطالب خلال الفترة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  Helpers.formatNumber(report.paidAmount),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'تُجلب تلقائيًا من صندوق الحلقة ضمن نفس فترة التقرير.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 20),
            for (final payment in payments)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 17,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_fundTypeLabel(payment.type)} · ${_formatDate(payment.date)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (payment.note?.trim().isNotEmpty == true)
                            Text(
                              payment.note!.trim(),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Helpers.formatNumber(payment.amount),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fundTypeLabel(String type) => switch (type) {
        'subscription' => 'اشتراك',
        'penalty' => 'تسوية/جزاء',
        'donation' => 'تبرع',
        _ => 'دفعة',
      };

  Widget _buildExams(StudentPeriodReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.quiz_outlined, size: 19),
                SizedBox(width: 7),
                Text('اختبارات الفترة', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ...report.exams.map(
              (exam) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${exam.type == 'oral' ? 'شفهي' : 'تحريري'} · ${_formatDate(exam.date)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '${exam.score}%',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: exam.score >= 60
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
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
        backgroundColor: color.withValues(alpha: 0.12),
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
        _detailRow('تقييم الحفظ', day.memorizationRating),
        _detailRow('تقييم المراجعة', day.revisionRating),
        if (day.lateMinutes > 0)
          _detailRow('مدة التأخر', '${day.lateMinutes} دقيقة'),
        _detailRow('النقاط', '+${Helpers.formatNumber(day.positivePoints)} / -${Helpers.formatNumber(day.negativePoints)}'),
        if (_dayNote(day).isNotEmpty) _detailRow('الملاحظات', _dayNote(day)),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: AppResponsiveInfoRow(
        label: label,
        value: value,
        labelWidth: 75,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
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
        AppResponsiveButtonRow(
          children: [
            OutlinedButton.icon(
              onPressed: () => _print(report, PdfPageFormat.a4),
              icon: const Icon(Icons.print),
              label: const Text('طباعة A4'),
            ),
            OutlinedButton.icon(
              onPressed: () => _print(report, PdfPageFormat.a5),
              icon: const Icon(Icons.print_outlined),
              label: const Text('طباعة A5'),
            ),
            OutlinedButton.icon(
              onPressed: () => _print(
                report,
                PdfPageFormat.a4,
                compactSummary: true,
              ),
              icon: const Icon(Icons.description_outlined),
              label: const Text('ملخص صفحة واحدة'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickRange() async {
    final range = await showDualCalendarDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      title: 'اختر فترة التقرير',
    );
    if (range == null) return;
    setState(() {
      _startDate = _dateOnly(range.start);
      _endDate = _dateOnly(range.end);
    });
    await _generate();
  }

  Future<void> _print(
    StudentPeriodReport report,
    PdfPageFormat format, {
    bool compactSummary = false,
  }) async {
    final settings = await _db.getSettings();
    final bytes = await _pdf.generateStudentPeriodReport(
      report: report,
      pageFormat: format,
      halaqahName: settings.halaqahName,
      mosqueName: settings.mosqueName,
      useHijriCalendar: settings.useHijriCalendar,
      compactSummary: compactSummary,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _shareWhatsApp(StudentPeriodReport report) async {
    final settings = await _db.getSettings();
    final text = _whatsAppText(
      report,
      useHijriCalendar: settings.useHijriCalendar,
    );
    await Share.share(text, subject: 'تقرير ${report.student.name}');
  }

  String _whatsAppText(
    StudentPeriodReport report, {
    bool useHijriCalendar = false,
  }) {
    final memorizationRanges = report.days
        .expand((day) => day.memorization)
        .toList();
    final revisionRanges = report.days.expand((day) => day.revision).toList();
    String reportDate(DateTime date) => useHijriCalendar
        ? Helpers.getFullHijriDate(date)
        : _formatDate(date);
    final buffer = StringBuffer()
      ..writeln('🕌 *تقرير الطالب خلال الفترة*')
      ..writeln('حرصًا على متابعة ابنكم، نضع بين أيديكم مستوى أدائه خلال الفترة:')
      ..writeln('👤 *${report.student.name}*')
      ..writeln('🪪 كود الطالب: ${report.student.displayCode}')
      ..writeln('📅 ${reportDate(report.startDate)} — ${reportDate(report.endDate)}')
      ..writeln()
      ..writeln('📖 *الحفظ والمراجعة*')
      ..writeln('✅ الحفظ الجديد: ${report.memorizedAyahs} آية (${report.memorizedPages.toStringAsFixed(1)} صفحة)')
      ..writeln('🧭 من: ${_progressText(memorizationRanges)}')
      ..writeln('🔁 المراجعة: ${report.revisedAyahs} آية (${report.revisedPages.toStringAsFixed(1)} صفحة)')
      ..writeln('📚 السرد: ${report.recitedAyahs} آية (${report.recitedPages.toStringAsFixed(1)} صفحة)')
      ..writeln('📊 إجمالي الصفحات: ${report.totalCompletedPages.toStringAsFixed(1)}')
      ..writeln('🧭 من: ${_progressText(revisionRanges)}')
      ..writeln('⭐ متوسط الجودة: ${report.averageQuality.toStringAsFixed(1)}/5')
      ..writeln('💳 مدفوعات الفترة: ${report.paidAmount.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('📅 *الحضور والمواظبة*')
      ..writeln('✅ حاضر: ${report.presentDays} | ⏰ متأخر: ${report.lateDays}')
      ..writeln('⏱️ إجمالي وقت التأخر: ${report.totalLateMinutes} دقيقة')
      ..writeln('❌ غائب: ${report.absentDays} | 📝 مستأذن: ${report.excusedDays}')
      ..writeln('🔕 لم يسمّع وهو حاضر: ${report.noRecitationDays}')
      ..writeln('📊 نسبة الحضور: ${report.attendanceRate}%')
      ..writeln()
      ..writeln('🏆 إيجابيات: +${Helpers.formatNumber(report.positivePoints)} (${report.positiveEvents})')
      ..writeln('⚠️ سلبيات: -${Helpers.formatNumber(report.negativePoints)} (${report.negativeEvents})')
      ..writeln('🚫 مخالفات مستقلة: ${report.violationEvents} (-${report.violationPoints})')
      ..writeln('💳 سُوّي عبر الصندوق: ${report.settledNegativePoints} نقطة | المتبقي: -${report.outstandingNegativePoints}')
      ..writeln('📈 الأداء العام: ${report.performanceScore}%')
      ..writeln(report.rankLabel == null ? '' : '🏅 ${report.rankLabel}');
    if (report.exams.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('📝 *اختبارات الفترة*');
      for (final exam in report.exams) {
        buffer.writeln(
          '• ${reportDate(exam.date)} — ${exam.type == 'oral' ? 'شفهي' : 'تحريري'}: ${exam.score}%',
        );
      }
    }
    buffer
      ..writeln()
      ..writeln('🗓️ *تفصيل الأيام*');
    for (final day in report.days) {
      final activity = day.record?.hasActivity == true
          ? (day.record!.activityNote?.trim().isNotEmpty == true
              ? ' · ${day.record!.activityNote!.trim()}'
              : '')
          : '';
      final recitation = day.memorizationDone || day.revisionDone
          ? ' · تسميع مسجل'
          : day.record?.recitationExempt == true &&
                  day.record?.hasActivity != true &&
                  day.record?.talaqqinDone != true
              ? ' · معفى من التسميع'
              : '';
      buffer.writeln(
        '• ${Helpers.getDayName(day.date)} ${reportDate(day.date)} — '
        '${_attendanceLabel(day)}$activity$recitation',
      );
    }
    buffer.writeln();

    final notes = report.days
        .where((day) =>
            day.isSuspended || day.vacation != null || day.hold != null || day.record?.hasActivity == true)
        .map((day) => '• ${reportDate(day.date)}: ${_dayNote(day)}')
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
    buffer.writeln('ننتظر ملاحظاتكم، فبتعاون الأسرة والمعلم يرتقي الطالب بإذن الله.');
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
      final label = day.hold!.exemptsAttendance
          ? 'توقف كامل'
          : 'إيقاف التسميع';
      return '$label: ${day.hold!.reason}'
          '${note == null || note.isEmpty ? '' : ' — $note'}';
    }
    if (day.record?.hasActivity == true) {
      final note = day.record!.activityNote?.trim();
      return '${DailyActivityType.label(day.record!.activityType)}'
          '${note == null || note.isEmpty ? '' : ': $note'}';
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
      day.record?.talaqqinNote,
      day.record?.activityNote,
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
    if (day.hold != null) {
      return day.hold!.exemptsAttendance
          ? 'متوقف مؤقتًا — معفى من الحضور والتسميع'
          : 'الحضور متاح — التسميع موقوف';
    }
    final activityLabel = day.record?.hasActivity == true
        ? DailyActivityType.label(day.record!.activityType)
        : null;
    switch (day.record?.attendance) {
      case 'present':
        if (day.memorizationDone || day.revisionDone) {
          return activityLabel == null
              ? 'حاضر وسمّع'
              : 'حاضر وسمّع — $activityLabel';
        }
        if (day.record?.talaqqinDone == true) {
          return activityLabel == null
              ? 'حاضر — تلقين'
              : 'حاضر — تلقين و$activityLabel';
        }
        if (activityLabel != null) return '$activityLabel — حاضر ومعفى من التسميع';
        if (day.record?.recitationExempt == true) return 'حاضر — معفى من التسميع';
        return 'حاضر ولم يسمّع';
      case 'late':
        if (day.memorizationDone || day.revisionDone) {
          return activityLabel == null
              ? 'متأخر وسمّع'
              : 'متأخر وسمّع — $activityLabel';
        }
        if (day.record?.talaqqinDone == true) {
          return activityLabel == null
              ? 'متأخر — تلقين'
              : 'متأخر — تلقين و$activityLabel';
        }
        if (activityLabel != null) return '$activityLabel — متأخر ومعفى من التسميع';
        if (day.record?.recitationExempt == true) return 'متأخر — معفى من التسميع';
        return 'متأخر ولم يسمّع';
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
