import 'package:flutter/material.dart';

import '../../models/memorization.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/quran_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../widgets/surah_picker.dart';

class RecitationHistoryScreen extends StatefulWidget {
  final Student? initialStudent;

  const RecitationHistoryScreen({super.key, this.initialStudent});

  @override
  State<RecitationHistoryScreen> createState() =>
      _RecitationHistoryScreenState();
}

class _RecitationHistoryScreenState extends State<RecitationHistoryScreen> {
  final DatabaseService _db = DatabaseService();
  final MushafService _mushaf = MushafService();
  final QuranService _quran = QuranService.instance;

  List<Student> _students = [];
  List<MemorizationProgress> _records = [];
  String? _studentId;
  String _type = 'all';
  String _query = '';
  DateTimeRange? _range;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _studentId = widget.initialStudent?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait<dynamic>([
      _db.getStudents(),
      _db.getAllMemorizationProgress(),
    ]);
    if (!mounted) return;
    setState(() {
      _students = results[0] as List<Student>;
      _records = (results[1] as List<MemorizationProgress>)
        ..sort((a, b) {
          final byDate = b.date.compareTo(a.date);
          return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
        });
      _isLoading = false;
    });
  }

  List<MemorizationProgress> get _filteredRecords {
    return _records.where((record) {
      if (_studentId != null && record.studentId != _studentId) return false;
      if (_type == 'memorization' && record.isRevision) return false;
      if (_type == 'revision' && !record.isRevision) return false;
      if (_range != null) {
        final date = DateTime(record.date.year, record.date.month, record.date.day);
        final start = DateTime(
          _range!.start.year,
          _range!.start.month,
          _range!.start.day,
        );
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      if (_query.isNotEmpty) {
        final studentName = _studentName(record.studentId);
        final surahName = _quran.getSurahName(record.surahId);
        if (!studentName.contains(_query) && !surahName.contains(_query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRecords;
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التسميع والمراجعة')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFilters(),
                _buildSummary(filtered),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('لا توجد سجلات مطابقة'))
                      : RefreshIndicator(
                          onRefresh: _loadData,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) =>
                                _buildRecordCard(filtered[index]),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                hintText: 'بحث باسم الطالب أو السورة',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _studentId ?? 'all',
              decoration: const InputDecoration(
                labelText: 'الطالب',
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: 'all',
                  child: Text('جميع الطلاب'),
                ),
                ..._students.map((student) => DropdownMenuItem<String>(
                      value: student.id,
                      child: Text(student.name),
                    )),
              ],
              onChanged: (value) => setState(
                () => _studentId = value == 'all' ? null : value,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _typeChip('الكل', 'all'),
                _typeChip('حفظ جديد', 'memorization'),
                _typeChip('مراجعة', 'revision'),
                InputChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    _range == null
                        ? 'كل التواريخ'
                        : '${_date(_range!.start)} — ${_date(_range!.end)}',
                  ),
                  onSelected: (_) => _pickRange(),
                  onDeleted: _range == null
                      ? null
                      : () => setState(() => _range = null),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String label, String value) => ChoiceChip(
        label: Text(label),
        selected: _type == value,
        onSelected: (_) => setState(() => _type = value),
      );

  Widget _buildSummary(List<MemorizationProgress> records) {
    final memorization = records.where((record) => !record.isRevision).length;
    final revision = records.where((record) => record.isRevision).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summaryItem('السجلات', records.length, Colors.blue),
          _summaryItem('الحفظ', memorization, Colors.green),
          _summaryItem('المراجعة', revision, Colors.orange),
        ],
      ),
    );
  }

  Widget _summaryItem(String label, int value, Color color) => Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      );

  Widget _buildRecordCard(MemorizationProgress record) {
    final color = record.isRevision ? Colors.orange : Colors.green;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(
                    record.isRevision ? Icons.replay : Icons.menu_book,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _studentName(record.studentId),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '${Helpers.getFullHijriDate(record.date)} — '
                        '${record.isRevision ? 'مراجعة' : 'حفظ جديد'}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'edit') _editRecord(record);
                    if (action == 'delete') _deleteRecord(record);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('تعديل السجل')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text('حذف السجل', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Text(
              'سورة ${_quran.getSurahName(record.surahId)} — '
              'من آية ${record.fromAyah} إلى ${record.toAyah}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('عدد الآيات: ${record.ayahCount}'),
                const SizedBox(width: 16),
                Text('التقييم: ${record.qualityRating}/5'),
              ],
            ),
            if (record.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text('ملاحظة: ${record.notes}'),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange: _range ??
          DateTimeRange(
            start: DateTime(today.year, today.month, 1),
            end: today,
          ),
    );
    if (range != null) setState(() => _range = range);
  }

  Future<void> _editRecord(MemorizationProgress original) async {
    var surahId = original.surahId;
    var fromAyah = original.fromAyah;
    var toAyah = original.toAyah;
    var date = original.date;
    var quality = original.qualityRating;
    var isRevision = original.isRevision;
    final notesController = TextEditingController(text: original.notes ?? '');

    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final surah = _quran.getSurah(surahId)!;
          return AlertDialog(
            title: const Text('تعديل سجل التسميع'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.menu_book),
                      title: Text('سورة ${surah.name}'),
                      trailing: const Icon(Icons.arrow_drop_down),
                      onTap: () async {
                        final selected = await showSurahPicker(
                          context,
                          selectedSurahId: surahId,
                          title: 'اختر السورة',
                        );
                        if (selected != null) {
                          setDialogState(() {
                            surahId = selected;
                            fromAyah = 1;
                            toAyah = _quran.getSurah(selected)?.totalAyahs ?? 1;
                          });
                        }
                      },
                    ),
                    AyahRangePicker(
                      key: ValueKey('$surahId-$fromAyah-$toAyah'),
                      maxAyahs: surah.totalAyahs,
                      initialFrom: fromAyah,
                      initialTo: toAyah,
                      onRangeChanged: (from, to) {
                        fromAyah = from;
                        toAyah = to;
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('هذا السجل مراجعة'),
                      value: isRevision,
                      onChanged: (value) =>
                          setDialogState(() => isRevision = value),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today),
                      title: const Text('تاريخ السجل'),
                      subtitle: Text(_date(date)),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: context,
                          initialDate: date,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (selected != null) {
                          setDialogState(() => date = selected);
                        }
                      },
                    ),
                    Row(
                      children: [
                        const Text('التقييم'),
                        Expanded(
                          child: Slider(
                            value: quality.toDouble(),
                            min: 1,
                            max: 5,
                            divisions: 4,
                            label: '$quality/5',
                            onChanged: (value) => setDialogState(
                              () => quality = value.round(),
                            ),
                          ),
                        ),
                        Text('$quality/5'),
                      ],
                    ),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'الملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ التعديل'),
              ),
            ],
          );
        },
      ),
    );
    if (accepted == true) {
      try {
        final updated = original.copyWith(
          surahId: surahId,
          fromAyah: fromAyah,
          toAyah: toAyah,
          date: date,
          qualityRating: quality,
          isRevision: isRevision,
          notes: notesController.text.trim(),
          clearNotes: notesController.text.trim().isEmpty,
        );
        await _db.updateMemorizationProgress(original, updated);
        final mapRebuilt = await _rebuildMushafSafely(original.studentId);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                mapRebuilt
                    ? 'تم تعديل السجل وإعادة الحساب'
                    : 'تم تعديل السجل، وتعذر تحديث الخريطة؛ أعد المحاولة لاحقًا',
              ),
              backgroundColor: mapRebuilt ? Colors.green : Colors.orange,
            ),
          );
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر تعديل السجل: $error')),
          );
        }
      }
    }
    notesController.dispose();
  }

  Future<void> _deleteRecord(MemorizationProgress record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف سجل التسميع؟'),
        content: Text(
          'سيُحذف سجل ${_studentName(record.studentId)} في '
          '${_date(record.date)}، ثم يعاد حساب اليوم وإجمالي المحفوظ.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف وإعادة الحساب'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _db.deleteMemorizationProgress(record);
      final mapRebuilt = await _rebuildMushafSafely(record.studentId);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              mapRebuilt
                  ? 'تم حذف السجل وإعادة الحساب'
                  : 'تم حذف السجل، وتعذر تحديث الخريطة؛ أعد المحاولة لاحقًا',
            ),
            backgroundColor: mapRebuilt ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حذف السجل: $error')),
        );
      }
    }
  }

  Future<bool> _rebuildMushafSafely(String studentId) async {
    try {
      await _mushaf.rebuildStudentProgress(studentId);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _studentName(String id) {
    for (final student in _students) {
      if (student.id == id) return student.name;
    }
    return 'طالب غير متاح';
  }

  String _date(DateTime date) =>
      '${date.year}/${date.month.toString().padLeft(2, '0')}/'
      '${date.day.toString().padLeft(2, '0')}';
}
