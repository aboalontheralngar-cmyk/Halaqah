import 'dart:convert';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/student_learning_policy.dart';
import '../../models/student.dart';
import '../../models/daily_record.dart';
import '../../models/student_hold.dart';
import '../../models/quran_course.dart';
import '../../utils/helpers.dart';
import 'add_memorization_screen.dart';
import 'revision_screen.dart';
import 'student_memorization_view.dart';
import 'memorization_plan_screen.dart';
import 'recitation_screen.dart';
import 'recitation_history_screen.dart';
import 'talaqqin_screen.dart';
import '../../app/theme.dart';
import '../../app/design_tokens.dart';
import '../../widgets/app_design_widgets.dart';

class MemorizationScreen extends StatefulWidget {
  const MemorizationScreen({super.key});

  @override
  State<MemorizationScreen> createState() => _MemorizationScreenState();
}

class _MemorizationScreenState extends State<MemorizationScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  late TabController _tabController;
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _loadData();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) setState(() {});
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
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
              !todayKey.isBefore(DateTime(course.startDate.year, course.startDate.month, course.startDate.day)) &&
              !todayKey.isAfter(DateTime(course.endDate.year, course.endDate.month, course.endDate.day)) &&
              course.studyWeekdays.contains(today.weekday))
            course.id: course,
      };
      final courseByStudent = <String, QuranCourse>{};
      for (final enrollment in enrollments.where((item) => item.status == 'active')) {
        final course = activeCoursesById[enrollment.courseId];
        if (course != null) courseByStudent.putIfAbsent(enrollment.studentId, () => course);
      }

      final recordsMap = <String, DailyRecord>{};
      for (final record in records) {
        recordsMap[record.studentId] = record;
      }

      final parsedOrder = <String>[];
      if (storedOrder != null && storedOrder.isNotEmpty) {
        try {
          final raw = jsonDecode(storedOrder);
          if (raw is List) parsedOrder.addAll(raw.map((item) => item.toString()));
        } catch (_) {
          // ترتيب قديم/تالف لا يمنع تحميل شاشة التسميع.
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
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Student> _filteredStudentsFor({required bool revision}) {
    final eligible = _students.where(
      revision
          ? StudentLearningPolicy.canReceiveRevision
          : StudentLearningPolicy.canReceiveNewMemorization,
    );
    List<Student> list;
    if (_filter == 'all') {
      list = List<Student>.from(eligible);
    } else {
      list = eligible.where((student) {
        final record = _todayRecords[student.id];
        if (_filter == 'completed') {
          return revision
              ? record?.revisionDone == true
              : record?.memorizationDone == true;
        } else {
          return revision
              ? record?.revisionDone != true
              : record?.memorizationDone != true;
        }
      }).toList();
    }

    if (_sortBy == 'name') {
      list.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'memorized') {
      list.sort((a, b) => b.totalMemorized.compareTo(a.totalMemorized));
    } else if (_sortBy == 'manual') {
      list.sort((a, b) => _manualIndex(a.id).compareTo(_manualIndex(b.id)));
    }
    return list;
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
    setState(() => _manualOrder = master);
    await _db.saveSetting('recitation_manual_order', jsonEncode(master));
  }

  Widget _buildReorderableStudentList(
    List<Student> students,
    Widget Function(Student student) builder,
  ) {
    if (_sortBy != 'manual' || _filter != 'all') {
      return ListView.builder(
        padding: AppSpacing.page,
        itemCount: students.length,
        itemBuilder: (context, index) => builder(students[index]),
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
          child: builder(student),
        );
      },
    );
  }

  List<Student> _filteredTalaqqinStudents() {
    var list = _students.where(StudentLearningPolicy.canReceiveTalaqqin).toList();
    if (_filter != 'all') {
      list = list.where((student) {
        final done = _todayRecords[student.id]?.talaqqinDone == true;
        return _filter == 'completed' ? done : !done;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسميع والتلقين'),
        bottom: TabBar(
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.72),
          indicatorColor: Theme.of(context).colorScheme.secondary,
          controller: _tabController,
          tabs: const [
            Tab(text: 'الحفظ الجديد'),
            Tab(text: 'المراجعة'),
            Tab(text: 'التلقين'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const RecitationHistoryScreen(),
                ),
              );
              await _loadData();
            },
            tooltip: 'سجل التسميع والتعديل',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MemorizationPlanScreen()),
              );
            },
            tooltip: 'خطة الحفظ',
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
              PopupMenuItem(
                value: 'sort_manual',
                child: Row(
                  children: [
                    Icon(Icons.drag_indicator, color: _sortBy == 'manual' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('ترتيب يدوي بالسحب'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: _sortBy == 'name' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('ترتيب أبجدي (الاسم)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'sort_memorized',
                child: Row(
                  children: [
                    Icon(Icons.star, color: _sortBy == 'memorized' ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    const Text('ترتيب حسب المحفوظ'),
                  ],
                ),
              ),
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
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMemorizationTab(),
                  _buildRevisionTab(),
                  _buildTalaqqinTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () => _navigateToAddMemorization(null),
              tooltip: 'إضافة حفظ جديد',
              icon: const Icon(Icons.add_rounded),
              label: const Text('حفظ مباشر'),
            )
          : null,
    );
  }

  Widget _buildWorkspaceSummary() {
    final revision = _tabController.index == 1;
    final talaqqin = _tabController.index == 2;
    final eligible = _students
        .where(
          revision || talaqqin
              ? StudentLearningPolicy.canReceiveRevision
              : StudentLearningPolicy.canReceiveNewMemorization,
        )
        .toList();
    int completed = 0;
    int pending = 0;
    for (final student in eligible) {
      final record = _todayRecords[student.id];
      final isDone = talaqqin
          ? record?.talaqqinDone == true
          : revision
              ? record?.revisionDone == true
              : record?.memorizationDone == true;
      if (isDone) {
        completed++;
      } else {
        pending++;
      }
    }

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
                    talaqqin
                        ? Icons.record_voice_over_outlined
                        : revision
                            ? Icons.replay_rounded
                            : Icons.auto_stories_outlined,
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
                  AppStatusPill(
                    label: 'تم $completed',
                    color: semantic.success,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  AppStatusPill(
                    label: 'باقٍ $pending',
                    color: semantic.warning,
                  ),
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

  Widget _buildMemorizationTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredStudents = _filteredStudentsFor(revision: false);
    if (filteredStudents.isEmpty) {
      return _buildEmptyState(
        _students.any(StudentLearningPolicy.hasCompletedQuran)
            ? 'لا يوجد طلاب في مسار الحفظ الجديد؛ الخاتمون يظهرون في المراجعة فقط'
            : 'لا يوجد طلاب في مسار الحفظ الجديد',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _buildReorderableStudentList(
            filteredStudents,
            (student) => _buildStudentMemorizationCard(
              student,
              _todayRecords[student.id],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRevisionTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredStudents = _filteredStudentsFor(revision: true);
    if (filteredStudents.isEmpty) {
      return _buildEmptyState('لا يوجد طلاب');
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _buildReorderableStudentList(
            filteredStudents,
            (student) => _buildStudentRevisionCard(
              student,
              _todayRecords[student.id],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTalaqqinTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final students = _filteredTalaqqinStudents();
    if (students.isEmpty) return _buildEmptyState('لا يوجد طلاب للتلقين');
    return RefreshIndicator(
      onRefresh: _loadData,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: _buildReorderableStudentList(
            students,
            (student) => _buildStudentTalaqqinCard(
              student,
              _todayRecords[student.id],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStudentTalaqqinCard(Student student, DailyRecord? record) {
    final isDone = record?.talaqqinDone == true;
    final hold = _activeHolds[student.id];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: hold == null ? 1 : 0.55,
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(isDone
                ? Icons.check_rounded
                : Icons.record_voice_over_outlined),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              _buildAttendanceBadge(record),
              _buildHoldBadge(student.id),
            ],
          ),
          subtitle: Text(
            hold != null
                ? 'التلقين موقوف مؤقتًا'
                : isDone
                    ? 'تم تلقين ${record?.talaqqinAmount ?? 0} آية اليوم'
                    : 'تلقين مستقل لا يزيد المحفوظ',
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: hold != null
              ? () => _showHoldMessage(student)
              : () => _navigateToTalaqqin(student),
        ),
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
      'موقوف مؤقتًا',
      Icons.pause_circle_outline,
      Colors.deepOrange,
    );
  }

  Widget _attendanceTag(String label, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStudentMemorizationCard(Student student, DailyRecord? record) {
    final isDone = record?.memorizationDone == true;
    final isAbsentOrExcused = record?.attendance == 'absent' || record?.attendance == 'excused';
    final isHeld = _activeHolds.containsKey(student.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isAbsentOrExcused || isHeld ? 0.55 : 1.0,
        child: InkWell(
        onTap: isHeld
            ? () => _showHoldMessage(student)
            : () => _navigateToAddMemorization(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '؟',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildAttendanceBadge(record),
                        _buildHoldBadge(student.id),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (_todayCourseByStudent[student.id] case final course?) ...[
                      const SizedBox(height: 2),
                      Text(
                        course.includesMemorization
                            ? 'دورة ${course.title}: ${course.memorizationAmount} ${_getPlanLabel(course.memorizationUnit)}'
                            : 'دورة ${course.title}: مراجعة فقط اليوم',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Text(
                      isHeld ? 'التسميع موقوف مؤقتًا' : isDone ? 'أُنجز مقرر اليوم' : 'بانتظار تسميع اليوم',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isHeld
                            ? Colors.deepOrange
                            : isDone
                                ? Colors.green
                                : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إجراءات الطالب',
                onSelected: (value) {
                  if (value == 'session' && !isHeld) {
                    _navigateToRecitation(student);
                  }
                  if (value == 'view') _navigateToStudentView(student);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'session',
                    enabled: !isHeld,
                    child: const ListTile(
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
                icon: Icon(
                  isHeld
                      ? Icons.pause_circle_outline
                      : isDone
                          ? Icons.check_circle_outline
                          : Icons.more_vert,
                  color: isHeld
                      ? Colors.deepOrange
                      : isDone
                          ? Colors.green
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildStudentRevisionCard(Student student, DailyRecord? record) {
    final isDone = record?.revisionDone == true;
    final isHeld = _activeHolds.containsKey(student.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Opacity(
        opacity: isHeld ? 0.55 : 1,
        child: InkWell(
        onTap: isHeld
            ? () => _showHoldMessage(student)
            : () => _navigateToRevision(student),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                child: Text(
                  student.name.isNotEmpty ? student.name[0] : '؟',
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            student.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        _buildAttendanceBadge(record),
                        _buildHoldBadge(student.id),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'إجمالي الحفظ: ${student.totalMemorized} آية',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isHeld
                      ? AppSemanticColors.of(context).warningContainer
                      : isDone
                          ? AppSemanticColors.of(context).successContainer
                          : Theme.of(context).colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isHeld
                          ? Icons.pause_circle
                          : isDone
                              ? Icons.check_circle
                              : Icons.replay,
                      size: 16,
                      color: isHeld
                          ? AppSemanticColors.of(context).warning
                          : isDone
                              ? AppSemanticColors.of(context).success
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isHeld ? 'موقوفة' : isDone ? 'تمت' : 'مراجعة',
                      style: TextStyle(
                        color: isHeld
                            ? AppSemanticColors.of(context).warning
                            : isDone
                                ? AppSemanticColors.of(context).success
                                : Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showHoldMessage(Student student) {
    final hold = _activeHolds[student.id];
    if (hold == null) return;
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

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
  }

  void _navigateToAddMemorization(Student? student) async {
    final course = student == null ? null : _todayCourseByStudent[student.id];
    final courseApplies = course != null && course.includesMemorization;
    final result = await Navigator.push(
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
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToRevision(Student student) async {
    final course = _todayCourseByStudent[student.id];
    final courseApplies = course != null && course.includesRevision;
    final result = await Navigator.push(
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
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToStudentView(Student student) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentMemorizationView(student: student),
      ),
    );
  }

  void _navigateToRecitation(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecitationScreen(student: student),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  Future<void> _navigateToTalaqqin(Student student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TalaqqinScreen(student: student)),
    );
    if (result == true) await _loadData();
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
