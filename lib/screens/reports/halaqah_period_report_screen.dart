import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/halaqah_period_report.dart';
import '../../services/database_service.dart';
import '../../services/share_file_name_service.dart';
import '../../services/halaqah_period_report_service.dart';
import '../../services/pdf_service.dart';
import '../../utils/helpers.dart';

class HalaqahPeriodReportScreen extends StatefulWidget {
  final String initialPeriod;

  const HalaqahPeriodReportScreen({
    super.key,
    this.initialPeriod = 'month',
  });

  @override
  State<HalaqahPeriodReportScreen> createState() =>
      _HalaqahPeriodReportScreenState();
}

class _HalaqahPeriodReportScreenState
    extends State<HalaqahPeriodReportScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  final GlobalKey _shareCardKey = GlobalKey();
  late final HalaqahPeriodReportService _reports;
  late DateTime _startDate;
  late DateTime _endDate;
  HalaqahPeriodReport? _report;
  String _halaqahName = 'حلقتي';
  String _mosqueName = '';
  bool _useHijriCalendar = false;
  bool _loading = true;
  bool _exportingImage = false;
  int _completed = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _reports = HalaqahPeriodReportService(database: _db);
    final today = _dateOnly(DateTime.now());
    _endDate = today;
    switch (widget.initialPeriod) {
      case 'day':
        _startDate = today;
        break;
      case 'week':
        _startDate = today.subtract(const Duration(days: 6));
        break;
      default:
        _startDate = DateTime(today.year, today.month, 1);
    }
    _generate();
  }

  Future<void> _generate() async {
    setState(() {
      _loading = true;
      _completed = 0;
      _total = 0;
    });
    try {
      final settings = await _db.getSettings();
      final report = await _reports.generate(
        startDate: _startDate,
        endDate: _endDate,
        onProgress: (completed, total) {
          if (!mounted) return;
          setState(() {
            _completed = completed;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _halaqahName = settings.halaqahName;
        _mosqueName = settings.mosqueName;
        _useHijriCalendar = settings.useHijriCalendar;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء تقرير الحلقة: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التقرير التجميعي للحلقة')),
      body: RefreshIndicator(
        onRefresh: _generate,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _filters(),
            const SizedBox(height: 16),
            if (_loading)
              _loadingCard()
            else if (_report != null) ...[
              RepaintBoundary(
                key: _shareCardKey,
                child: _shareCard(_report!),
              ),
              const SizedBox(height: 16),
              _actions(_report!),
              const SizedBox(height: 16),
              _studentsTable(_report!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filters() => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('فترة التقرير', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('اليوم'),
                    onPressed: () {
                      final today = _dateOnly(DateTime.now());
                      setState(() => _startDate = _endDate = today);
                      _generate();
                    },
                  ),
                  ActionChip(
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
                  ActionChip(
                    avatar: const Icon(Icons.date_range, size: 18),
                    label: Text('${_formatDate(_startDate)} — ${_formatDate(_endDate)}'),
                    onPressed: _pickRange,
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_remove_alt_1_outlined),
                title: const Text(
                  'استثناءات ترتيب الأوائل',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  (_report?.rankingExcludedCount ?? 0) == 0
                      ? 'لا يوجد مستبعدون. الاستثناء يؤثر على ترتيب المتميزين فقط ولا يحذف بيانات الطالب من التقرير.'
                      : 'مستبعدون من ترتيب المتميزين: ${_report!.rankingExcludedCount} — تبقى بياناتهم ضمن الإجماليات والتفاصيل.',
                ),
                trailing: Badge(
                  isLabelVisible: (_report?.rankingExcludedCount ?? 0) > 0,
                  label: Text('${_report?.rankingExcludedCount ?? 0}'),
                  child: const Icon(Icons.tune_outlined),
                ),
                onTap: _report == null ? null : _manageRankingExclusions,
              ),
            ],
          ),
        ),
      );

  Widget _loadingCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(
                _total == 0
                    ? 'جارٍ جمع بيانات الحلقة…'
                    : 'تم تحليل $_completed من $_total طالب',
              ),
            ],
          ),
        ),
      );

  Widget _shareCard(HalaqahPeriodReport report) {
    final scoreColor = _scoreColor(report.performanceScore);
    final cardWidth = (MediaQuery.sizeOf(context).width - 32)
        .clamp(300.0, 720.0)
        .toDouble();
    final compact = cardWidth < 620;
    return Container(
      width: cardWidth,
      padding: EdgeInsets.all(compact ? 16 : 30),
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 16 : 22),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التقرير التجميعي للحلقة',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: compact ? 20 : 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'حلقة $_halaqahName${_mosqueName.isEmpty ? '' : ' · مسجد $_mosqueName'}',
                        style: TextStyle(color: const Color(0xFFCCFBF1), fontSize: compact ? 13 : 15),
                      ),
                      Text(
                        '${_formatDate(report.startDate)} — ${_formatDate(report.endDate)} · '
                        '${report.studyDays} أيام دراسية',
                        style: TextStyle(color: const Color(0xFF99F6E4), fontSize: compact ? 11 : 13),
                      ),
                      if (report.rankingExcludedCount > 0)
                        Text(
                          'استبعاد ${report.rankingExcludedCount} من ترتيب الأوائل فقط',
                          style: TextStyle(
                            color: const Color(0xFFFDE68A),
                            fontSize: compact ? 10 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  width: compact ? 78 : 100,
                  height: compact ? 78 : 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: scoreColor, width: 5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${report.performanceScore}%',
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: compact ? 20 : 25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'مستوى الحلقة',
                        style: TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: compact ? 2 : 4,
            childAspectRatio: compact ? 1.75 : 1.55,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              _visualStat('الطلاب', '${report.studentCount}', Icons.groups, Colors.teal),
              _visualStat('سمّعوا', '${report.recitedStudentCount}', Icons.record_voice_over, Colors.green),
              _visualStat('الحفظ', '${report.totalMemorizedAyahs} آية', Icons.menu_book, Colors.green),
              _visualStat('المراجعة', '${report.totalRevisedAyahs} آية', Icons.refresh, Colors.blue),
              _visualStat('إجمالي الصفحات', report.totalCompletedPages.toStringAsFixed(1), Icons.auto_stories, Colors.purple),
              _visualStat('صفحات حفظ', report.totalMemorizedPages.toStringAsFixed(1), Icons.menu_book_outlined, Colors.green),
              _visualStat('صفحات مراجعة', report.totalRevisedPages.toStringAsFixed(1), Icons.refresh, Colors.blue),
              _visualStat('صفحات سرد', report.totalRecitedPages.toStringAsFixed(1), Icons.record_voice_over_outlined, Colors.indigo),
              _visualStat('مدفوعات', report.totalPaidAmount.toStringAsFixed(2), Icons.payments_outlined, Colors.teal),
              _visualStat('الحضور', '${report.attendanceRate}%', Icons.how_to_reg, Colors.teal),
              _visualStat('لم يسمّع', '${report.noRecitationDays}', Icons.volume_off, Colors.orange),
              _visualStat('يحتاج متابعة', '${report.attentionStudents.length}', Icons.priority_high, Colors.red),
            ],
          ),
          const SizedBox(height: 18),
          if (compact) ...[
            _rankingPanel(report),
            const SizedBox(height: 10),
            _attendancePanel(report),
          ] else
            Row(
              children: [
                Expanded(child: _rankingPanel(report)),
                const SizedBox(width: 12),
                Expanded(child: _attendancePanel(report)),
              ],
            ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'خلاصة الفترة',
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أنجز الطلاب ${report.totalMemorizedPages.toStringAsFixed(1)} صفحة حفظ '
                  '(${report.totalMemorizedJuz.toStringAsFixed(2)} جزء تقريبًا)، '
                  'وسجلوا ${Helpers.formatNumber(report.positivePoints)} نقطة إيجابية مقابل '
                  '${Helpers.formatNumber(report.negativePoints)} نقطة سلبية.',
                  style: const TextStyle(color: Color(0xFF475569), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Center(
            child: Text(
              'تقرير مولّد من بيانات الحلقة المسجلة — حلقتي',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visualStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          ],
        ),
      );

  Widget _rankingPanel(HalaqahPeriodReport report) => _panel(
        title: 'متميزو الفترة',
        icon: Icons.emoji_events,
        color: Colors.amber[700]!,
        children: report.topStudents.isEmpty
            ? const [Text('لا توجد بيانات كافية', style: TextStyle(color: Color(0xFF334155)))]
            : report.topStudents.take(4).toList().asMap().entries.map((entry) {
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: entry.key == 0
                            ? Colors.amber[100]
                            : const Color(0xFFF1F5F9),
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.student.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${item.performanceScore}%',
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
      );

  Widget _attendancePanel(HalaqahPeriodReport report) => _panel(
        title: 'الحضور والانضباط',
        icon: Icons.fact_check_outlined,
        color: Colors.teal,
        children: [
          _miniRow('حاضر', report.presentDays, Colors.green),
          _miniRow('متأخر', report.lateDays, Colors.orange),
          _miniRow('غائب', report.absentDays, Colors.red),
          _miniRow('مستأذن', report.excusedDays, Colors.blue),
        ],
      );

  Widget _panel({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const Divider(color: Color(0xFFE2E8F0)),
            ...children,
          ],
        ),
      );

  Widget _miniRow(String label, int value, Color color) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: Color(0xFF334155)),
              ),
            ),
            Text('$value', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _actions(HalaqahPeriodReport report) => Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exportingImage ? null : _shareImage,
                  icon: _exportingImage
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined),
                  label: const Text('مشاركة كصورة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _printPdf(report),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('تقرير مفصل'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _printManagementSummary(report),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('ملخص الإدارة — جميع الطلاب في صفحة واحدة'),
            ),
          ),
        ],
      );

  Widget _studentsTable(HalaqahPeriodReport report) => Card(
        child: ExpansionTile(
          leading: const Icon(Icons.table_rows_outlined),
          title: const Text('تفاصيل جميع الطلاب', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('${report.studentCount} طالبًا مرتبين أبجديًا'),
          children: report.students.map((item) {
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _scoreColor(item.performanceScore).withValues(alpha: 0.12),
                child: Text('${item.performanceScore}%', style: TextStyle(fontSize: 11, color: _scoreColor(item.performanceScore))),
              ),
              title: Text(item.student.name),
              subtitle: Text(
                'حفظ ${item.memorizedAyahs} · مراجعة ${item.revisedAyahs} · '
                'حضور ${item.attendanceRate}%'
                '${report.isExcludedFromRanking(item.student.id) ? ' · مستبعد من ترتيب الأوائل' : ''}',
              ),
              trailing: item.needsAttention
                  ? const Tooltip(message: 'يحتاج متابعة', child: Icon(Icons.priority_high, color: Colors.orange))
                  : const Icon(Icons.check_circle_outline, color: Colors.green),
            );
          }).toList(),
        ),
      );

  Future<void> _manageRankingExclusions() async {
    final report = _report;
    if (report == null) return;
    final selected = Set<String>.from(report.rankingExcludedStudentIds);
    final students = report.students.map((item) => item.student).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final joinedWithinPeriod = students
              .where((student) =>
                  !student.joinDate.isBefore(_startDate) &&
                  !student.joinDate.isAfter(_endDate))
              .map((student) => student.id)
              .toSet();
          return SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'استثناءات ترتيب الأوائل',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الاستثناء خاص بهذه الفترة فقط. يبقى الطالب ظاهرًا في تفاصيل التقرير وإجماليات الحلقة، لكنه لا يدخل في قائمة المتميزين أو المركز الأول.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: joinedWithinPeriod.isEmpty
                                ? null
                                : () => setSheetState(
                                      () => selected.addAll(joinedWithinPeriod),
                                    ),
                            icon: const Icon(Icons.person_add_alt_1_outlined),
                            label: Text(
                              'استبعاد المستجدين داخل الفترة (${joinedWithinPeriod.length})',
                            ),
                          ),
                          TextButton.icon(
                            onPressed: selected.isEmpty
                                ? null
                                : () => setSheetState(selected.clear),
                            icon: const Icon(Icons.restart_alt),
                            label: const Text('إعادة الجميع للترتيب'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final excluded = selected.contains(student.id);
                      final isNew = joinedWithinPeriod.contains(student.id);
                      return CheckboxListTile(
                        value: excluded,
                        onChanged: (value) => setSheetState(() {
                          if (value == true) {
                            selected.add(student.id);
                          } else {
                            selected.remove(student.id);
                          }
                        }),
                        title: Text(student.name),
                        subtitle: isNew
                            ? Text(
                                'مستجد خلال فترة التقرير · انضم ${_formatDate(student.joinDate)}',
                              )
                            : null,
                        secondary: Icon(
                          excluded
                              ? Icons.person_off_outlined
                              : Icons.emoji_events_outlined,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      icon: const Icon(Icons.check),
                      label: Text('اعتماد الاستثناءات (${selected.length})'),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (accepted != true) return;
    await _reports.saveRankingExcludedStudentIds(
      startDate: _startDate,
      endDate: _endDate,
      studentIds: selected,
    );
    await _generate();
  }

  Future<void> _pickRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: _dateOnly(DateTime.now()),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      helpText: 'اختر فترة تقرير الحلقة',
      saveText: 'اعتماد',
    );
    if (result == null) return;
    setState(() {
      _startDate = _dateOnly(result.start);
      _endDate = _dateOnly(result.end);
    });
    await _generate();
  }

  Future<void> _shareImage() async {
    setState(() => _exportingImage = true);
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = _shareCardKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw StateError('تعذر تجهيز بطاقة التقرير');
      final image = await boundary.toImage(pixelRatio: 2.2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('تعذر تحويل التقرير إلى صورة');
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}/${ShareFileNameService.appName}_تقرير_الحلقة_${_fileDate(_startDate)}_${_fileDate(_endDate)}.png',
      );
      await file.writeAsBytes(data.buffer.asUint8List());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: '${ShareFileNameService.appName} — تقرير حلقة $_halaqahName من ${_formatDate(_startDate)} إلى ${_formatDate(_endDate)}',
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر مشاركة الصورة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingImage = false);
    }
  }

  Future<void> _printPdf(HalaqahPeriodReport report) async {
    final bytes = await _pdf.generateHalaqahPeriodReport(
      report: report,
      halaqahName: _halaqahName,
      mosqueName: _mosqueName,
      pageFormat: PdfPageFormat.a4,
      useHijriCalendar: _useHijriCalendar,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _printManagementSummary(HalaqahPeriodReport report) async {
    final bytes = await _pdf.generateHalaqahManagementSummary(
      report: report,
      halaqahName: _halaqahName,
      mosqueName: _mosqueName,
      useHijriCalendar: _useHijriCalendar,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF16A34A);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  String _formatDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String _fileDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}
