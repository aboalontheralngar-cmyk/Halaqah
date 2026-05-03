import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/vacation.dart';
import '../../utils/helpers.dart';
import 'add_vacation_screen.dart';

class VacationsScreen extends StatefulWidget {
  const VacationsScreen({super.key});

  @override
  State<VacationsScreen> createState() => _VacationsScreenState();
}

class _VacationsScreenState extends State<VacationsScreen> {
  final DatabaseService _db = DatabaseService();
  List<VacationWithStudent> _vacations = [];
  bool _isLoading = true;
  String _filter = 'current';

  @override
  void initState() {
    super.initState();
    _loadVacations();
  }

  Future<void> _loadVacations() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents();
      final vacations = <VacationWithStudent>[];

      for (final student in students) {
        final studentVacations = await _db.getStudentVacations(student.id);
        for (final vacation in studentVacations) {
          vacations.add(VacationWithStudent(student: student, vacation: vacation));
        }
      }

      vacations.sort((a, b) => b.vacation.startDate.compareTo(a.vacation.startDate));

      setState(() {
        _vacations = vacations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<VacationWithStudent> get _filteredVacations {
    final now = DateTime.now();
    switch (_filter) {
      case 'current':
        return _vacations.where((v) {
          return v.vacation.startDate.isBefore(now) &&
              v.vacation.endDate.isAfter(now);
        }).toList();
      case 'upcoming':
        return _vacations.where((v) {
          return v.vacation.startDate.isAfter(now);
        }).toList();
      case 'past':
        return _vacations.where((v) {
          return v.vacation.endDate.isBefore(now);
        }).toList();
      default:
        return _vacations;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الإجازات'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'current', child: Text('الحالية')),
              const PopupMenuItem(value: 'upcoming', child: Text('القادمة')),
              const PopupMenuItem(value: 'past', child: Text('السابقة')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilterTabs(),
                Expanded(
                  child: _filteredVacations.isEmpty
                      ? _buildEmptyState()
                      : _buildVacationsList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToAddVacation(),
        icon: const Icon(Icons.add),
        label: const Text('إضافة إجازة'),
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildFilterChip('الكل', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('الحالية', 'current'),
          const SizedBox(width: 8),
          _buildFilterChip('القادمة', 'upcoming'),
          const SizedBox(width: 8),
          _buildFilterChip('السابقة', 'past'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.beach_access, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا توجد إجازات',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _getEmptyMessage(),
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _getEmptyMessage() {
    switch (_filter) {
      case 'current':
        return 'لا يوجد طلاب في إجازة حالياً';
      case 'upcoming':
        return 'لا توجد إجازات مجدولة';
      case 'past':
        return 'لا توجد إجازات سابقة';
      default:
        return 'اضغط + لإضافة إجازة جديدة';
    }
  }

  Widget _buildVacationsList() {
    return RefreshIndicator(
      onRefresh: _loadVacations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredVacations.length,
        itemBuilder: (context, index) {
          final data = _filteredVacations[index];
          return _buildVacationCard(data);
        },
      ),
    );
  }

  Widget _buildVacationCard(VacationWithStudent data) {
    final now = DateTime.now();
    final isCurrent = data.vacation.startDate.isBefore(now) &&
        data.vacation.endDate.isAfter(now);
    final isUpcoming = data.vacation.startDate.isAfter(now);
    final isPast = data.vacation.endDate.isBefore(now);

    Color statusColor;
    String statusLabel;
    if (isCurrent) {
      statusColor = Colors.green;
      statusLabel = 'جارية';
    } else if (isUpcoming) {
      statusColor = Colors.blue;
      statusLabel = 'قادمة';
    } else {
      statusColor = Colors.grey;
      statusLabel = 'انتهت';
    }

    final daysCount = data.vacation.endDate.difference(data.vacation.startDate).inDays + 1;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Text(
                    data.student.name.isNotEmpty ? data.student.name[0] : '؟',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _getReasonLabel(data.vacation.reason),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildDateInfo('من', data.vacation.startDate),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$daysCount يوم',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildDateInfo('إلى', data.vacation.endDate),
                ),
              ],
            ),
            if (data.vacation.notes != null && data.vacation.notes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.note, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data.vacation.notes!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!isPast) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _deleteVacation(data),
                    icon: const Icon(Icons.delete, size: 18),
                    label: const Text('حذف'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo(String label, DateTime date) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        Text(
          Helpers.formatHijriDate(date),
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  String _getReasonLabel(String reason) {
    switch (reason) {
      case 'travel':
        return 'سفر';
      case 'illness':
        return 'مرض';
      case 'family':
        return 'ظرف عائلي';
      default:
        return 'أخرى';
    }
  }

  void _navigateToAddVacation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddVacationScreen()),
    );
    if (result == true) _loadVacations();
  }

  Future<void> _deleteVacation(VacationWithStudent data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الإجازة'),
        content: Text('هل تريد حذف إجازة ${data.student.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.deleteVacation(data.vacation.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الإجازة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadVacations();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

class VacationWithStudent {
  final Student student;
  final Vacation vacation;

  VacationWithStudent({required this.student, required this.vacation});
}
