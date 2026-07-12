import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/student_status_change.dart';
import '../../services/database_service.dart';
import '../../utils/helpers.dart';
import 'student_detail_screen.dart';

class StudentArchiveScreen extends StatefulWidget {
  const StudentArchiveScreen({super.key});

  @override
  State<StudentArchiveScreen> createState() => _StudentArchiveScreenState();
}

class _StudentArchiveScreenState extends State<StudentArchiveScreen> {
  final DatabaseService _db = DatabaseService();
  List<_ArchivedStudentEntry> _entries = [];
  bool _isLoading = true;
  String _filter = 'all';
  String _search = '';

  @override
  void initState() {
    super.initState();
    _loadArchive();
  }

  Future<void> _loadArchive() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getArchivedStudents();
      final entries = await Future.wait(
        students.map((student) async => _ArchivedStudentEntry(
              student: student,
              latestChange:
                  await _db.getLatestStudentStatusChange(student.id),
            )),
      );
      entries.sort((a, b) => a.student.name.compareTo(b.student.name));
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_ArchivedStudentEntry> get _filteredEntries => _entries.where((entry) {
        final matchesFilter =
            _filter == 'all' || entry.student.status == _filter;
        final query = _search.trim();
        final matchesSearch = query.isEmpty ||
            entry.student.name.contains(query) ||
            entry.student.guardianPhone.contains(query);
        return matchesFilter && matchesSearch;
      }).toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('أرشيف الطلاب')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'بحث بالاسم أو رقم ولي الأمر',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _search = value),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'الكل', _entries.length),
                _filterChip(
                  'expelled',
                  'المفصولون',
                  _entries.where((e) => e.student.status == 'expelled').length,
                ),
                _filterChip(
                  'graduated',
                  'الخاتمون/المتخرجون',
                  _entries.where((e) => e.student.status == 'graduated').length,
                ),
                _filterChip(
                  'inactive',
                  'السابقون',
                  _entries.where((e) => e.student.status == 'inactive').length,
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadArchive,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) =>
                              _buildArchiveCard(_filteredEntries[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label, int count) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        selected: _filter == value,
        label: Text('$label ($count)'),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              'لا توجد سجلات في هذا القسم',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text('لا تُحذف بيانات الطالب عند نقله إلى الأرشيف.'),
          ],
        ),
      );

  Widget _buildArchiveCard(_ArchivedStudentEntry entry) {
    final student = entry.student;
    final change = entry.latestChange;
    final color = _statusColor(student.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Text(
                    student.name.isEmpty ? '؟' : student.name[0],
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        change == null
                            ? 'سبب النقل غير موثق في البيانات القديمة'
                            : change.reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusLabel(student.status),
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            if (change != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  'آخر تغيير: ${Helpers.getFullHijriDate(change.changedAt)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ),
            ],
            const Divider(height: 24),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _openDetails(student),
                  icon: const Icon(Icons.person_outline),
                  label: const Text('التفاصيل'),
                ),
                TextButton.icon(
                  onPressed: () => _showHistory(student),
                  icon: const Icon(Icons.history),
                  label: const Text('سجل الحالة'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _restoreStudent(student),
                  icon: const Icon(Icons.restore),
                  label: const Text('إعادة تفعيل'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDetails(Student student) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
    );
    await _loadArchive();
  }

  Future<void> _restoreStudent(Student student) async {
    final reasonController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعادة تفعيل ${student.name}؟'),
        content: TextField(
          controller: reasonController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'سبب إعادة التفعيل (إلزامي)',
            hintText: 'مثال: عاد للانتظام بعد التواصل مع ولي الأمر',
          ),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;
              Navigator.pop(context, true);
            },
            child: const Text('تأكيد إعادة التفعيل'),
          ),
        ],
      ),
    );
    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (accepted != true || reason.isEmpty) return;
    await _db.changeStudentStatus(
      studentId: student.id,
      newStatus: 'active',
      reason: reason,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('أُعيد ${student.name} إلى قائمة الطلاب النشطين')),
    );
    await _loadArchive();
  }

  Future<void> _showHistory(Student student) async {
    final history = await _db.getStudentStatusHistory(student.id);
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: history.isEmpty
              ? const Center(child: Text('لا يوجد سجل تاريخي لهذه الحالة'))
              : ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final change = history[index];
                    return ListTile(
                      leading: const Icon(Icons.swap_horiz),
                      title: Text(
                        '${_statusLabel(change.previousStatus)} ← ${_statusLabel(change.newStatus)}',
                      ),
                      subtitle: Text(
                        '${change.reason}\n${Helpers.getFullHijriDate(change.changedAt)}'
                        '${change.notes?.isNotEmpty == true ? '\n${change.notes}' : ''}',
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'expelled':
        return Colors.red;
      case 'graduated':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'suspended':
        return 'موقوف';
      case 'expelled':
        return 'مفصول';
      case 'graduated':
        return 'متخرج';
      case 'inactive':
        return 'سابق';
      default:
        return status;
    }
  }
}

class _ArchivedStudentEntry {
  final Student student;
  final StudentStatusChange? latestChange;

  const _ArchivedStudentEntry({
    required this.student,
    required this.latestChange,
  });
}
