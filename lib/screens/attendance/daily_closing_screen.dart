import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../services/daily_closing_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_design_widgets.dart';

class DailyClosingScreen extends StatefulWidget {
  const DailyClosingScreen({super.key, this.initialDate});

  final DateTime? initialDate;

  @override
  State<DailyClosingScreen> createState() => _DailyClosingScreenState();
}

class _DailyClosingScreenState extends State<DailyClosingScreen> {
  final DailyClosingService _service = DailyClosingService();
  late DateTime _selectedDate;
  DailyClosingSnapshot? _snapshot;
  bool _loading = true;
  bool _closing = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _selectedDate = DateTime(initial.year, initial.month, initial.day);
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final snapshot = await _service.load(date: _selectedDate);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تحميل مراجعة اليوم')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _load();
  }

  Future<void> _closeDay() async {
    final snapshot = _snapshot;
    if (snapshot == null || !snapshot.canClose || _closing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const AppDialogTitle(
          icon: Icons.fact_check_outlined,
          title: 'اعتماد إغلاق اليوم؟',
        ),
        content: Text(
          'سيُسجّل ${snapshot.unrecordedCount} طالبًا كغائب، ويُعتمد '
          '${snapshot.absentCount + snapshot.unrecordedCount} سجل غياب، '
          'و${snapshot.noRecitationCount} حالة عدم تسميع.\n\n'
          'لن تتأثر الإجازات المعتمدة أو الطلاب الموقوفون عن التسميع، '
          'ولا يمكن تكرار الإغلاق لنفس اليوم.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('مراجعة أخرى'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.lock_outline),
            label: const Text('اعتماد الإغلاق'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _closing = true);
    try {
      final result = await _service.closeDay(date: _selectedDate);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إغلاق اليوم: ${result.recordsCreated} سجل حضور جديد، '
            '${result.recordsExcused} إجازة، '
            '${result.totalPointsRecordsAdded} سجل نقاط.',
          ),
          backgroundColor: Colors.green,
        ),
      );
      await _load();
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message.toString())),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر إغلاق اليوم. لم تُحفظ عملية جزئية.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  List<DailyClosingStudentItem> get _visibleItems {
    final items = _snapshot?.items ?? const <DailyClosingStudentItem>[];
    switch (_filter) {
      case 'action':
        return items.where((item) => item.needsAction).toList();
      case 'completed':
        return items
            .where((item) => item.state == DailyClosingState.completed)
            .toList();
      case 'exempt':
        return items.where((item) => item.isExempt).toList();
      default:
        return items;
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      appBar: AppBar(title: const Text('مركز إغلاق اليوم')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.sm,
                        AppSpacing.md,
                        AppSpacing.xl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          AppPageIntro(
                            title: 'مراجعة اليوم قبل الاعتماد',
                            subtitle:
                                'راجع السجلات والاستثناءات واعتمدها بعد الدوام؛ وإن تُرك اليوم مفتوحًا يُغلق تلقائيًا عند بدء اليوم التالي.',
                            icon: Icons.fact_check_outlined,
                            actions: [
                              OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(Icons.calendar_month_outlined),
                                label: Text(Helpers.getDayName(_selectedDate)),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          if (snapshot != null) ...[
                            _buildStatusBanner(snapshot),
                            const SizedBox(height: AppSpacing.md),
                            _buildMetrics(snapshot),
                            const SizedBox(height: AppSpacing.md),
                            _buildFilters(snapshot),
                            const SizedBox(height: AppSpacing.sm),
                            ..._visibleItems.map(_buildStudentTile),
                            if (_visibleItems.isEmpty) _buildEmptyState(),
                            const SizedBox(height: AppSpacing.md),
                            _buildCloseButton(snapshot),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatusBanner(DailyClosingSnapshot snapshot) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, title, detail, color) = snapshot.isHoliday
        ? (
            Icons.event_busy_outlined,
            'اليوم معلق أو إجازة',
            snapshot.suspensionReason ?? 'لا توجد عقوبات أو حاجة للإغلاق',
            scheme.tertiary,
          )
        : snapshot.alreadyClosed
            ? (
                Icons.verified_outlined,
                'تم إغلاق اليوم',
                snapshot.closedAt == null
                    ? 'الإغلاق معتمد ولا يمكن تكراره'
                    : '${snapshot.wasAutomaticallyClosed ? 'أُغلق تلقائيًا' : 'اعتمد يدويًا'} في '
                        '${Helpers.formatTime(snapshot.closedAt!, context: context)}',
                Colors.green,
              )
            : !snapshot.isPastEndTime
                ? (
                    Icons.schedule_outlined,
                    'المراجعة متاحة والإغلاق مؤجل',
                    'يُفعّل زر الاعتماد تلقائيًا بعد انتهاء دوام الحلقة',
                    Colors.orange,
                  )
                : (
                    Icons.rule_folder_outlined,
                    'جاهز للمراجعة والاعتماد',
                    'تحقق من الحالات التي تحتاج إجراء قبل الإغلاق',
                    scheme.primary,
                  );
    return Card(
      color: color.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(detail, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetrics(DailyClosingSnapshot snapshot) {
    final metrics = [
      ('مكتمل', snapshot.completedCount, Icons.task_alt, Colors.green),
      ('بلا حضور', snapshot.unrecordedCount, Icons.help_outline, Colors.orange),
      ('غائب', snapshot.absentCount, Icons.person_off_outlined, Colors.red),
      ('لم يسمّع', snapshot.noRecitationCount, Icons.menu_book_outlined, Colors.deepOrange),
      ('مستثنى', snapshot.exemptCount, Icons.shield_outlined, Colors.teal),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth < 350 || textScale > 1.25 ? 2 : 3;
        final width = (constraints.maxWidth - (columns - 1) * AppSpacing.sm) / columns;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: metrics.map((metric) {
            return SizedBox(
              width: width,
              child: Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Column(
                    children: [
                      Icon(metric.$3, color: metric.$4, size: 22),
                      const SizedBox(height: AppSpacing.xs),
                      Text('${metric.$2}', style: Theme.of(context).textTheme.titleLarge),
                      Text(
                        metric.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilters(DailyClosingSnapshot snapshot) {
    final filters = [
      ('all', 'الكل ${snapshot.items.length}'),
      ('action', 'يحتاج إجراء ${snapshot.actionRequiredCount}'),
      ('completed', 'مكتمل ${snapshot.completedCount}'),
      ('exempt', 'مستثنى ${snapshot.exemptCount}'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((entry) {
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(entry.$2),
              selected: _filter == entry.$1,
              onSelected: (_) => setState(() => _filter = entry.$1),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStudentTile(DailyClosingStudentItem item) {
    final presentation = _presentation(item.state);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: presentation.$3.withValues(alpha: .12),
          child: Icon(presentation.$2, color: presentation.$3, size: 20),
        ),
        title: Text(
          item.student.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          item.detail ?? presentation.$1,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: presentation.$3.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(
            presentation.$1,
            style: TextStyle(
              color: presentation.$3,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => const Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: Text('لا توجد حالات ضمن هذا المرشح')),
      );

  Widget _buildCloseButton(DailyClosingSnapshot snapshot) {
    final label = snapshot.isHoliday
        ? 'اليوم لا يحتاج إلى إغلاق'
        : snapshot.alreadyClosed
            ? 'تم اعتماد الإغلاق'
            : !snapshot.isPastEndTime
                ? 'يتاح الإغلاق بعد انتهاء الدوام'
                : 'اعتماد إغلاق اليوم';
    return FilledButton.icon(
      onPressed: snapshot.canClose && !_closing ? _closeDay : null,
      icon: _closing
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(snapshot.alreadyClosed ? Icons.verified : Icons.lock_outline),
      label: Text(label),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
      ),
    );
  }

  (String, IconData, Color) _presentation(DailyClosingState state) {
    switch (state) {
      case DailyClosingState.completed:
        return ('مكتمل', Icons.task_alt, Colors.green);
      case DailyClosingState.absent:
        return ('غائب', Icons.person_off_outlined, Colors.red);
      case DailyClosingState.noRecitation:
        return ('لم يسمّع', Icons.menu_book_outlined, Colors.deepOrange);
      case DailyClosingState.unrecorded:
        return ('بلا تسجيل', Icons.help_outline, Colors.orange);
      case DailyClosingState.excused:
        return ('مستأذن', Icons.beach_access_outlined, Colors.teal);
      case DailyClosingState.held:
        return ('موقوف', Icons.pause_circle_outline, Colors.blueGrey);
      case DailyClosingState.activity:
        return ('نشاط', Icons.celebration_outlined, Colors.purple);
      case DailyClosingState.talaqqin:
        return ('تلقين', Icons.record_voice_over_outlined, Colors.teal);
      case DailyClosingState.holiday:
        return ('إجازة', Icons.event_busy_outlined, Colors.indigo);
    }
  }
}
