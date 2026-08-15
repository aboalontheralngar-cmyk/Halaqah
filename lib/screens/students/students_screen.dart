import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/settings.dart';
import '../../utils/helpers.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';
import 'student_archive_screen.dart';
import 'families_screen.dart';
import '../../widgets/app_design_widgets.dart';
import '../../widgets/student_card.dart';

class StudentsScreen extends StatefulWidget {
  final VoidCallback? onOpenMenu;

  const StudentsScreen({super.key, this.onOpenMenu});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final DatabaseService _db = DatabaseService();
  List<Student> _students = [];
  List<Student> _filteredStudents = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _sortBy = 'name';
  HalaqahSettings _settings = HalaqahSettings();
  List<String> _leftOutStudentIds = [];
  int _archiveCount = 0;

  // إشعار "لم يسمّع" لا يظهر إلا بعد انتهاء وقت دوام الحلقة (وقت النهاية في الإعدادات)
  bool _checkPastEndTime(HalaqahSettings settings) {
    final endStr =
        settings.isRamadanMode ? settings.ramadanEndTime : settings.normalEndTime;
    final parts = endStr.split(':');
    if (parts.length < 2) return true;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    final endToday = DateTime(now.year, now.month, now.day, h, m);
    return now.isAfter(endToday);
  }

  bool get _isPastClassEndTime => _checkPastEndTime(_settings);

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait<dynamic>([
        _db.getSettings(),
        _db.getOperationalStudents(),
        _db.getArchivedStudents(),
        _db.getStudentsWhoDidNotReciteLastClass(),
      ]);
      final settings = results[0] as HalaqahSettings;
      final students = results[1] as List<Student>;
      final archivedStudents = results[2] as List<Student>;
      final leftOutIds = results[3] as List<String>;
      if (!mounted) return;
      setState(() {
        _students = students;
        _settings = settings;
        _leftOutStudentIds = leftOutIds;
        _archiveCount = archivedStudents.length;
        _applyFilters();
        _isLoading = false;
      });

      // لا نحجب ظهور قائمة الطلاب بعمليات إغلاق/نقاط وإشعارات قد تستغرق
      // وقتًا على قواعد كبيرة. تنفذ بعد الإطار الأول ثم نحدث المؤشرات فقط.
      unawaited(_refreshAutomaticRules(settings));
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshAutomaticRules(HalaqahSettings settings) async {
    if (!_checkPastEndTime(settings)) return;
    try {
      final today = DateTime.now();
      final suspended = await _db.isDateSuspended(today);
      await _db.applyAutomaticNegativePoints(isHoliday: suspended);
      await _db.generateNotifications();
      final leftOutIds = await _db.getStudentsWhoDidNotReciteLastClass();
      if (!mounted) return;
      setState(() {
        _leftOutStudentIds = leftOutIds;
        _applyFilters();
      });
    } catch (_) {
      // فشل الصيانة الخلفية لا يمنع استخدام قائمة الطلاب.
    }
  }

  void _applyFilters() {
    _filteredStudents = _students.where((student) {
      final matchesSearch = student.name.contains(_searchQuery) ||
          student.phone.contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'all' || student.status == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();

    if (_sortBy == 'name') {
      _filteredStudents.sort((a, b) => a.name.compareTo(b.name));
    } else if (_sortBy == 'memorized') {
      _filteredStudents.sort((a, b) => b.totalMemorized.compareTo(a.totalMemorized));
    } else if (_sortBy == 'left_out') {
      _filteredStudents.sort((a, b) {
        final aLeft = _leftOutStudentIds.contains(a.id);
        final bLeft = _leftOutStudentIds.contains(b.id);
        if (aLeft && !bLeft) return -1;
        if (!aLeft && bLeft) return 1;
        return a.name.compareTo(b.name);
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
        title: Text(GenderHelper.students(_settings.gender)),
        actions: [
          IconButton(
            icon: const Icon(Icons.family_restroom_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FamiliesScreen()),
              );
              await _loadStudents();
            },
            tooltip: 'العائلات وأولياء الأمور',
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: _archiveCount > 0,
              label: Text('$_archiveCount'),
              child: const Icon(Icons.inventory_2_outlined),
            ),
            onPressed: _openArchive,
            tooltip: 'أرشيف الطلاب',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'ترتيب ${GenderHelper.students(_settings.gender)}',
            onSelected: (value) {
              setState(() {
                _sortBy = value;
                _applyFilters();
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'name',
                child: Row(
                  children: [
                    Icon(Icons.sort_by_alpha, color: _sortBy == 'name' ? Theme.of(context).primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('ترتيب أبجدي (الاسم)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'memorized',
                child: Row(
                  children: [
                    Icon(Icons.star, color: _sortBy == 'memorized' ? Theme.of(context).primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('ترتيب حسب المحفوظ'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'left_out',
                child: Row(
                  children: [
                    Icon(Icons.priority_high, color: _sortBy == 'left_out' ? Theme.of(context).primaryColor : Colors.grey),
                    const SizedBox(width: 8),
                    const Text('الأولوية للذين لم يسمّعوا'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
            tooltip: 'تصفية ${GenderHelper.students(_settings.gender)}',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppSearchField(
                hintText:
                    'بحث عن اسم ${GenderHelper.student(_settings.gender)} أو رقم الهاتف...',
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                    _applyFilters();
                  });
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredStudents.isEmpty
                      ? _buildEmptyState()
                      : _buildStudentList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: Text(GenderHelper.addStudent(_settings.gender)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return AppEmptyState(
      icon: _searchQuery.isEmpty ? Icons.people_outline : Icons.search_off,
      title: _searchQuery.isNotEmpty
          ? 'لا توجد نتائج مطابقة'
          : 'لا يوجد ${GenderHelper.students(_settings.gender)} بعد',
      message: _searchQuery.isNotEmpty
          ? 'جرّب اسمًا آخر أو امسح فلاتر الحالة والترتيب.'
          : 'ابدأ بإضافة ${GenderHelper.student(_settings.gender)} لتظهر بياناته وخطته هنا.',
      action: _searchQuery.isNotEmpty
          ? null
          : FilledButton.icon(
              onPressed: () => _navigateToForm(null),
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(GenderHelper.addStudent(_settings.gender)),
            ),
    );
  }

  Widget _buildStudentList() {
    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredStudents.length,
        itemBuilder: (context, index) {
          final student = _filteredStudents[index];
          return _buildStudentCard(student);
        },
      ),
    );
  }

  Widget _buildStudentCard(Student student) {
    final needsFollowUp = _isPastClassEndTime &&
        _leftOutStudentIds.contains(student.id);
    final phone = student.phone.isEmpty ? '' : '\n${student.phone}';
    return StudentCard(
      student: student,
      onTap: () => _navigateToDetail(student),
      subtitle:
          'الحفظ: ${student.totalMemorized} آية • المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}$phone',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (needsFollowUp)
            Tooltip(
              message: 'لم يسمّع في آخر يوم حضره',
              child: Icon(
                Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفية'),
        content: RadioGroup<String>(
          groupValue: _statusFilter,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _statusFilter = value;
              _applyFilters();
            });
            Navigator.pop(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              RadioListTile<String>(
                title: Text('الكل'),
                value: 'all',
              ),
              RadioListTile<String>(
                title: Text('نشط'),
                value: 'active',
              ),
              RadioListTile<String>(
                title: Text('موقوف'),
                value: 'suspended',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToForm(Student? student) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(student: student),
      ),
    );
    if (result == true) {
      _loadStudents();
    }
  }

  Future<void> _openArchive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const StudentArchiveScreen()),
    );
    await _loadStudents();
  }

  void _navigateToDetail(Student student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDetailScreen(student: student),
      ),
    );
    _loadStudents();
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      case 'hizbs':
        return 'حزب';
      default:
        return type;
    }
  }
}
