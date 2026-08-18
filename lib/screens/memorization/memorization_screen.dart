import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../../models/daily_record.dart';
import '../../models/quran_course.dart';
import '../../models/student.dart';
import '../../models/student_hold.dart';
import '../../services/database_service.dart';
import '../../services/student_learning_policy.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_design_widgets.dart';
import 'add_memorization_screen.dart';
import 'recitation_history_screen.dart';
import 'recitation_screen.dart';
import 'revision_screen.dart';
import 'student_memorization_view.dart';
import 'talaqqin_screen.dart';

class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key});

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen> {
  final DatabaseService _db = DatabaseService();
  List<Student> _students = [];
  Map<String, DailyRecord> _todayRecords = {};
  Map<String, StudentHold> _activeHolds = {};
  Map<String, QuranCourse> _todayCourseByStudent = {};
  bool _isLoading = true;
  String _filter = 'all';
  String _sortBy = 'manual';
  List<String> _manualOrder = <String>[];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.getStudents(status: 'active'),
        _db.getStudents(status: 'graduated'),
        _db.getDailyRecordsForDate(DateTime.now()),
        _db.getActiveStudentHolds(),
        _db.getSetting('recitation_manual_order'),
        _db.getQuranCourses(),
        _db.getAllQuranCourseEnrollments(),
      ]);
      final studentGroups = [
        results[0] as List<Student>,
        results[1] as List<Student>,
      ];
      final studentsById = <String, Student>{
        for (final group in studentGroups)
          for (final student in group) student.id: student,
      };
      final students = studentsById.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      final records = results[2] as List<DailyRecord>;
      final holds = results[3] as List<StudentHold>;
      final storedOrder = results[4] as String?;
      final courses = results[5] as List<QuranCourse>;
      final enrollments = results[6] as List<QuranCourseEnrollment>;
      final today = DateTime.now();
      final todayKey = DateTime(today.year, today.month, today.day);
      final activeCoursesById = <String, QuranCourse>{
        for (final course in courses)
          if (course.status == 'active' &&
              !todayKey.isBefore(
                DateTime(
                  course.startDate.year,
                  course.startDate.month,
                  course.startDate.day,
                ),
              ) &&
              !todayKey.isAfter(
                DateTime(
                  course.endDate.year,
                  course.endDate.month,
                  course.endDate.day,
                ),
              ) &&
              course.studyWeekdays.contains(today.weekday))
            course.id: course,
      };
      final courseByStudent = <String, QuranCourse>{};
      for (final enrollment
          in enrollments.where((item) => item.status == 'active')) {
        final course = activeCoursesById[enrollment.courseId];
        if (course != null) {
          courseByStudent.putIfAbsent(enrollment.studentId, () => course);
        }
      }

      final recordsMap = <String, DailyRecord>{};
      for (final record in records) {
        recordsMap[record.studentId] = record;
      }

      final parsedOrder = <String>[];
      if (storedOrder != null && storedOrder.isNotEmpty) {
        try {
          final raw = jsonDecode(storedOrder);
          if (raw is List) {
            parsedOrder.addAll(raw.map((item) => item.toString()));
          }
        } catch (_) {
          // A legacy/corrupt order must not block the recitation workspace.
        }
      }
      final studentIds = students.map((student) => student.id).toSet();
      parsedOrder.removeWhere((id) => !studentIds.contains(id));
      for (final student in students) {
        if (!parsedOrder.contains(student.id)) parsedOrder.add(student.id);
      }

      if (!mounted) return;
      setState(() {
        _students = students;
        _manualOrder = parsedOrder;
        _todayRecords = recordsMap;
        _activeHolds = {for (final hold in holds) hold.studentId: hold};
        _todayCourseByStudent = courseByStudent;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Student> _filteredStudents() {
    var list = _students.where(_hasRecitationAction).toList();
    if (_filter != 'all') {
      list = list.where((student) {
        final completed = _isCoreWorkCompleted(
          student,
          _todayRecords[student.id],
        );
        return _filter == 'completed' ? completed : !completed;
      }).toList();
    }

    if (_sortBy == 'name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'memorized') {
      list.sort((a, b) => b.totalMemorized.compareTo(a.totalMemorized));
    } else {
      list.sort((a, b) => _manualIndex(a.id).compareTo(_manualIndex(b.id)));
    }
    return list;
  }

  bool _hasRecitationAction(Student student) =>
      StudentLearningPolicy.canReceiveNewMemorization(student) ||
      StudentLearningPolicy.canReceiveRevision(student) ||
      StudentLearningPolicy.canReceiveTalaqqin(student);

  bool _isCoreWorkCompleted(Student student, DailyRecord? record) {
    final states = <bool>[];
    if (StudentLearningPolicy.canReceiveNewMemorization(student)) {
      states.add(record?.memorizationDone == true);
    }
    if (StudentLearningPolicy.canReceiveRevision(student)) {
      states.add(record?.revisionDone == true);
    }
    if (states.isEmpty && StudentLearningPolicy.canReceiveTalaqqin(student)) {
      states.add(record?.talaqqinDone == true);
    }
    return states.isNotEmpty && states.every((done) => done);
  }

  int _manualIndex(String studentId) {
    final index = _manualOrder.indexOf(studentId);
    return index < 0 ? _manualOrder.length + 1 : index;
  }

  Future<void> _reorderVisibleStudents(
    int oldIndex,
    int newIndex,
    List<Student> visible,
  ) async {
    if (newIndex > oldIndex) newIndex -= 1;
    final reordered = List<Student>.from(visible);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final visibleIds = visible.map((student) => student.id).toSet();
    final master = List<String>.from(_manualOrder);
    for (final student in _students) {
      if (!master.contains(student.id)) master.add(student.id);
    }
    final positions = <int>[];
    for (var index = 0; index < master.length; index++) {
      if (visibleIds.contains(master[index])) positions.add(index);
    }
    for (var index = 0; index < positions.length; index++) {
      master[positions[index]] = reordered[index].id;
    }
    if (!mounted) return;
    setState(() => _manualOrder = master);
    await _db.saveSetting('recitation_manual_order', jsonEncode(master));
  }

  Widget _buildStudentList(List<Student> students) {
    if (_sortBy != 'manual' || _filter != 'all') {
      return ListView.builder(
        padding: AppSpacing.page,
        itemCount: students.length,
        itemBuilder: (context, index) => _buildStudentCard(students[index]),
      );
    }
    return ReorderableListView.builder(
      padding: AppSpacing.page,
      itemCount: students.length,
      buildDefaultDragHandles: true,
      onReorder: (oldIndex, newIndex) =>
          _reorderVisibleStudents(oldIndex, newIndex, students),
      itemBuilder: (context, index) {
        final student = students[index];
        return KeyedSubtree(
          key: ValueKey('recitation_order_${student.id}'),
          child: _buildStudentCard(student),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = _filteredStudents();
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسميع والتلقين'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              await Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecitationHistoryScreen(),
                ),
              );
              if (mounted) await _loadData();
            },
            tooltip: 'سجل التسميع والتعديل',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'الترتيب والتصفية',
            onSelected: (value) {
              setState(() {
                if (value.startsWith('sort_')) {
                  _sortBy = value.substring(5);
                } else {
                  _filter = value.substring(7);
                }
              });
            },
            itemBuilder: (context) => [
              _sortMenuItem('sort_manual', 'ترتيب يدوي بالسحب', Icons.drag_indicator),
              _sortMenuItem('sort_name', 'ترتيب أبجدي', Icons.sort_by_alpha),
              _sortMenuItem('sort_memorized', 'ترتيب حسب المحفوظ', Icons.star),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'filter_all',
                child: Text('عرض جميع الطلاب'),
              ),
              const PopupMenuItem(
                value: 'filter_completed',
                child: Text('المكتمل اليوم فقط'),
              ),
              const PopupMenuItem(
                value: 'filter_pending',
                child: Text('المتبقي اليوم فقط'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildWorkspaceSummary(),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Text(
                  'اسحب البطاقة يمينًا للحفظ، ويسارًا للمراجعة. بقية الإجراءات من ⋮',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : students.isEmpty
                      ? _buildEmptyState('لا يوجد طلاب مطابقون للتصفية')
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 880),
                              child: _buildStudentList(students),
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddMemorization(null),
        tooltip: 'إضافة حفظ مباشر',
        icon: const Icon(Icons.add_rounded),
        label: const Text('حفظ مباشر'),
      ),
    );
  }

  PopupMenuItem<String> _sortMenuItem(
    String value,
    String label,
    IconData icon,
  ) {
    final selected = _sortBy == value.substring(5);
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  Widget _buildWorkspaceSummary() {
    final eligible = _students.where(_hasRecitationAction).toList();
    final completed = eligible
        .where(
          (student) =>
              _isCoreWorkCompleted(student, _todayRecords[student.id]),
        )
        .length;
    final pending = eligible.length - completed;
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final progress = eligible.isEmpty
        ? 0.0
        : (completed / eligible.length).clamp(0.0, 1.0).toDouble();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.record_voice_over_outlined,
                    size: 19,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      Helpers.getFullHijriDate(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                  AppStatusPill(label: 'تم $completed', color: semantic.success),
                  const SizedBox(width: AppSpacing.xs),
                  AppStatusPill(label: 'باقٍ $pending', color: semantic.warning),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 5,
                  backgroundColor: scheme.surfaceContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final record = _todayRecords[student.id];
    final hold = _activeHolds[student.id];
    final canMemorize = StudentLearningPolicy.canReceiveNewMemorization(student);
    final canRevise = StudentLearningPolicy.canReceiveRevision(student);
    final canTalaqqin = StudentLearningPolicy.canReceiveTalaqqin(student);
    final memorizationDone = record?.memorizationDone == true;
    final revisionDone = record?.revisionDone == true;
    final course = _todayCourseByStudent[student.id];

    final card = Directionality(
      textDirection: TextDirection.rtl,
      child: Card(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: hold == null ? 1 : 0.58,
          child: ListTile(
            contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 7, 8, 7),
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.10),
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '؟',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    student.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildAttendanceBadge(record),
                _buildHoldBadge(student.id),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      if (canMemorize)
                        _statusTag(
                          memorizationDone ? 'الحفظ تم' : 'الحفظ',
                          memorizationDone ? Icons.check_circle : Icons.menu_book,
                          memorizationDone
                              ? context.semanticColors.success
                              : Theme.of(context).colorScheme.primary,
                        ),
                      if (canRevise)
                        _statusTag(
                          revisionDone ? 'المراجعة تمت' : 'المراجعة',
                          revisionDone ? Icons.check_circle : Icons.replay,
                          revisionDone
                              ? context.semanticColors.success
                              : context.semanticColors.info,
                        ),
                      if (canTalaqqin && record?.talaqqinDone == true)
                        _statusTag(
                          'التلقين تم',
                          Icons.record_voice_over,
                          context.semanticColors.success,
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    canMemorize
                        ? 'المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}'
                        : 'إجمالي الحفظ: ${student.totalMemorized} آية',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (course != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'دورة اليوم: ${course.title}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'المزيد',
              onSelected: (value) {
                if (hold != null) {
                  _showHoldMessage(student);
                  return;
                }
                switch (value) {
                  case 'talaqqin':
                    _navigateToTalaqqin(student);
                    break;
                  case 'session':
                    _navigateToRecitation(student);
                    break;
                  case 'view':
                    _navigateToStudentView(student);
                    break;
                }
              },
              itemBuilder: (_) => [
                if (canTalaqqin)
                  const PopupMenuItem(
                    value: 'talaqqin',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.record_voice_over_outlined),
                      title: Text('التلقين'),
                    ),
                  ),
                const PopupMenuItem(
                  value: 'session',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.mic_outlined),
                    title: Text('جلسة تسميع'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'view',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.visibility_outlined),
                    title: Text('عرض المحفوظ'),
                  ),
                ),
              ],
            ),
            onTap: hold != null
                ? () => _showHoldMessage(student)
                : () => _navigateToStudentView(student),
          ),
        ),
      ),
    );

    // Force physical swipe semantics independent of the app's RTL direction:
    // swipe right => memorization, swipe left => revision.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Slidable(
        key: ValueKey('student_recitation_${student.id}'),
        startActionPane: canMemorize
            ? ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: hold == null
                        ? (_) {
                            _navigateToAddMemorization(student);
                          }
                        : (_) {
                            _showHoldMessage(student);
                          },
                    backgroundColor: context.semanticColors.success,
                    foregroundColor: Colors.white,
                    icon: memorizationDone
                        ? Icons.edit_note_outlined
                        : Icons.auto_stories_outlined,
                    label: memorizationDone ? 'تعديل الحفظ' : 'الحفظ',
                  ),
                ],
              )
            : null,
        endActionPane: canRevise
            ? ActionPane(
                motion: const StretchMotion(),
                extentRatio: 0.28,
                children: [
                  SlidableAction(
                    onPressed: hold == null
                        ? (_) {
                            _navigateToRevision(student);
                          }
                        : (_) {
                            _showHoldMessage(student);
                          },
                    backgroundColor: context.semanticColors.info,
                    foregroundColor: Colors.white,
                    icon: revisionDone ? Icons.edit_note_outlined : Icons.replay,
                    label: revisionDone ? 'تعديل المراجعة' : 'المراجعة',
                  ),
                ],
              )
            : null,
        child: card,
      ),
    );
  }

  Widget _buildAttendanceBadge(DailyRecord? record) {
    final attendance = record?.attendance;
    if (attendance == 'absent') {
      return _attendanceTag('غائب', Icons.cancel, Colors.red);
    }
    if (attendance == 'excused') {
      return _attendanceTag('مستأذن', Icons.event_busy, Colors.orange);
    }
    return const SizedBox.shrink();
  }

  Widget _buildHoldBadge(String studentId) {
    if (!_activeHolds.containsKey(studentId)) return const SizedBox.shrink();
    return _attendanceTag(
      'موقوف',
      Icons.pause_circle_outline,
      Colors.deepOrange,
    );
  }

  Widget _attendanceTag(String label, IconData icon, Color color) => Container(
        margin: const EdgeInsetsDirectional.only(start: 5),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  Widget _statusTag(String label, IconData icon, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );

  void _showHoldMessage(Student student) {
    final hold = _activeHolds[student.id];
    if (hold == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'التسميع موقوف مؤقتًا حتى '
          '${Helpers.formatHijriDate(hold.endDate)} — ${hold.reason}',
        ),
        backgroundColor: Colors.deepOrange,
      ),
    );
  }

  Widget _buildEmptyState(String message) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 60,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Future<void> _navigateToAddMemorization(Student? student) async {
    if (!mounted) return;
    final course = student == null ? null : _todayCourseByStudent[student.id];
    final courseApplies = course != null && course.includesMemorization;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => AddMemorizationScreen(
          student: student,
          planUnitOverride: courseApplies ? course.memorizationUnit : null,
          planAmountOverride: courseApplies ? course.memorizationAmount : null,
          courseTitle: courseApplies ? course.title : null,
        ),
      ),
    );
    if (result == true && mounted) await _loadData();
  }

  Future<void> _navigateToRevision(Student student) async {
    if (!mounted) return;
    final course = _todayCourseByStudent[student.id];
    final courseApplies = course != null && course.includesRevision;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RevisionScreen(
          student: student,
          reviewUnitOverride: courseApplies ? course.revisionUnit : null,
          reviewAmountOverride: courseApplies ? course.revisionAmount : null,
          courseTitle: courseApplies ? course.title : null,
        ),
      ),
    );
    if (result == true && mounted) await _loadData();
  }

  Future<void> _navigateToStudentView(Student student) async {
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (context) => StudentMemorizationView(student: student),
      ),
    );
    if (mounted) await _loadData();
  }

  Future<void> _navigateToRecitation(Student student) async {
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationScreen(student: student),
      ),
    );
    if (result == true && mounted) await _loadData();
  }

  Future<void> _navigateToTalaqqin(Student student) async {
    if (!mounted) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => TalaqqinScreen(student: student)),
    );
    if (result == true && mounted) await _loadData();
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      case 'hizbs':
        return 'حزب';
      default:
        return planType;
    }
  }
}
