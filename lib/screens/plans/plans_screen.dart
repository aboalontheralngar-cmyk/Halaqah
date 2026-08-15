import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../models/exam.dart';
import '../../models/plan.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/plan_progress_service.dart';
import '../../services/review_plan_policy.dart';
import '../../services/smart_plan_schedule_service.dart';
import '../../services/student_learning_policy.dart';
import '../../utils/helpers.dart';
import 'plan_recitation_screen.dart';

class PlansScreen extends StatefulWidget {
  const PlansScreen({super.key});

  @override
  State<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends State<PlansScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  late final PlanProgressService _progressService =
      PlanProgressService(database: _db);
  late final SmartPlanScheduleService _scheduleService =
      SmartPlanScheduleService(database: _db);
  List<SmartPlan> _plans = [];
  List<Student> _students = [];
  Map<String, SmartPlanProgress> _progressByPlan = {};
  bool _isLoading = true;
  bool _isBulkCreating = false;
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
        _db.getStudents(status: 'graduated'),
      ]);
      final plans = values[0] as List<SmartPlan>;
      final studentsById = <String, Student>{
        for (final student in values[1] as List<Student>) student.id: student,
        for (final student in values[2] as List<Student>) student.id: student,
      };
      final students = studentsById.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final progressEntries = await Future.wait(
        plans.map((plan) async {
          final student = studentsById[plan.studentId];
          if (student == null) return null;
          try {
            final progress = await _progressService.calculate(
              plan: plan,
              student: student,
            );
            return MapEntry(plan.id, progress);
          } catch (_) {
            return null;
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _students = students;
        _progressByPlan = {
          for (final entry in progressEntries.whereType<MapEntry<String, SmartPlanProgress>>())
            entry.key: entry.value,
        };
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
    var reviewUnit = existing?.reviewUnit ?? unit;
    var newAmount = existing?.newAmount ?? 5;
    var reviewAmount = existing?.reviewAmount ?? 10;
    var recitationAmount = existing?.recitationAmount ?? 1;
    var startDate = existing?.startDate ?? _day(DateTime.now());
    var endDate = existing?.endDate ?? _day(DateTime.now()).add(const Duration(days: 6));
    var notes = existing?.notes ?? '';
    String? gateReason;
    ReviewPlanRecommendation? reviewRecommendation = existing == null
        ? null
        : ReviewPlanPolicy.recommend(
            _student(existing.studentId)?.totalMemorized ?? 0,
          );
    final formKey = GlobalKey<FormState>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final selectedStudent =
              studentId == null ? null : _student(studentId!);
          final revisionOnly = selectedStudent != null &&
              StudentLearningPolicy.hasCompletedQuran(selectedStudent);
          return Container(
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
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.alt_route_outlined, size: 18, color: Colors.teal),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تبدأ الخطة من آخر موضع تسميع فعلي للطالب، حتى لو انتهت الفترة السابقة قبل إكمال جميع بنودها.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: studentId,
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
                          final selected = value == null ? null : _student(value);
                          if (selected != null) {
                            unit = selected.planType;
                            reviewUnit = selected.reviewPlanType;
                            newAmount = selected.planAmount;
                            reviewAmount = selected.reviewPlanAmount;
                            reviewRecommendation = ReviewPlanPolicy.recommend(
                              selected.totalMemorized,
                            );
                          }
                          final reason = value == null
                              ? null
                              : await _db.getSmartPlanGateReason(value);
                          if (context.mounted) {
                            setSheetState(() {
                              gateReason = reason;
                            });
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
                  initialValue: unit,
                  decoration: const InputDecoration(
                    labelText: 'وحدة الحفظ والسرد',
                    prefixIcon: Icon(Icons.straighten),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                    DropdownMenuItem(value: 'pages', child: Text('صفحات')),
                    DropdownMenuItem(value: 'lines', child: Text('أسطر')),
                    DropdownMenuItem(value: 'hizbs', child: Text('أحزاب')),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => unit = value);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: reviewUnit,
                  decoration: const InputDecoration(
                    labelText: 'وحدة المراجعة',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                    DropdownMenuItem(value: 'pages', child: Text('أوجه/صفحات')),
                    DropdownMenuItem(value: 'lines', child: Text('أسطر')),
                    DropdownMenuItem(value: 'hizbs', child: Text('أحزاب')),
                  ],
                  onChanged: (value) {
                    if (value != null) setSheetState(() => reviewUnit = value);
                  },
                ),
                const SizedBox(height: 14),
                if (revisionOnly) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.workspace_premium_outlined,
                            color: Colors.amber),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذا الطالب خاتم للقرآن؛ الخطة مخصصة للمراجعة والسرد/التلاوة فقط.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _AmountStepper(
                    label: 'مقرر الحفظ اليومي (${_unitLabel(unit)})',
                    value: newAmount,
                    onChanged: (value) =>
                        setSheetState(() => newAmount = value),
                  ),
                  const SizedBox(height: 12),
                ],
                _AmountStepper(
                  label: 'مقرر المراجعة اليومي (${_unitLabel(reviewUnit)})',
                  value: reviewAmount,
                  onChanged: (value) => setSheetState(() => reviewAmount = value),
                ),
                if (reviewRecommendation != null) ...[
                  const SizedBox(height: 8),
                  Material(
                    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: Text(
                        'المقترح: ${reviewRecommendation!.amountForUnit(reviewUnit)} '
                        '${_unitLabel(reviewUnit)} يوميًا',
                      ),
                      subtitle: Text(
                        '${reviewRecommendation!.tierLabel} · دورة مراجعة تقارب 30 يومًا',
                      ),
                      trailing: TextButton(
                        onPressed: () => setSheetState(() {
                          reviewAmount = reviewRecommendation!.amountForUnit(reviewUnit);
                        }),
                        child: const Text('اعتماد'),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _AmountStepper(
                  label: 'مقرر السرد/التلاوة اليومي (${_unitLabel(unit)})',
                  value: recitationAmount,
                  onChanged: (value) =>
                      setSheetState(() => recitationAmount = value),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.skip_next, size: 18),
                      label: const Text('الأسبوع القادم'),
                      onPressed: () => setSheetState(() {
                        period = 'weekly';
                        startDate = _nextWeekStart(DateTime.now());
                        endDate = startDate.add(const Duration(days: 6));
                      }),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_outlined, size: 18),
                      label: const Text('الشهر القادم'),
                      onPressed: () => setSheetState(() {
                        period = 'monthly';
                        final now = DateTime.now();
                        startDate = DateTime(now.year, now.month + 1, 1);
                        endDate = DateTime(now.year, now.month + 2, 0);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
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
                            final candidate = existing == null
                                ? SmartPlan(
                                    studentId: studentId!,
                                    period: period,
                                    startDate: startDate,
                                    endDate: endDate,
                                    unit: unit,
                                    reviewUnit: reviewUnit,
                                    newAmount: newAmount,
                                    reviewAmount: reviewAmount,
                                    recitationAmount: recitationAmount,
                                    notes: notes.trim().isEmpty
                                        ? null
                                        : notes.trim(),
                                  )
                                : existing.copyWith(
                                  period: period,
                                  startDate: startDate,
                                  endDate: endDate,
                                  unit: unit,
                                  reviewUnit: reviewUnit,
                                  newAmount: newAmount,
                                  reviewAmount: reviewAmount,
                                  recitationAmount: recitationAmount,
                                  notes: notes.trim(),
                                  clearNotes: notes.trim().isEmpty,
                                );
                            final selectedStudent = _student(candidate.studentId);
                            if (selectedStudent == null) {
                              throw StateError('تعذر العثور على ملف الطالب');
                            }
                            // لا تُحفظ خطة عامة مبهمة: يجب نجاح إنشاء جدول
                            // السورة والآية لكل يوم أولًا.
                            await _scheduleService.generate(
                              plan: candidate,
                              student: selectedStudent,
                            );
                            if (existing == null) {
                              await _db.insertSmartPlan(candidate);
                            } else {
                              await _db.updateSmartPlan(candidate);
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
          );
        },
      ),
    );
  }

  Future<void> _adjustAmount(
    SmartPlan plan, {
    int newDelta = 0,
    int reviewDelta = 0,
    int recitationDelta = 0,
  }) async {
    try {
      await _db.updateSmartPlan(
        plan.copyWith(
          newAmount: (plan.newAmount + newDelta).clamp(1, 999).toInt(),
          reviewAmount: (plan.reviewAmount + reviewDelta).clamp(1, 999).toInt(),
          recitationAmount:
              (plan.recitationAmount + recitationDelta).clamp(1, 999).toInt(),
        ),
      );
      await _loadData();
    } catch (error) {
      _message(_cleanError(error), error: true);
    }
  }

  Future<void> _completePlan(SmartPlan plan) async {
    final progress = _progressByPlan[plan.id];
    final student = _student(plan.studentId);
    final revisionOnly = student != null &&
        StudentLearningPolicy.hasCompletedQuran(student);
    final confirmed = await _confirm(
      progress?.isAccomplished == true ? 'اعتماد إنجاز الخطة؟' : 'إنهاء فترة الخطة؟',
      progress?.isAccomplished == true
          ? revisionOnly
              ? 'أنجز الطالب المراجعة والسرد المقررين. بعد الاعتماد سيُلزم باختبار تجاوز قبل الخطة التالية.'
              : 'أنجز الطالب الحفظ والمراجعة والسرد المقررين. بعد الاعتماد سيُلزم باختبار تجاوز قبل الخطة التالية.'
          : 'الإنجاز المحسوب ${progress?.completionPercent ?? 0}%. سيُحفظ ما وصل إليه الطالب، وتبدأ الخطة التالية من آخر تسميع فعلي بعد اختبار التجاوز.',
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
      final assignments = await _scheduleService.generate(
        plan: plan,
        student: student,
      );
      final bytes = await _pdf.generateSmartPlan(
        student: student,
        plan: plan,
        halaqahName: settings.halaqahName,
        mosqueName: settings.mosqueName,
        cashier: cashier,
        holidayWeekdays: settings.holidayWeekdays,
        dailyAssignments: assignments,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } catch (error) {
      _message('تعذرت طباعة الخطة: $error', error: true);
    }
  }

  Future<void> _openPlanRecitation(SmartPlan plan) async {
    final student = _student(plan.studentId);
    if (student == null) {
      _message('تعذر العثور على ملف الطالب', error: true);
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => PlanRecitationScreen(
          plan: plan,
          student: student,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _createAndPrintAllPlans() async {
    if (_students.isEmpty || _isBulkCreating) return;
    var period = 'weekly';
    var startDate = _day(DateTime.now());
    var endDate = startDate.add(const Duration(days: 6));
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء خطط جميع الطلاب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'سيُستخدم مقرر الحفظ والمراجعة المحفوظ في ملف كل طالب، '
                'ويُنشأ للخاتم مقرر مراجعة وسرد فقط، '
                'وسيُتجاوز من لديه خطة نشطة أو ينتظر اختبار تجاوز.',
              ),
              const SizedBox(height: 14),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'weekly', label: Text('أسبوعية')),
                  ButtonSegment(value: 'monthly', label: Text('شهرية')),
                ],
                selected: {period},
                onSelectionChanged: (value) => setDialogState(() {
                  period = value.first;
                  endDate = startDate.add(
                    Duration(days: period == 'weekly' ? 6 : 29),
                  );
                }),
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.date_range_outlined),
                title: const Text('مدة الخطط'),
                subtitle: Text('${_date(startDate)} — ${_date(endDate)}'),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: dialogContext,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 730)),
                    initialDateRange: DateTimeRange(
                      start: startDate,
                      end: endDate,
                    ),
                  );
                  if (range == null) return;
                  setDialogState(() {
                    startDate = _day(range.start);
                    endDate = _day(range.end);
                    period = range.duration.inDays <= 7 ? 'weekly' : 'monthly';
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('إنشاء وطباعة'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBulkCreating = true);
    final created = <SmartPlan>[];
    final dailyAssignmentsByPlan =
        <String, List<SmartPlanDailyAssignment>>{};
    final skippedReasons = <String>[];
    try {
      final gateReasons = await _db.getSmartPlanGateReasons(
        _students.map((student) => student.id),
      );
      for (final student in _students) {
        final gate = gateReasons[student.id];
        if (gate != null) {
          skippedReasons.add('${student.name}: $gate');
          continue;
        }
        final plan = SmartPlan(
          studentId: student.id,
          period: period,
          startDate: startDate,
          endDate: endDate,
          unit: student.planType,
          reviewUnit: student.reviewPlanType,
          newAmount: student.planAmount,
          reviewAmount: student.reviewPlanAmount,
          recitationAmount: student.planAmount,
          notes: StudentLearningPolicy.hasCompletedQuran(student)
              ? 'خطة خاتم: مراجعة وسرد/تلاوة فقط'
              : 'أُنشئت تلقائيًا من المقرر الافتراضي في ملف الطالب',
        );
        try {
          final assignments = await _scheduleService.generate(
            plan: plan,
            student: student,
          );
          // التوليد يسبق الحفظ، فلا تنشأ في قاعدة البيانات خطة لا يمكن
          // طباعتها بنطاقات قرآنية يومية دقيقة.
          dailyAssignmentsByPlan[plan.id] = assignments;
          await _db.insertSmartPlan(plan);
          created.add(plan);
        } catch (error) {
          skippedReasons.add('${student.name}: ${_cleanError(error)}');
        }
      }
      if (created.isEmpty) {
        _message(
          skippedReasons.isEmpty
              ? 'لم تُنشأ خطط جديدة؛ جميع الطلاب لديهم خطط قائمة أو اختبار مطلوب'
              : 'لم تُنشأ أي خطة دقيقة. راجع نطاق المحفوظ في ملفات الطلاب.',
          error: true,
        );
        if (skippedReasons.isNotEmpty && mounted) {
          await _showBulkPlanIssues(skippedReasons);
        }
        return;
      }
      final settings = await _db.getSettings();
      final bytes = await _pdf.generateAllSmartPlans(
        students: _students,
        plans: created,
        halaqahName: settings.halaqahName,
        mosqueName: settings.mosqueName,
        holidayWeekdays: settings.holidayWeekdays,
        dailyAssignmentsByPlan: dailyAssignmentsByPlan,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
      await _loadData();
      _message(
        'تم إنشاء ${created.length} خطة دقيقة'
        '${skippedReasons.isEmpty ? '' : ' وتجاوز ${skippedReasons.length} طالبًا'}',
      );
      if (skippedReasons.isNotEmpty && mounted) {
        await _showBulkPlanIssues(skippedReasons);
      }
    } catch (error) {
      _message('تعذر إكمال الإنشاء الجماعي: ${_cleanError(error)}', error: true);
    } finally {
      if (mounted) setState(() => _isBulkCreating = false);
    }
  }

  Future<void> _showBulkPlanIssues(List<String> reasons) async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلاب يحتاجون استكمال البيانات'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: reasons.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (_, index) => Text('• ${reasons[index]}'),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePlans;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الخطط الأسبوعية والشهرية'),
        actions: [
          IconButton(
            onPressed: _isBulkCreating ? null : _createAndPrintAllPlans,
            tooltip: 'إنشاء وطباعة خطط جميع الطلاب',
            icon: _isBulkCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.library_add_check_outlined),
          ),
        ],
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
    final revisionOnly = student != null &&
        StudentLearningPolicy.hasCompletedQuran(student);
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
                  backgroundColor: status.color.withValues(alpha: 0.12),
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
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(status.label),
                  labelStyle: TextStyle(fontSize: 10, color: status.color),
                  backgroundColor: status.color.withValues(alpha: 0.08),
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
            if (revisionOnly) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'خاتم للقرآن · مسار مراجعة وسرد/تلاوة',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 8),
            ] else ...[
              _quickAmount(
                title: 'الحفظ اليومي',
                value: plan.newAmount,
                unit: plan.unit,
                enabled: plan.isActive,
                onMinus: () => _adjustAmount(plan, newDelta: -1),
                onPlus: () => _adjustAmount(plan, newDelta: 1),
              ),
              const SizedBox(height: 8),
            ],
            _quickAmount(
              title: 'المراجعة اليومية',
              value: plan.reviewAmount,
              unit: plan.unit,
              enabled: plan.isActive,
              onMinus: () => _adjustAmount(plan, reviewDelta: -1),
              onPlus: () => _adjustAmount(plan, reviewDelta: 1),
            ),
            const SizedBox(height: 8),
            _quickAmount(
              title: 'السرد/التلاوة اليومية',
              value: plan.recitationAmount,
              unit: plan.unit,
              enabled: plan.isActive,
              onMinus: () => _adjustAmount(plan, recitationDelta: -1),
              onPlus: () => _adjustAmount(plan, recitationDelta: 1),
            ),
            if (_progressByPlan[plan.id] != null) ...[
              const SizedBox(height: 12),
              _planProgressCard(
                _progressByPlan[plan.id]!,
                includeMemorization: !revisionOnly,
              ),
            ],
            if (plan.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 10),
              Text('ملاحظات: ${plan.notes}', style: const TextStyle(fontSize: 12)),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openPlanRecitation(plan),
                icon: const Icon(Icons.record_voice_over_outlined),
                label: Text(
                  plan.isActive
                      ? 'تسجيل السرد وعرض الجلسات'
                      : 'عرض سجل السرد',
                ),
              ),
            ),
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

  Widget _planProgressCard(
    SmartPlanProgress progress, {
    required bool includeMemorization,
  }) {
    final color = progress.isAccomplished
        ? Colors.green
        : progress.completionPercent >= 60
            ? Colors.orange
            : Colors.teal;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        border: Border.all(color: color.withValues(alpha: 0.32)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                progress.isAccomplished
                    ? Icons.verified_outlined
                    : Icons.donut_large_outlined,
                color: color,
                size: 19,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  progress.isAccomplished
                      ? 'الخطة منجزة حسابيًا'
                      : 'نسبة إنجاز الخطة ${progress.completionPercent}%',
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
              ),
              Text('${progress.requiredStudyDays} يوم دراسي'),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.completionPercent / 100,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.14),
          ),
          const SizedBox(height: 7),
          Text(
            'تُحدّث النسبة تلقائيًا من سجلات التسميع المنفذة والمدخلة داخل مدة الخطة.',
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (includeMemorization)
                _progressAxis(
                  'الحفظ',
                  progress.actualMemorization,
                  progress.requiredMemorization,
                ),
              _progressAxis(
                'المراجعة',
                progress.actualReview,
                progress.requiredReview,
              ),
              _progressAxis(
                'السرد',
                progress.actualRecitation,
                progress.requiredRecitation,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _progressAxis(String label, double actual, double required) {
    final percent = required <= 0
        ? 0
        : ((actual / required).clamp(0, 1) * 100).round();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$label $percent% · ${actual.toStringAsFixed(1)}/${required.toStringAsFixed(1)}',
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _warningBox(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
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
    if (unit == 'hizbs') return 'حزب';
    return 'آية';
  }

  DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

  DateTime _nextWeekStart(DateTime value) {
    final day = _day(value);
    final daysUntilSaturday = (DateTime.saturday - day.weekday + 7) % 7;
    return day.add(Duration(days: daysUntilSaturday == 0 ? 7 : daysUntilSaturday));
  }

  String _date(DateTime date) => Helpers.formatPlanDate(date);

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
