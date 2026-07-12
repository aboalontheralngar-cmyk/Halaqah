import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:printing/printing.dart';

import '../../models/exam.dart';
import '../../models/plan.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  List<SmartPlan> _plans = [];
  List<Student> _students = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _isLoading = true);
    try {
      final values = await Future.wait<dynamic>([
        _db.getSmartPlans(),
        _db.getStudents(status: 'active'),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = values[0] as List<SmartPlan>;
        _students = values[1] as List<Student>;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _message('تعذر تحميل الخطط: $error', error: true);
    }
  }

  List<SmartPlan> get _visiblePlans => _plans.where((plan) {
        if (_filter == 'active') return plan.isActive;
        if (_filter == 'exam') return plan.isWaitingForExam;
        if (_filter == 'completed') {
          return plan.isCompleted && plan.testStatus == 'passed';
        }
        return true;
      }).toList();

  Future<void> _showPlanSheet({SmartPlan? existing}) async {
    var studentId = existing?.studentId;
    var period = existing?.period ?? 'weekly';
    var unit = existing?.unit ?? 'ayahs';
    var newAmount = existing?.newAmount ?? 5;
    var reviewAmount = existing?.reviewAmount ?? 10;
    var startDate = existing?.startDate ?? _day(DateTime.now());
    var endDate = existing?.endDate ?? _day(DateTime.now()).add(const Duration(days: 6));
    var notes = existing?.notes ?? '';
    String? gateReason;
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.92,
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            18,
            20,
            MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: formKey,
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        existing == null ? 'إنشاء خطة للطالب' : 'تعديل الخطة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: studentId,
                  decoration: const InputDecoration(
                    labelText: 'الطالب',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  items: _students
                      .map(
                        (student) => DropdownMenuItem(
                          value: student.id,
                          child: Text(student.name),
                        ),
                      )
                      .toList(),
                  onChanged: existing != null
                      ? null
                      : (value) async {
                          studentId = value;
                          final reason = value == null
                              ? null
                              : await _db.getSmartPlanGateReason(value);
                          if (context.mounted) {
                            setSheetState(() => gateReason = reason);
                          }
                        },
                  validator: (value) => value == null ? 'اختر الطالب' : null,
                ),
                if (gateReason != null) ...[
                  const SizedBox(height: 8),
                  _warningBox(gateReason!),
                ],
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'weekly', label: Text('أسبوعية')),
                    ButtonSegment(value: 'monthly', label: Text('شهرية')),
                  ],
                  selected: {period},
                  onSelectionChanged: (values) {
                    setSheetState(() {
                      period = values.first;
                      endDate = startDate.add(
                        Duration(days: period == 'weekly' ? 6 : 29),
                      );
                    });
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: unit,
                  decoration: const InputDecoration(
                    labelText: 'وحدة المقرر',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                    DropdownMenuItem(value: 'pages', child: Text('صفحات')),
                    DropdownMenuItem(value: 'lines', child: Text('أسطر')),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => unit = value);
                  },
                ),
                const SizedBox(height: 14),
                _AmountStepper(
                  label: 'مقرر الحفظ اليومي (${_unitLabel(unit)})',
                  value: newAmount,
                  onChanged: (value) => setSheetState(() => newAmount = value),
                ),
                const SizedBox(height: 12),
                _AmountStepper(
                  label: 'مقرر المراجعة اليومي (${_unitLabel(unit)})',
                  value: reviewAmount,
                  onChanged: (value) => setSheetState(() => reviewAmount = value),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.date_range),
                  title: const Text('مدة الخطة'),
                  subtitle: Text('${_date(startDate)} — ${_date(endDate)}'),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: () async {
                    final selected = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                      initialDateRange: DateTimeRange(
                        start: startDate,
                        end: endDate,
                      ),
                    );
                    if (selected != null) {
                      setSheetState(() {
                        startDate = selected.start;
                        endDate = selected.end;
                        period = selected.duration.inDays <= 7
                            ? 'weekly'
                            : 'monthly';
                      });
                    }
                  },
                ),
                TextFormField(
                  initialValue: notes,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'التوجيهات والملاحظات',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  onChanged: (value) => notes = value,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: gateReason != null && existing == null
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          try {
                            if (existing == null) {
                              await _db.insertSmartPlan(
                                SmartPlan(
                                  studentId: studentId!,
                                  period: period,
                                  startDate: startDate,
                                  endDate: endDate,
                                  unit: unit,
                                  newAmount: newAmount,
                                  reviewAmount: reviewAmount,
                                  notes: notes.trim().isEmpty ? null : notes.trim(),
                                ),
                              );
                            } else {
                              await _db.updateSmartPlan(
                                existing.copyWith(
                                  period: period,
                                  startDate: startDate,
                                  endDate: endDate,
                                  unit: unit,
                                  newAmount: newAmount,
                                  reviewAmount: reviewAmount,
                                  notes: notes.trim(),
                                  clearNotes: notes.trim().isEmpty,
                                ),
                              );
                            }
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            await _loadData();
                            _message(existing == null
                                ? 'تم إنشاء الخطة وتحديث مقرر الطالب'
                                : 'تم تعديل الخطة');
                          } catch (error) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(content: Text(_cleanError(error))),
                              );
                            }
                          }
                        },
                  icon: Icon(existing == null ? Icons.add_task : Icons.save),
                  label: Text(existing == null ? 'إنشاء الخطة' : 'حفظ التعديل'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _adjustAmount(
    SmartPlan plan, {
    int newDelta = 0,
    int reviewDelta = 0,
  }) async {
    try {
      await _db.updateSmartPlan(
        plan.copyWith(
          newAmount: (plan.newAmount + newDelta).clamp(1, 999).toInt(),
          reviewAmount: (plan.reviewAmount + reviewDelta).clamp(1, 999).toInt(),
        ),
      );
      await _loadData();
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  Future<void> _completePlan(SmartPlan plan) async {
    final confirmed = await _confirm(
      'إكمال الخطة؟',
      'بعد الإكمال سيُلزم الطالب باجتياز اختبار تجاوز قبل إنشاء خطة جديدة.',
    );
    if (!confirmed) return;
    await _db.completeSmartPlan(plan);
    await _loadData();
    _message('اكتملت الخطة وأصبحت بانتظار اختبار التجاوز');
  }

  Future<void> _cancelPlan(SmartPlan plan) async {
    final confirmed = await _confirm(
      'إلغاء الخطة؟',
      'ستبقى الخطة محفوظة في السجل بحالة ملغاة.',
    );
    if (!confirmed) return;
    await _db.updateSmartPlan(
      plan.copyWith(status: 'cancelled', testStatus: 'not_required'),
    );
    await _loadData();
  }

  Future<void> _approveExam(SmartPlan plan) async {
    final exams = await _db.getStudentExams(plan.studentId);
    final boundary = _day(plan.completedAt ?? plan.endDate);
    final eligible = exams
        .where((exam) => exam.isPassed && !_day(exam.date).isBefore(boundary))
        .toList();
    if (!mounted) return;
    if (eligible.isEmpty) {
      _message(
        'لا يوجد اختبار ناجح بعد إكمال الخطة. سجّل نتيجة اختبار التجاوز أولًا.',
        error: true,
      );
      return;
    }
    final exam = await showDialog<Exam>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد اختبار التجاوز'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: eligible
                .map(
                  (item) => ListTile(
                    leading: const Icon(Icons.verified, color: Colors.green),
                    title: Text('${item.score}% — ${item.scoreGrade}'),
                    subtitle: Text(
                      '${_date(item.date)} · من سورة ${item.fromSurah} إلى ${item.toSurah}',
                    ),
                    onTap: () => Navigator.pop(context, item),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (exam == null) return;
    try {
      await _db.approveSmartPlanExam(plan, exam);
      await _loadData();
      _message('تم اعتماد اختبار التجاوز، ويمكن إنشاء الخطة التالية');
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  Future<void> _deletePlan(SmartPlan plan) async {
    final confirmed = await _confirm(
      'حذف الخطة؟',
      'سيُحذف هذا السجل من الجهاز ومن السحابة عند المزامنة التالية.',
    );
    if (!confirmed) return;
    await _db.deleteSmartPlan(plan);
    await _loadData();
  }

  Future<void> _printPlan(SmartPlan plan, {required bool cashier}) async {
    final student = _student(plan.studentId);
    if (student == null) return;
    try {
      final settings = await _db.getSettings();
      final bytes = await _pdf.generateSmartPlan(
        student: student,
        plan: plan,
        halaqahName: settings.halaqahName,
        mosqueName: settings.mosqueName,
        cashier: cashier,
        holidayWeekdays: settings.holidayWeekdays,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      _message('تعذرت طباعة الخطة: $error', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePlans;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطط الأسبوعية والشهرية'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPlanSheet(),
        icon: const Icon(Icons.playlist_add),
        label: const Text('خطة جديدة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildOverview(),
                SizedBox(
                  height: 52,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _filterChip('الكل', 'all'),
                      _filterChip('نشطة', 'active'),
                      _filterChip('بانتظار الاختبار', 'exam'),
                      _filterChip('مجتازة', 'completed'),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(child: Text('لا توجد خطط مطابقة'))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 4, 12, 90),
                            itemCount: visible.length,
                            itemBuilder: (context, index) =>
                                _buildPlanCard(visible[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildOverview() {
    final active = _plans.where((plan) => plan.isActive).length;
    final waiting = _plans.where((plan) => plan.isWaitingForExam).length;
    final passed = _plans
        .where((plan) => plan.isCompleted && plan.testStatus == 'passed')
        .length;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _stat('نشطة', active, Colors.teal),
            _stat('بانتظار اختبار', waiting, Colors.orange),
            _stat('مجتازة', passed, Colors.green),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, int value, Color color) => Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _filterChip(String label, String value) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: _filter == value,
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _buildPlanCard(SmartPlan plan) {
    final student = _student(plan.studentId);
    final status = _status(plan);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: status.color.withOpacity(0.12),
                  child: Icon(status.icon, color: status.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student?.name ?? 'طالب غير متاح',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${plan.period == 'weekly' ? 'أسبوعية' : 'شهرية'} · ${_date(plan.startDate)} — ${_date(plan.endDate)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(status.label),
                  labelStyle: TextStyle(fontSize: 10, color: status.color),
                  backgroundColor: status.color.withOpacity(0.08),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _showPlanSheet(existing: plan);
                    if (action == 'a4') _printPlan(plan, cashier: false);
                    if (action == 'cashier') _printPlan(plan, cashier: true);
                    if (action == 'delete') _deletePlan(plan);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل الخطة')),
                    PopupMenuItem(value: 'a4', child: Text('طباعة A4')),
                    PopupMenuItem(value: 'cashier', child: Text('طباعة كاشير 80مم')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف الخطة', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 22),
            _quickAmount(
              title: 'الحفظ اليومي',
              value: plan.newAmount,
              unit: plan.unit,
              enabled: plan.isActive,
              onMinus: () => _adjustAmount(plan, newDelta: -1),
              onPlus: () => _adjustAmount(plan, newDelta: 1),
            ),
            const SizedBox(height: 8),
            _quickAmount(
              title: 'المراجعة اليومية',
              value: plan.reviewAmount,
              unit: plan.unit,
              enabled: plan.isActive,
              onMinus: () => _adjustAmount(plan, reviewDelta: -1),
              onPlus: () => _adjustAmount(plan, reviewDelta: 1),
            ),
            if (plan.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text('ملاحظات: ${plan.notes}', style: const TextStyle(fontSize: 12)),
            ],
            if (plan.isWaitingForExam) ...[
              const SizedBox(height: 10),
              _warningBox(
                plan.testStatus == 'failed'
                    ? 'لم يجتز الطالب الاختبار؛ يلزم اختبار ناجح قبل الخطة التالية.'
                    : 'اكتملت الخطة وتنتظر ربط اختبار تجاوز ناجح.',
              ),
            ],
            const SizedBox(height: 12),
            if (plan.isActive)
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _cancelPlan(plan),
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _completePlan(plan),
                      icon: const Icon(Icons.task_alt),
                      label: const Text('إكمال وطلب اختبار تجاوز'),
                    ),
                  ),
                ],
              )
            else if (plan.isWaitingForExam)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _approveExam(plan),
                  icon: const Icon(Icons.verified),
                  label: const Text('اعتماد اختبار التجاوز'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _quickAmount({
    required String title,
    required int value,
    required String unit,
    required bool enabled,
    required VoidCallback onMinus,
    required VoidCallback onPlus,
  }) =>
      Row(
        children: [
          Expanded(child: Text(title)),
          IconButton(
            onPressed: enabled && value > 1 ? onMinus : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 88,
            child: Text(
              '$value ${_unitLabel(unit)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: enabled ? onPlus : null,
            icon: const Icon(Icons.add_circle, color: Colors.teal),
          ),
        ],
      );

  Widget _warningBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_clock, color: Colors.orange, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('رجوع'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('تأكيد'),
            ),
          ],
        ),
      ) ??
      false;

  Student? _student(String id) {
    for (final student in _students) {
      if (student.id == id) return student;
    }
    return null;
  }

  ({String label, Color color, IconData icon}) _status(SmartPlan plan) {
    if (plan.status == 'cancelled') {
      return (label: 'ملغاة', color: Colors.red, icon: Icons.cancel_outlined);
    }
    if (plan.isWaitingForExam) {
      return (label: 'بانتظار الاختبار', color: Colors.orange, icon: Icons.quiz);
    }
    if (plan.isCompleted && plan.testStatus == 'passed') {
      return (label: 'مجتازة', color: Colors.green, icon: Icons.verified);
    }
    if (plan.isCompleted) {
      return (label: 'مكتملة قديمة', color: Colors.grey, icon: Icons.history);
    }
    return (label: 'نشطة', color: Colors.teal, icon: Icons.track_changes);
  }

  String _unitLabel(String unit) {
    if (unit == 'pages') return 'صفحة';
    if (unit == 'lines') return 'سطر';
    return 'آية';
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  String _date(DateTime date) => intl.DateFormat('yyyy/MM/dd').format(date);

  String _cleanError(Object error) =>
      error.toString().replaceFirst('Bad state: ', '').replaceFirst('Invalid argument(s): ', '');

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }
}

class _AmountStepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  const _AmountStepper({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label),
      child: Row(
        children: [
          IconButton(
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Expanded(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle, color: Colors.teal),
          ),
        ],
      ),
    );
  }
}
