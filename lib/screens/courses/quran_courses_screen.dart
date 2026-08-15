import 'package:flutter/material.dart';

import '../../models/quran_course.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';

class QuranCoursesScreen extends StatefulWidget {
  const QuranCoursesScreen({super.key});

  @override
  State<QuranCoursesScreen> createState() => _QuranCoursesScreenState();
}

class _QuranCoursesScreenState extends State<QuranCoursesScreen> {
  final DatabaseService _db = DatabaseService();
  List<QuranCourse> _courses = [];
  List<Student> _students = [];
  Map<String, List<QuranCourseEnrollment>> _enrollments = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.getQuranCourses(),
        _db.getStudents(status: 'active'),
        _db.getAllQuranCourseEnrollments(),
      ]);
      final enrollments = <String, List<QuranCourseEnrollment>>{};
      for (final item in results[2] as List<QuranCourseEnrollment>) {
        enrollments.putIfAbsent(item.courseId, () => []).add(item);
      }
      if (!mounted) return;
      setState(() {
        _courses = results[0] as List<QuranCourse>;
        _students = results[1] as List<Student>;
        _enrollments = enrollments;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل الدورات: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دورات الحفظ والمراجعة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 90),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) => _courseCard(_courses[index]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        icon: const Icon(Icons.add),
        label: const Text('دورة جديدة'),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.event_repeat_outlined,
                size: 54,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              const Text(
                'لا توجد دورات بعد',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'أنشئ دورة محددة المدة للحفظ أو المراجعة، وحدد أيام الدراسة والمقرر والطلاب المشاركين.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () => _showEditor(),
                icon: const Icon(Icons.add),
                label: const Text('إنشاء أول دورة'),
              ),
            ],
          ),
        ),
      );

  Widget _courseCard(QuranCourse course) {
    final scheme = Theme.of(context).colorScheme;
    final enrolled = _enrollments[course.id] ?? const <QuranCourseEnrollment>[];
    final studyDays = _countStudyDays(course);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon(course.type), color: scheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(course.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        '${_date(course.startDate)} — ${_date(course.endDate)} · $studyDays يوم دراسة',
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _statusChip(course.status),
                PopupMenuButton<String>(
                  tooltip: 'خيارات الدورة',
                  onSelected: (value) {
                    if (value == 'edit') _showEditor(course);
                    if (value == 'delete') _delete(course);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل')),
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _infoChip(_typeLabel(course.type), Icons.alt_route_outlined),
                _infoChip('${enrolled.length} طلاب', Icons.people_outline),
                if (course.includesMemorization)
                  _infoChip(
                    'حفظ ${course.memorizationAmount} ${_unitLabel(course.memorizationUnit)} يوميًا',
                    Icons.menu_book_outlined,
                  ),
                if (course.includesRevision)
                  _infoChip(
                    'مراجعة ${course.revisionAmount} ${_unitLabel(course.revisionUnit)} يوميًا',
                    Icons.replay_outlined,
                  ),
              ],
            ),
            if (course.notes?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 9),
              Text(
                course.notes!.trim(),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(String text, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(text, style: const TextStyle(fontSize: 10.5)),
          ],
        ),
      );

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'active' => ('نشطة', Theme.of(context).colorScheme.primary),
      'completed' => ('مكتملة', Colors.blueGrey),
      'cancelled' => ('ملغاة', Theme.of(context).colorScheme.error),
      _ => ('مخططة', Theme.of(context).colorScheme.secondary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Future<void> _showEditor([QuranCourse? existing]) async {
    final titleController = TextEditingController(text: existing?.title ?? '');
    final memAmountController = TextEditingController(text: '${existing?.memorizationAmount ?? 5}');
    final revAmountController = TextEditingController(text: '${existing?.revisionAmount ?? 2}');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String type = existing?.type ?? 'mixed';
    String memUnit = existing?.memorizationUnit ?? 'ayahs';
    String revUnit = existing?.revisionUnit ?? 'pages';
    String status = existing?.status ?? 'planned';
    DateTime start = existing?.startDate ?? DateTime.now();
    DateTime end = existing?.endDate ?? DateTime.now().add(const Duration(days: 30));
    final weekdays = <int>{...(existing?.studyWeekdays ?? const [7, 1, 2, 3, 4])};
    final selectedStudents = <String>{
      if (existing != null)
        ...(_enrollments[existing.id] ?? const <QuranCourseEnrollment>[])
            .where((item) => item.status != 'withdrawn')
            .map((item) => item.studentId),
    };

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'دورة قرآنية جديدة' : 'تعديل الدورة'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'اسم الدورة'),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    children: [
                      _choice('حفظ', 'memorization', type, (v) => setDialogState(() => type = v)),
                      _choice('مراجعة', 'revision', type, (v) => setDialogState(() => type = v)),
                      _choice('حفظ + مراجعة', 'mixed', type, (v) => setDialogState(() => type = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.date_range_outlined),
                    title: Text('${_date(start)} — ${_date(end)}'),
                    subtitle: const Text('مدة الدورة'),
                    trailing: const Icon(Icons.edit_calendar_outlined),
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: dialogContext,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 3650)),
                        initialDateRange: DateTimeRange(start: start, end: end),
                      );
                      if (range != null) {
                        setDialogState(() {
                          start = range.start;
                          end = range.end;
                        });
                      }
                    },
                  ),
                  const Text('أيام الدراسة', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: List.generate(7, (index) {
                      final day = index + 1;
                      return FilterChip(
                        label: Text(_weekdayLabel(day)),
                        selected: weekdays.contains(day),
                        onSelected: (selected) => setDialogState(() {
                          if (selected) {
                            weekdays.add(day);
                          } else if (weekdays.length > 1) {
                            weekdays.remove(day);
                          }
                        }),
                      );
                    }),
                  ),
                  if (type != 'revision') ...[
                    const SizedBox(height: 12),
                    _targetRow(
                      label: 'مقرر الحفظ اليومي',
                      unit: memUnit,
                      amountController: memAmountController,
                      onUnitChanged: (value) => setDialogState(() => memUnit = value),
                    ),
                  ],
                  if (type != 'memorization') ...[
                    const SizedBox(height: 12),
                    _targetRow(
                      label: 'مقرر المراجعة اليومي',
                      unit: revUnit,
                      amountController: revAmountController,
                      onUnitChanged: (value) => setDialogState(() => revUnit = value),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'حالة الدورة'),
                    items: const [
                      DropdownMenuItem(value: 'planned', child: Text('مخططة')),
                      DropdownMenuItem(value: 'active', child: Text('نشطة')),
                      DropdownMenuItem(value: 'completed', child: Text('مكتملة')),
                      DropdownMenuItem(value: 'cancelled', child: Text('ملغاة')),
                    ],
                    onChanged: (value) => setDialogState(() => status = value ?? status),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('الطلاب المشاركون', style: TextStyle(fontWeight: FontWeight.w600))),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          if (selectedStudents.length == _students.length) {
                            selectedStudents.clear();
                          } else {
                            selectedStudents
                              ..clear()
                              ..addAll(_students.map((student) => student.id));
                          }
                        }),
                        child: Text(selectedStudents.length == _students.length ? 'إلغاء الكل' : 'تحديد الكل'),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: _students.map((student) => FilterChip(
                      label: Text(student.name),
                      selected: selectedStudents.contains(student.id),
                      onSelected: (selected) => setDialogState(() {
                        if (selected) {
                          selectedStudents.add(student.id);
                        } else {
                          selectedStudents.remove(student.id);
                        }
                      }),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'ملاحظات الدورة'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );

    if (saved == true) {
      final title = titleController.text.trim();
      final memAmount = int.tryParse(memAmountController.text.trim()) ?? 0;
      final revAmount = int.tryParse(revAmountController.text.trim()) ?? 0;
      final memorizationTargetInvalid = type != 'revision' && memAmount < 1;
      final revisionTargetInvalid = type != 'memorization' && revAmount < 1;
      if (title.isEmpty ||
          memorizationTargetInvalid ||
          revisionTargetInvalid ||
          selectedStudents.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('أكمل اسم الدورة والمقررات واختر طالبًا واحدًا على الأقل')),
          );
        }
      } else {
        final course = QuranCourse(
          id: existing?.id,
          title: title,
          type: type,
          startDate: start,
          endDate: end,
          memorizationUnit: memUnit,
          memorizationAmount: memAmount,
          revisionUnit: revUnit,
          revisionAmount: revAmount,
          studyWeekdays: weekdays.toList()..sort(),
          status: status,
          notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          createdAt: existing?.createdAt,
        );
        try {
          await _db.saveQuranCourse(course, studentIds: selectedStudents.toList());
          if (mounted) await _load();
        } catch (error) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('تعذر حفظ الدورة: $error')),
            );
          }
        }
      }
    }

    titleController.dispose();
    memAmountController.dispose();
    revAmountController.dispose();
    notesController.dispose();
  }

  Widget _choice(String label, String value, String current, ValueChanged<String> onChanged) => ChoiceChip(
        label: Text(label),
        selected: current == value,
        onSelected: (selected) {
          if (selected) onChanged(value);
        },
      );

  Widget _targetRow({
    required String label,
    required String unit,
    required TextEditingController amountController,
    required ValueChanged<String> onUnitChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            SizedBox(
              width: 90,
              child: TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الكمية'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'الوحدة'),
                items: const [
                  DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                  DropdownMenuItem(value: 'lines', child: Text('أسطر')),
                  DropdownMenuItem(value: 'pages', child: Text('أوجه / صفحات')),
                  DropdownMenuItem(value: 'hizbs', child: Text('أحزاب')),
                ],
                onChanged: (value) {
                  if (value != null) onUnitChanged(value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _delete(QuranCourse course) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدورة'),
        content: Text('حذف «${course.title}» وتسجيلات الطلاب في هذه الدورة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirm != true) return;
    await _db.deleteQuranCourse(course.id);
    if (mounted) await _load();
  }

  int _countStudyDays(QuranCourse course) {
    var count = 0;
    for (var date = DateTime(course.startDate.year, course.startDate.month, course.startDate.day);
        !date.isAfter(course.endDate);
        date = date.add(const Duration(days: 1))) {
      if (course.studyWeekdays.contains(date.weekday)) count++;
    }
    return count;
  }

  IconData _typeIcon(String type) => switch (type) {
        'memorization' => Icons.menu_book_outlined,
        'revision' => Icons.replay_outlined,
        _ => Icons.sync_alt_outlined,
      };

  String _typeLabel(String type) => switch (type) {
        'memorization' => 'دورة حفظ',
        'revision' => 'دورة مراجعة',
        _ => 'حفظ ومراجعة',
      };

  String _unitLabel(String unit) => switch (unit) {
        'lines' => 'سطر',
        'pages' => 'وجه',
        'hizbs' => 'حزب',
        _ => 'آية',
      };

  String _weekdayLabel(int day) => switch (day) {
        1 => 'الاثنين',
        2 => 'الثلاثاء',
        3 => 'الأربعاء',
        4 => 'الخميس',
        5 => 'الجمعة',
        6 => 'السبت',
        _ => 'الأحد',
      };

  String _date(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}
