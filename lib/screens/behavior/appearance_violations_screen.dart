import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/behavior_point.dart';
import '../../utils/helpers.dart';

class AppearanceViolationsScreen extends StatefulWidget {
  const AppearanceViolationsScreen({super.key});

  @override
  State<AppearanceViolationsScreen> createState() => _AppearanceViolationsScreenState();
}

class _AppearanceViolationsScreenState extends State<AppearanceViolationsScreen> {
  final DatabaseService _db = DatabaseService();
  List<ViolationWithStudent> _violations = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadViolations();
  }

  Future<void> _loadViolations() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      final violations = <ViolationWithStudent>[];

      for (final student in students) {
        final unresolved = await _db.getUnresolvedViolations(student.id);
        for (final violation in unresolved) {
          violations.add(ViolationWithStudent(
            student: student,
            violation: violation,
          ));
        }
      }

      violations.sort((a, b) => b.violation.date.compareTo(a.violation.date));

      setState(() {
        _violations = violations;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخالفات القائمة'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _violations.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildInfoBanner(),
                    Expanded(child: _buildViolationsList()),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 80, color: Colors.green[300]),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مخالفات قائمة',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'جميع الطلاب ملتزمون بالمظهر المطلوب',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'مخالفات المظهر والحلاقة',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
                const SizedBox(height: 4),
                Text(
                  'هذه المخالفات تستمر حتى يتم تعديلها. اضغط على "تم التعديل" عند إصلاح المخالفة.',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsList() {
    return RefreshIndicator(
      onRefresh: _loadViolations,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _violations.length,
        itemBuilder: (context, index) {
          final data = _violations[index];
          return _buildViolationCard(data);
        },
      ),
    );
  }

  Widget _buildViolationCard(ViolationWithStudent data) {
    final daysCount = DateTime.now().difference(data.violation.date).inDays;
    final totalPenalty = (daysCount + 1) * 3;

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
                  backgroundColor: Colors.red.withOpacity(0.1),
                  child: Text(
                    data.student.name.isNotEmpty ? data.student.name[0] : '؟',
                    style: const TextStyle(color: Colors.red),
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
                        data.violation.reason,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '-$totalPenalty',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تاريخ المخالفة',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      Helpers.formatHijriDate(data.violation.date),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'المدة',
                      style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    ),
                    Text(
                      '$daysCount يوم',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => _resolveViolation(data),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('تم التعديل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            if (data.violation.notes != null && data.violation.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
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
                    Text(
                      data.violation.notes!,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resolveViolation(ViolationWithStudent data) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد التعديل'),
        content: Text('هل تم تعديل مخالفة ${data.student.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _db.resolveBehaviorPoint(data.violation.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل تعديل المخالفة'),
            backgroundColor: Colors.green,
          ),
        );
        _loadViolations();
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

class ViolationWithStudent {
  final Student student;
  final BehaviorPoint violation;

  ViolationWithStudent({
    required this.student,
    required this.violation,
  });
}
