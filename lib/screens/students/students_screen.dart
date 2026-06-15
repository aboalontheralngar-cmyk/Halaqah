import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import 'student_form_screen.dart';
import 'student_detail_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents();
      setState(() {
        _students = students;
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلاب'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث عن اسم الطالب أو رقم الهاتف...',
                prefixIcon: Icon(Icons.search),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToForm(null),
        icon: const Icon(Icons.add),
        label: const Text('إضافة طالب'),
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
            _searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا يوجد طلاب',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          if (_searchQuery.isEmpty)
            Text(
              'اضغط + لإضافة طالب جديد',
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
            RadioListTile<String>(
              title: const Text('مفصول'),
              value: 'expelled',
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
