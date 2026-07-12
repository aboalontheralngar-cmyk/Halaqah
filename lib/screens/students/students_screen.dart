import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/settings.dart';
import '../../utils/helpers.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';
import 'student_archive_screen.dart';

class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

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
      final settings = await _db.getSettings();
      // احتساب النقاط السلبية التلقائية بعد انتهاء دوام الحلقة فقط (idempotent)
      // مع تخطّي الأيام المعطّلة (إجازة أسبوعية أو تعليق دراسة)
      if (_checkPastEndTime(settings)) {
        final today = DateTime.now();
        final suspended = await _db.isDateSuspended(today);
        await _db.applyAutomaticNegativePoints(isHoliday: suspended);
        await _db.generateNotifications();
      }
      final students = await _db.getOperationalStudents();
      final archivedStudents = await _db.getArchivedStudents();
      final leftOutIds = await _db.getStudentsWhoDidNotReciteLastClass();
      setState(() {
        _students = students;
        _settings = settings;
        _leftOutStudentIds = leftOutIds;
        _archiveCount = archivedStudents.length;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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
        title: Text(GenderHelper.students(_settings.gender)),
        actions: [
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
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'بحث عن اسم ${GenderHelper.student(_settings.gender)} أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search),
                ),
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا يوجد ${GenderHelper.students(_settings.gender)}',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'اضغط + لإضافة ${GenderHelper.student(_settings.gender)} جديد',
              style: TextStyle(color: Colors.grey[500]),
            ),
        ],
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
    final statusColor = _getStatusColor(student.status);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _navigateToDetail(student),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                child: student.photoPath != null
                    ? ClipOval(
                        child: Image.asset(
                          student.photoPath!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _buildAvatarText(student),
                        ),
                      )
                    : _buildAvatarText(student),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            student.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (_isPastClassEndTime && _leftOutStudentIds.contains(student.id)) ...[
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber.shade300),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.warning_amber_rounded, size: 10, color: Colors.orange),
                                const SizedBox(width: 4),
                                Text(
                                  'لم يسمّع',
                                  style: GoogleFonts.tajawal(fontSize: 9, color: Colors.brown, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusLabel(student.status),
                            style: TextStyle(
                              fontSize: 10,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'الحفظ: ${student.totalMemorized} آية | المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    if (student.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        student.phone,
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarText(Student student) {
    return Text(
      student.name.isNotEmpty ? student.name[0] : '؟',
      style: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تصفية'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              title: const Text('الكل'),
              value: 'all',
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('نشط'),
              value: 'active',
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
            RadioListTile<String>(
              title: const Text('موقوف'),
              value: 'suspended',
              groupValue: _statusFilter,
              onChanged: (value) {
                setState(() {
                  _statusFilter = value!;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
            ),
          ],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'suspended':
        return Colors.orange;
      case 'expelled':
        return Colors.red;
      case 'graduated':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'suspended':
        return 'موقوف';
      case 'expelled':
        return 'مفصول';
      case 'graduated':
        return 'متخرج';
      default:
        return status;
    }
  }

  String _getPlanLabel(String type) {
    switch (type) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return type;
    }
  }
}
