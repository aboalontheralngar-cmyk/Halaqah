import 'package:flutter/material.dart';
import '../../models/daily_achievement.dart';
import '../../models/student.dart';
import '../../services/daily_excellence_service.dart';
import '../../services/database_service.dart';
import '../../services/quran_service.dart';
import '../../utils/helpers.dart';

class DailyExcellenceScreen extends StatefulWidget {
  const DailyExcellenceScreen({super.key});

  @override
  State<DailyExcellenceScreen> createState() => _DailyExcellenceScreenState();
}

class _DailyExcellenceScreenState extends State<DailyExcellenceScreen> {
  final DatabaseService _db = DatabaseService();
  DateTime _selectedDate = DateTime.now();
  List<Student> _students = [];
  List<_DailyExcellenceEntry> _entries = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() => _isLoading = true);
    try {
      await QuranService.instance.initialize();
      final students = await _db.getStudents(status: 'active');
      final saved = await _db.getDailyAchievements(_selectedDate);
      final savedByStudent = {for (final item in saved) item.studentId: item};
      final entries = <_DailyExcellenceEntry>[];
      final surahs = {
        for (final surah in QuranService.instance.surahs)
          surah.number: surah,
      };

      for (final student in students) {
        final progress = await _db.getStudentMemorizationInRange(
          student.id,
          _selectedDate,
          _selectedDate,
        );
        final actual = DailyExcellenceService.calculateActualAmount(
          progress: progress,
          surahs: surahs,
          unit: student.planType,
        );
        final qualifies = DailyExcellenceService.qualifies(
          actualAmount: actual,
          planAmount: student.planAmount.toDouble(),
        );
        final stored = savedByStudent.remove(student.id);
        if (qualifies) {
          final automatic = DailyAchievement(
            id: stored?.id,
            studentId: student.id,
            date: _selectedDate,
            source: 'automatic',
            reason: stored?.reason ?? 'تجاوز المقرر اليومي',
            actualAmount: actual,
            planAmount: student.planAmount.toDouble(),
            unit: student.planType,
            rewardType: stored?.rewardType,
            rewardDetails: stored?.rewardDetails,
            rewardPoints: stored?.rewardPoints ?? 0,
            awardedAt: stored?.awardedAt,
            notes: stored?.notes,
            createdAt: stored?.createdAt,
            updatedAt: stored?.updatedAt,
          );
          entries.add(_DailyExcellenceEntry(
            student: student,
            achievement: automatic,
            isLiveAutomatic: true,
          ));
        } else if (stored != null) {
          entries.add(_DailyExcellenceEntry(
            student: student,
            achievement: stored,
          ));
        }
      }

      for (final orphan in savedByStudent.values) {
        final student = await _db.getStudent(orphan.studentId);
        if (student != null) {
          entries.add(_DailyExcellenceEntry(
            student: student,
            achievement: orphan,
          ));
        }
      }

      entries.sort((a, b) {
        if (a.achievement.isAutomatic != b.achievement.isAutomatic) {
          return a.achievement.isAutomatic ? -1 : 1;
        }
        final aExtra = a.achievement.actualAmount - a.achievement.planAmount;
        final bExtra = b.achievement.actualAmount - b.achievement.planAmount;
        return bExtra.compareTo(aExtra);
      });
      if (!mounted) return;
      setState(() {
        _students = students;
        _entries = entries;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<_DailyExcellenceEntry> get _filteredEntries {
    if (_filter == 'automatic') {
      return _entries.where((entry) => entry.achievement.isAutomatic).toList();
    }
    if (_filter == 'manual') {
      return _entries.where((entry) => !entry.achievement.isAutomatic).toList();
    }
    if (_filter == 'rewarded') {
      return _entries.where((entry) => entry.achievement.isRewarded).toList();
    }
    return _entries;
  }

  @override
  Widget build(BuildContext context) {
    final automaticCount =
        _entries.where((entry) => entry.achievement.isAutomatic).length;
    final rewardedCount =
        _entries.where((entry) => entry.achievement.isRewarded).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('متميزو اليوم'),
        actions: [
          IconButton(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'اختيار التاريخ',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _statCard('تلقائي', '$automaticCount', Icons.auto_awesome, Colors.teal),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard('إجمالي', '${_entries.length}', Icons.workspace_premium, Colors.amber),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _statCard('كوفئوا', '$rewardedCount', Icons.card_giftcard, Colors.purple),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _filterChip('all', 'الكل'),
                _filterChip('automatic', 'تجاوزوا المقرر'),
                _filterChip('manual', 'إضافة المعلم'),
                _filterChip('rewarded', 'تم تكريمهم'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadEntries,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          itemCount: _filteredEntries.length,
                          itemBuilder: (context, index) =>
                              _buildEntryCard(_filteredEntries[index]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addManualAchievement,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة متميز'),
      ),
    );
  }

  Widget _buildDateHeader() => Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            IconButton(
              onPressed: () => _changeDate(-1),
              icon: const Icon(Icons.chevron_right),
            ),
            Expanded(
              child: Column(
                children: [
                  const Text('تميز الحلقة في', style: TextStyle(fontSize: 12)),
                  Text(
                    Helpers.getFullHijriDate(_selectedDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _isToday(_selectedDate) ? null : () => _changeDate(1),
              icon: const Icon(Icons.chevron_left),
            ),
          ],
        ),
      );

  Widget _statCard(String label, String value, IconData icon, Color color) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      );

  Widget _filterChip(String value, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: ChoiceChip(
          selected: _filter == value,
          label: Text(label),
          onSelected: (_) => setState(() => _filter = value),
        ),
      );

  Widget _buildEmptyState() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text('لا يوجد متميزون مسجلون في هذا اليوم'),
            const SizedBox(height: 6),
            const Text('سيظهر من تجاوز مقرره تلقائيًا، ويمكن للمعلم إضافة آخرين.'),
          ],
        ),
      );

  Widget _buildEntryCard(_DailyExcellenceEntry entry) {
    final achievement = entry.achievement;
    final extra = DailyExcellenceService.exceededBy(
      actualAmount: achievement.actualAmount,
      planAmount: achievement.planAmount,
    );
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
                  backgroundColor: Colors.amber.withOpacity(0.16),
                  child: Text(entry.student.name.isEmpty ? '؟' : entry.student.name[0]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(achievement.reason, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
                if (achievement.isAutomatic)
                  const Chip(
                    avatar: Icon(Icons.auto_awesome, size: 16),
                    label: Text('تلقائي'),
                  ),
              ],
            ),
            if (achievement.isAutomatic) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: achievement.planAmount <= 0
                    ? 1
                    : ((achievement.actualAmount / achievement.planAmount)
                                .clamp(0, 2)
                                .toDouble() /
                            2),
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 8),
              Text(
                'أنجز ${_formatAmount(achievement.actualAmount)} ${_unitLabel(achievement.unit)} '
                'من مقرر ${_formatAmount(achievement.planAmount)} — زيادة ${_formatAmount(extra)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if (achievement.isRewarded) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🎁 ${_rewardLabel(achievement.rewardType!)}'
                  '${achievement.rewardPoints > 0 ? ' (${achievement.rewardPoints} نقطة)' : ''}'
                  '${achievement.rewardDetails?.isNotEmpty == true ? ' — ${achievement.rewardDetails}' : ''}',
                ),
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                onPressed: () => _showRewardDialog(entry),
                icon: Icon(achievement.isRewarded ? Icons.edit : Icons.card_giftcard),
                label: Text(achievement.isRewarded ? 'تعديل التكريم' : 'تكريم الطالب'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addManualAchievement() async {
    Student? selected;
    final reasonController = TextEditingController();
    final notesController = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة متميز يدويًا'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Student>(
                value: selected,
                decoration: const InputDecoration(labelText: 'الطالب'),
                items: _students.map((student) => DropdownMenuItem(
                      value: student,
                      child: Text(student.name),
                    )).toList(),
                onChanged: (value) => setDialogState(() => selected = value),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب التميز (إلزامي)',
                  hintText: 'مثال: حسن التعاون أو الإتقان أو المبادرة',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (selected == null || reasonController.text.trim().isEmpty) return;
                Navigator.pop(context, true);
              },
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
    final reason = reasonController.text.trim();
    final notes = notesController.text.trim();
    reasonController.dispose();
    notesController.dispose();
    if (accepted != true || selected == null || reason.isEmpty) return;
    await _db.saveDailyAchievement(DailyAchievement(
      studentId: selected!.id,
      date: _selectedDate,
      source: 'manual',
      reason: reason,
      planAmount: selected!.planAmount.toDouble(),
      unit: selected!.planType,
      notes: notes.isEmpty ? null : notes,
    ));
    await _loadEntries();
  }

  Future<void> _showRewardDialog(_DailyExcellenceEntry entry) async {
    var rewardType = entry.achievement.rewardType ?? 'points';
    var rewardPoints = entry.achievement.rewardPoints > 0
        ? entry.achievement.rewardPoints
        : 5;
    final detailsController = TextEditingController(
      text: entry.achievement.rewardDetails ?? '',
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تكريم ${entry.student.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: rewardType,
                decoration: const InputDecoration(labelText: 'نوع التكريم'),
                items: const [
                  DropdownMenuItem(value: 'points', child: Text('نقاط مكافأة')),
                  DropdownMenuItem(value: 'certificate', child: Text('شهادة شكر')),
                  DropdownMenuItem(value: 'gift', child: Text('هدية')),
                  DropdownMenuItem(value: 'meal', child: Text('وجبة/عشاء جماعي')),
                  DropdownMenuItem(value: 'other', child: Text('تكريم آخر')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => rewardType = value);
                },
              ),
              if (rewardType == 'points') ...[
                const SizedBox(height: 12),
                TextFormField(
                  initialValue: '$rewardPoints',
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'عدد النقاط'),
                  onChanged: (value) => rewardPoints = int.tryParse(value) ?? 0,
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: detailsController,
                decoration: const InputDecoration(
                  labelText: 'تفاصيل التكريم',
                  hintText: 'مثال: عشاء المجموعة يوم الخميس',
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (rewardType == 'points' && rewardPoints < 1) return;
                Navigator.pop(context, true);
              },
              child: const Text('اعتماد التكريم'),
            ),
          ],
        ),
      ),
    );
    final details = detailsController.text.trim();
    detailsController.dispose();
    if (accepted != true) return;
    await _db.awardDailyAchievement(
      achievement: entry.achievement,
      rewardType: rewardType,
      rewardDetails: details.isEmpty ? null : details,
      rewardPoints: rewardType == 'points' ? rewardPoints : 0,
    );
    await _loadEntries();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _selectedDate = picked);
    await _loadEntries();
  }

  Future<void> _changeDate(int days) async {
    final next = _selectedDate.add(Duration(days: days));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = next);
    await _loadEntries();
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  String _formatAmount(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);

  String _unitLabel(String unit) {
    if (unit == 'pages') return 'صفحة';
    if (unit == 'lines') return 'سطرًا';
    return 'آية';
  }

  String _rewardLabel(String type) {
    if (type == 'points') return 'نقاط مكافأة';
    if (type == 'certificate') return 'شهادة شكر';
    if (type == 'gift') return 'هدية';
    if (type == 'meal') return 'وجبة/عشاء جماعي';
    return 'تكريم آخر';
  }
}

class _DailyExcellenceEntry {
  final Student student;
  final DailyAchievement achievement;
  final bool isLiveAutomatic;

  const _DailyExcellenceEntry({
    required this.student,
    required this.achievement,
    this.isLiveAutomatic = false,
  });
}
