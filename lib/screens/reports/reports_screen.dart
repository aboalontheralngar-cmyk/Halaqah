import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/halaqah_period_report_service.dart';
import '../../services/student_period_report_service.dart';
import '../../models/halaqah_period_report.dart';
import '../../models/student.dart';
import '../../utils/helpers.dart';
import '../../app/design_tokens.dart';
import '../../widgets/app_design_widgets.dart';
import '../../widgets/student_card.dart';
import '../../widgets/dual_calendar_date_picker.dart';
import 'student_period_report_screen.dart';
import 'halaqah_period_report_screen.dart';
import 'student_receipt_screen.dart';

class ReportsScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const ReportsScreen({super.key, this.onOpenMenu});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  late final StudentPeriodReportService _periodReports;
  late final HalaqahPeriodReportService _halaqahReports;
  List<Student> _students = [];
  HalaqahPeriodReport? _dashboard;
  String? _dashboardError;
  bool _isLoading = true;
  bool _isBatchExporting = false;

  @override
  void initState() {
    super.initState();
    _periodReports = StudentPeriodReportService(database: _db);
    _halaqahReports = HalaqahPeriodReportService(database: _db);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final today = DateTime.now();
      final results = await Future.wait<dynamic>([
        _db.getStudents(),
        _halaqahReports.generate(
          startDate: DateTime(today.year, today.month, 1),
          endDate: DateTime(today.year, today.month, today.day),
        ),
      ]);
      final students = results[0] as List<Student>;
      setState(() {
        _students = students;
        _dashboard = results[1] as HalaqahPeriodReport;
        _dashboardError = null;
        _isLoading = false;
      });
    } catch (e) {
      final students = await _db.getStudents().catchError(
        (_) => <Student>[],
      );
      if (!mounted) return;
      setState(() {
        _students = students;
        _dashboardError = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onOpenMenu == null
            ? null
            : IconButton(
                onPressed: widget.onOpenMenu,
                icon: const Icon(Icons.menu),
                tooltip: 'القائمة الرئيسية',
              ),
        title: const Text('التقارير'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              children: [
                const AppPageIntro(
                  title: 'التقارير والتحليلات',
                  subtitle:
                      'ملخصات يومية وتقارير دورية قابلة للطباعة والمشاركة.',
                  icon: Icons.assessment_outlined,
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildDashboard(),
                const SizedBox(height: AppSpacing.xl),
                _buildReportTypeSection(),
                const SizedBox(height: AppSpacing.xxl),
                _buildStudentReportsSection(),
              ],
            ),
    );
  }

  Widget _buildDashboard() {
    final report = _dashboard;
    if (report == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _dashboardError == null
                      ? 'لا توجد بيانات كافية لقياس أداء الحلقة.'
                      : 'تعذر حساب لوحة الأداء الآن. اسحب للتحديث أو افتح تقرير الفترة للمحاولة مجددًا.',
                ),
              ),
            ],
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final topStudent =
        report.topStudents.isEmpty ? null : report.topStudents.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'لوحة أداء الحلقة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'من بداية الشهر حتى اليوم',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 74,
                  height: 74,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: report.performanceScore / 100,
                        strokeWidth: 7,
                        backgroundColor: scheme.surfaceContainerHigh,
                      ),
                      Text(
                        '${report.performanceScore}%',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _dashboardMetric(
                  'الحضور',
                  '${report.attendanceRate}%',
                  Icons.how_to_reg_outlined,
                  context.semanticColors.success,
                ),
                _dashboardMetric(
                  'الحفظ',
                  '${report.totalMemorizedAyahs} آية',
                  Icons.menu_book_outlined,
                  scheme.primary,
                ),
                _dashboardMetric(
                  'المراجعة',
                  '${report.totalRevisedAyahs} آية',
                  Icons.replay_outlined,
                  context.semanticColors.info,
                ),
                _dashboardMetric(
                  'تحتاج متابعة',
                  '${report.attentionStudents.length}',
                  Icons.flag_outlined,
                  context.semanticColors.warning,
                ),
              ],
            ),
            if (topStudent != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'الأعلى أداءً: ${topStudent.student.name}',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text(
                      '${topStudent.performanceScore}%',
                      style: TextStyle(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                onPressed: () => _openHalaqahReport('month'),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('فتح التحليل الكامل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardMetric(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      constraints: const BoxConstraints(minWidth: 128),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'أنواع التقارير',
          subtitle: 'اختر النطاق المناسب ثم راجع التقرير قبل تصديره.',
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 760 ? 3 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: columns == 3 ? 1.65 : 1.28,
              children: [
                _buildReportCard(
                  'تقرير يومي',
                  'الحضور والتسميع ونقاط اليوم',
                  Icons.today_outlined,
                  Colors.blue,
                  () => _generateDailyReport(),
                ),
                _buildReportCard(
                  'تقرير أسبوعي',
                  'ملخص أسبوع الدراسة واتجاه الأداء',
                  Icons.date_range_outlined,
                  Colors.green,
                  () => _generateWeeklyReport(),
                ),
                _buildReportCard(
                  'تقرير شهري',
                  'مؤشرات الشهر وأفضل النتائج',
                  Icons.calendar_month_outlined,
                  Colors.orange,
                  () => _generateMonthlyReport(),
                ),
                _buildReportCard(
                  'التقرير التجميعي',
                  'الحلقة كاملة مع الأوائل والاستثناءات',
                  Icons.analytics_outlined,
                  Colors.purple,
                  () => _showHalaqahStats(),
                ),
                _buildReportCard(
                  'تقرير طالب',
                  'فترة مخصصة لطالب واحد بالتفصيل',
                  Icons.assessment_outlined,
                  Colors.teal,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentPeriodReportScreen(),
                    ),
                  ),
                ),
                _buildReportCard(
                  _isBatchExporting
                      ? 'جارٍ تجهيز التقارير…'
                      : 'PDF لجميع الطلاب',
                  'ملف واحد وتقارير مرتبة لكل طالب',
                  Icons.picture_as_pdf_outlined,
                  Colors.red,
                  _isBatchExporting ? () {} : _startBatchPeriodExport,
                ),
                _buildReportCard(
                  'بطاقات QR',
                  'ورقة بطاقات الطلاب للطباعة والتوزيع',
                  Icons.qr_code_2_outlined,
                  Colors.indigo,
                  _printStudentQrCards,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _printStudentQrCards() async {
    final students = _students
        .where((student) => student.status == 'active')
        .toList();
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب نشطون لطباعة بطاقاتهم')),
      );
      return;
    }
    try {
      final settings = await _db.getSettings();
      final bytes = await _pdf.generateStudentQrCards(
        students: students,
        halaqahName: settings.halaqahName,
        mosqueName: settings.mosqueName,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إنشاء بطاقات الطلاب: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildReportCard(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startBatchPeriodExport() async {
    if (_students.isEmpty || _isBatchExporting) return;
    final today = DateTime.now();
    var startDate = DateTime(today.year, today.month, 1);
    var endDate = DateTime(today.year, today.month, today.day);
    var useA5 = false;
    var activeOnly = true;
    var compactSummary = true;
    var excludedStudentIds = <String>{};
    String? selectedHijriMonthKey;
    final hijriRanges = Helpers.recentHijriMonths();
    final hijriRangeByKey = {
      for (final range in hijriRanges) range.key: range,
    };

    final options = await showDialog<_BatchReportOptions>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const AppDialogTitle(
            icon: Icons.picture_as_pdf_outlined,
            iconColor: Colors.red,
            title: 'تصدير تقارير جميع الطلاب',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سينشأ ملف PDF واحد، ويبدأ تقرير كل طالب في صفحة مستقلة.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedHijriMonthKey,
                  decoration: const InputDecoration(
                    labelText: 'اختيار شهر هجري',
                    prefixIcon: Icon(Icons.brightness_2_outlined),
                    border: OutlineInputBorder(),
                  ),
                  hint: const Text('محرم أو شهر هجري آخر'),
                  isExpanded: true,
                  items: hijriRanges
                      .map(
                        (range) => DropdownMenuItem(
                          value: range.key,
                          child: Text(
                            range.label,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (rangeKey) {
                    final range = hijriRangeByKey[rangeKey];
                    if (range == null) return;
                    setDialogState(() {
                      selectedHijriMonthKey = range.key;
                      startDate = range.startDate;
                      endDate = range.endDate;
                    });
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range_outlined),
                  title: const Text('فترة التقرير'),
                  subtitle: Text(
                    '${_formatGregorianDate(startDate)} — ${_formatGregorianDate(endDate)}',
                  ),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: () async {
                    final range = await showDualCalendarDateRangePicker(
                      context: dialogContext,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(today.year, today.month, today.day),
                      initialDateRange: DateTimeRange(
                        start: startDate,
                        end: endDate,
                      ),
                      title: 'اختر فترة التقارير الجماعية',
                    );
                    if (range == null) return;
                    setDialogState(() {
                      startDate = DateTime(
                        range.start.year,
                        range.start.month,
                        range.start.day,
                      );
                      endDate = DateTime(
                        range.end.year,
                        range.end.month,
                        range.end.day,
                      );
                    });
                  },
                ),
                const Divider(),
                const Text('حجم الورق', style: TextStyle(fontWeight: FontWeight.bold)),
                RadioGroup<bool>(
                  groupValue: useA5,
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => useA5 = value);
                    }
                  },
                  child: Column(
                    children: const [
                      RadioListTile<bool>(
                        value: false,
                        contentPadding: EdgeInsets.zero,
                        title: Text('A4 — مناسب للتقارير المفصلة'),
                      ),
                      RadioListTile<bool>(
                        value: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text('A5 — حجم أصغر للطباعة'),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  value: activeOnly,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('الطلاب النشطون فقط'),
                  subtitle: const Text('عطّل الخيار لتضمين الأرشيف والطلاب السابقين'),
                  onChanged: (value) => setDialogState(() => activeOnly = value),
                ),
                SwitchListTile(
                  value: compactSummary,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ملخص صفحة واحدة لكل طالب'),
                  subtitle: const Text(
                    'أنسب للطباعة الجماعية؛ عطّله للحصول على التقرير اليومي المفصل.',
                  ),
                  onChanged: (value) =>
                      setDialogState(() => compactSummary = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_off_outlined),
                  title: const Text('استثناء طلاب من ملف PDF'),
                  subtitle: Text(
                    excludedStudentIds.isEmpty
                        ? 'لم يتم استثناء أحد'
                        : 'مستثنى ${excludedStudentIds.length} طالب/طلاب',
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () async {
                    final selected = await _pickBatchExcludedStudents(
                      initial: excludedStudentIds,
                      startDate: startDate,
                      endDate: endDate,
                      activeOnly: activeOnly,
                    );
                    if (selected == null) return;
                    setDialogState(() => excludedStudentIds = selected);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(
                dialogContext,
                _BatchReportOptions(
                  startDate: startDate,
                  endDate: endDate,
                  pageFormat: useA5 ? PdfPageFormat.a5 : PdfPageFormat.a4,
                  activeOnly: activeOnly,
                  compactSummary: compactSummary,
                  excludedStudentIds: Set<String>.from(excludedStudentIds),
                ),
              ),
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('إنشاء الملف'),
            ),
          ],
        ),
      ),
    );
    if (options == null || !mounted) return;
    await _exportAllStudentPeriodReports(options);
  }


  Future<Set<String>?> _pickBatchExcludedStudents({
    required Set<String> initial,
    required DateTime startDate,
    required DateTime endDate,
    required bool activeOnly,
  }) async {
    final candidates = _students
        .where((student) => !activeOnly || student.status == 'active')
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    var selected = Set<String>.from(initial);
    return showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('استثناء الطلاب من ملف PDF'),
          content: SizedBox(
            width: 460,
            height: 430,
            child: Column(
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        final periodStart = DateTime(
                          startDate.year,
                          startDate.month,
                          startDate.day,
                        );
                        final periodEndExclusive = DateTime(
                          endDate.year,
                          endDate.month,
                          endDate.day,
                        ).add(const Duration(days: 1));
                        setDialogState(() {
                          selected.addAll(
                            candidates
                                .where(
                                  (student) =>
                                      !student.joinDate.isBefore(periodStart) &&
                                      student.joinDate.isBefore(periodEndExclusive),
                                )
                                .map((student) => student.id),
                          );
                        });
                      },
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: const Text('استبعاد المستجدين في الفترة'),
                    ),
                    TextButton(
                      onPressed: () => setDialogState(selected.clear),
                      child: const Text('إلغاء كل الاستثناءات'),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final student = candidates[index];
                      final checked = selected.contains(student.id);
                      return CheckboxListTile(
                        value: checked,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(student.name),
                        subtitle: Text(
                          'التحاق: ${Helpers.formatPlanDate(student.joinDate)}',
                        ),
                        onChanged: (value) => setDialogState(() {
                          if (value == true) {
                            selected.add(student.id);
                          } else {
                            selected.remove(student.id);
                          }
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                Set<String>.from(selected),
              ),
              child: Text('اعتماد (${selected.length})'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportAllStudentPeriodReports(
    _BatchReportOptions options,
  ) async {
    final students = _students
        .where((student) => !options.activeOnly || student.status == 'active')
        .where((student) => !options.excludedStudentIds.contains(student.id))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طلاب ضمن النطاق المختار')),
      );
      return;
    }

    setState(() => _isBatchExporting = true);
    final progress = ValueNotifier<int>(0);
    var progressDialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('تجهيز ملف التقارير'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (context, completed, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: completed / students.length),
                const SizedBox(height: 12),
                Text('تم تجهيز $completed من ${students.length}'),
                const SizedBox(height: 4),
                Text(
                  'يرجى إبقاء هذه الشاشة مفتوحة حتى يكتمل إنشاء الملف.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final reports = await _periodReports.generateForStudents(
        students: students,
        startDate: options.startDate,
        endDate: options.endDate,
        onProgress: (completed, _) => progress.value = completed,
      );
      final settings = await _db.getSettings();
      final bytes = await _pdf.generateAllStudentPeriodReports(
        reports: reports,
        pageFormat: options.pageFormat,
        halaqahName: settings.halaqahName,
        mosqueName: settings.mosqueName,
        useHijriCalendar: settings.useHijriCalendar,
        compactSummary: options.compactSummary,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      progressDialogOpen = false;
      final from = _fileDate(options.startDate);
      final to = _fileDate(options.endDate);
      await _pdf.sharePdf(bytes, 'halaqah_students_reports_${from}_$to.pdf');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إنشاء ملف واحد يضم ${students.length} تقريرًا'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (mounted) {
        if (progressDialogOpen) {
          Navigator.of(context, rootNavigator: true).pop();
          progressDialogOpen = false;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر إنشاء التقارير الجماعية: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      progress.dispose();
      if (mounted) setState(() => _isBatchExporting = false);
    }
  }

  String _formatGregorianDate(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String _fileDate(DateTime date) =>
      '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';

  Widget _buildStudentReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(
          title: 'تقارير الطلاب',
          subtitle: 'وصول سريع إلى تقارير كل طالب وملفات المشاركة.',
        ),
        const SizedBox(height: 12),
        if (_students.isEmpty)
          const AppEmptyState(
            icon: Icons.people_outline,
            title: 'لا يوجد طلاب',
            message: 'أضف الطلاب أولاً حتى تتمكن من إنشاء تقاريرهم.',
          )
        else
          ..._students.map(
            (student) => StudentCard(
              student: student,
              subtitle: 'الحفظ: ${student.totalMemorized} آية',
              trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleStudentReport(student, value),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'period',
                        child: Text('تقرير أسبوعي/شهري/فترة'),
                      ),
                      const PopupMenuItem(
                        value: 'whatsapp',
                        child: Row(
                          children: [
                            Icon(Icons.chat, color: Colors.green, size: 20),
                            SizedBox(width: 8),
                            Text('تقرير واتساب الشهري'),
                          ],
                        ),
                      ),
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
          ),
      ],
    );
  }

  void _generateDailyReport() {
    _openHalaqahReport('day');
  }

  void _generateWeeklyReport() {
    _openHalaqahReport('week');
  }

  void _generateMonthlyReport() {
    _openHalaqahReport('month');
  }

  void _showHalaqahStats() {
    _openHalaqahReport('month');
  }

  void _openHalaqahReport(String period) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HalaqahPeriodReportScreen(
          initialPeriod: period,
        ),
      ),
    );
  }

  void _handleStudentReport(Student student, String type) {
    switch (type) {
      case 'period':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentPeriodReportScreen(
              initialStudent: student,
            ),
          ),
        );
        break;
      case 'whatsapp':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentPeriodReportScreen(
              initialStudent: student,
              initialPeriod: 'month',
            ),
          ),
        );
        break;
      case 'full':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentPeriodReportScreen(
              initialStudent: student,
              initialPeriod: 'month',
            ),
          ),
        );
        break;
      case 'receipt':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentReceiptScreen(student: student),
          ),
        );
        break;
      case 'attendance':
        _showStudentAttendanceReport(student);
        break;
    }
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


}

class _BatchReportOptions {
  final DateTime startDate;
  final DateTime endDate;
  final PdfPageFormat pageFormat;
  final bool activeOnly;
  final bool compactSummary;
  final Set<String> excludedStudentIds;

  const _BatchReportOptions({
    required this.startDate,
    required this.endDate,
    required this.pageFormat,
    required this.activeOnly,
    required this.compactSummary,
    required this.excludedStudentIds,
  });
}
