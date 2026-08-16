import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/behavior_point.dart';
import '../../utils/helpers.dart';

class PointsHistoryScreen extends StatefulWidget {
  final Student student;

  const PointsHistoryScreen({super.key, required this.student});

  @override
  State<PointsHistoryScreen> createState() => _PointsHistoryScreenState();
}

class _PointsHistoryScreenState extends State<PointsHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  List<BehaviorPoint> _points = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() => _isLoading = true);
    try {
      final points = await _db.getStudentBehaviorPoints(widget.student.id);
      setState(() {
        _points = points;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<BehaviorPoint> get _filteredPoints {
    if (_filter == 'all') return _points;
    if (_filter == 'positive') {
      return _points.where((p) => p.type == 'positive').toList();
    }
    if (_filter == 'unresolved') {
      return _points.where((p) => p.type == 'negative' && !p.resolved).toList();
    }
    return _points.where((p) => p.type == 'negative').toList();
  }

  double get _positiveTotal =>
      _points.where((p) => p.type == 'positive').fold<double>(0, (sum, p) => sum + p.points);

  double get _negativeTotal =>
      _points.where((p) => p.type == 'negative').fold<double>(0, (sum, p) => sum + p.points);

  double get _netTotal => _positiveTotal + _negativeTotal;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('نقاط ${widget.student.name}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('الكل')),
              const PopupMenuItem(value: 'positive', child: Text('إيجابية فقط')),
              const PopupMenuItem(value: 'negative', child: Text('سلبية فقط')),
              const PopupMenuItem(
                value: 'unresolved',
                child: Text('مخالفات قائمة فقط'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryCard(),
                Expanded(
                  child: _filteredPoints.isEmpty
                      ? _buildEmptyState()
                      : _buildPointsList(),
                ),
              ],
            ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSummaryItem('إيجابي', '+${Helpers.formatNumber(_positiveTotal)}', Colors.green),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('سلبي', Helpers.formatNumber(_negativeTotal), Colors.red),
              Container(width: 1, height: 40, color: Colors.white24),
              _buildSummaryItem('الصافي', Helpers.formatNumber(_netTotal), Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text(
            'لا يوجد سجل نقاط',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsList() {
    return RefreshIndicator(
      onRefresh: _loadPoints,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filteredPoints.length,
        itemBuilder: (context, index) {
          final point = _filteredPoints[index];
          return _buildPointCard(point);
        },
      ),
    );
  }

  Widget _buildPointCard(BehaviorPoint point) {
    final isPositive = point.type == 'positive';
    final color = isPositive ? Colors.green : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(
            isPositive ? Icons.add_circle : Icons.remove_circle,
            color: color,
          ),
        ),
        title: Text(point.reason),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(Helpers.formatHijriDate(point.date)),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${isPositive ? '+' : ''}${Helpers.formatNumber(point.points)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                if (!point.resolved)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'مخالفة قائمة',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
              ],
            ),
            if (point.notes != null && point.notes!.isNotEmpty)
              Text(
                point.notes!,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          tooltip: 'إجراءات السجل',
          onSelected: (value) {
            if (value == 'reassign') _showReassignDialog(point);
            if (value == 'delete') _confirmDelete(point);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'reassign',
              child: Row(
                children: [
                  Icon(Icons.person_search_outlined, color: Colors.blue),
                  SizedBox(width: 12),
                  Expanded(child: Text('تصحيح الطالب المسند إليه')),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 12),
                  Expanded(child: Text('حذف السجل الخاطئ')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BehaviorPoint point) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف سجل النقاط؟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'سيُحذف «${point.reason}» من سجل ${widget.student.name}. '
              'سيُحفظ سبب التصحيح في سجل التدقيق.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الحذف (إلزامي)',
                hintText: 'مثال: سُجلت المكافأة مرتين',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || reason.isEmpty) return;
    await _db.deleteBehaviorPoint(
      point.id,
      expectedStudentId: widget.student.id,
      correctionReason: reason,
    );
    if (!mounted) return;
    setState(() => _points.removeWhere((item) => item.id == point.id));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف السجل الخاطئ')),
    );
  }

  Future<void> _showReassignDialog(BehaviorPoint point) async {
    final students = (await _db.getOperationalStudents())
        .where((student) => student.id != widget.student.id)
        .toList();
    if (!mounted) return;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد طالب آخر نشط لتصحيح الإسناد إليه')),
      );
      return;
    }
    Student? selectedStudent;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تصحيح إسناد السجل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('السجل الحالي: ${point.reason} (${Helpers.formatNumber(point.points)} نقطة)'),
              Text('مسند حاليًا إلى: ${widget.student.name}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<Student>(
                initialValue: selectedStudent,
                decoration: const InputDecoration(
                  labelText: 'الطالب الصحيح',
                  prefixIcon: Icon(Icons.person_search_outlined),
                ),
                items: students.map((student) {
                  final suffix = student.guardianPhone.trim().isEmpty
                      ? ''
                      : ' — ${_maskedPhone(student.guardianPhone)}';
                  return DropdownMenuItem(
                    value: student,
                    child: Text(
                      '${student.name}$suffix',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setDialogState(() => selectedStudent = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب التصحيح (إلزامي)',
                  hintText: 'مثال: تشابه الاسمين عند التسجيل',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedStudent == null ||
                    reasonController.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('تأكيد التصحيح'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || selectedStudent == null || reason.isEmpty) return;
    await _db.reassignBehaviorPoint(
      pointId: point.id,
      expectedStudentId: widget.student.id,
      correctedStudentId: selectedStudent!.id,
      reason: reason,
    );
    if (!mounted) return;
    setState(() => _points.removeWhere((item) => item.id == point.id));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم نقل السجل إلى ${selectedStudent!.name} مع حفظ سبب التصحيح')),
    );
  }

  String _maskedPhone(String value) {
    final normalized = value.replaceAll(RegExp(r'\s+'), '');
    if (normalized.length <= 4) return normalized;
    return '••••${normalized.substring(normalized.length - 4)}';
  }
}
