import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/plan.dart';
import '../../models/plan_recitation_record.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/quran_cross_surah_range_service.dart';
import '../../services/quran_service.dart';
import '../../widgets/app_design_widgets.dart';
import '../../widgets/ayah_range_picker.dart';

class PlanRecitationScreen extends StatefulWidget {
  final SmartPlan plan;
  final Student student;

  const PlanRecitationScreen({
    super.key,
    required this.plan,
    required this.student,
  });

  @override
  State<PlanRecitationScreen> createState() => _PlanRecitationScreenState();
}

class _PlanRecitationScreenState extends State<PlanRecitationScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  final TextEditingController _notesController = TextEditingController();
  List<PlanRecitationRecord> _records = [];
  QuranCrossSurahRange? _suggestedRange;
  late DateTime _selectedDate;
  int _startSurahId = 1;
  int _startAyah = 1;
  int _qualityRating = 3;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _ascending => widget.student.memorizationDirection != 'desc';

  @override
  void initState() {
    super.initState();
    _selectedDate = _clampDate(DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveCursor = false}) async {
    if (mounted) setState(() => _isLoading = true);
    await _quran.initialize();
    final records = await _db.getPlanRecitationRecords(widget.plan.id);
    if (!preserveCursor) {
      final next = _nextStartingPoint(records);
      _startSurahId = next.$1;
      _startAyah = next.$2;
    }
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
      _rebuildRange();
    });
  }

  (int, int) _nextStartingPoint(List<PlanRecitationRecord> records) {
    if (records.isEmpty) return (_ascending ? 1 : 114, 1);
    final latestRecord = records.reduce(
      (left, right) => left.createdAt.isAfter(right.createdAt) ? left : right,
    );
    final latest = records
        .where((record) => record.sessionId == latestRecord.sessionId)
        .toList()
      ..sort((left, right) => left.segmentOrder.compareTo(right.segmentOrder));
    final last = latest.last;
    final surah = _quran.getSurah(last.surahId);
    if (surah != null && last.toAyah < surah.totalAyahs) {
      return (last.surahId, last.toAyah + 1);
    }
    final nextSurah = _ascending ? last.surahId + 1 : last.surahId - 1;
    if (nextSurah >= 1 && nextSurah <= 114) return (nextSurah, 1);
    return (_ascending ? 1 : 114, 1);
  }

  void _rebuildRange() {
    _suggestedRange = QuranCrossSurahRangeService.toAmount(
      surahs: _quran.surahs,
      startSurahId: _startSurahId,
      startAyah: _startAyah,
      unit: QuranCrossSurahRangeService.unitFromPlanType(widget.plan.unit),
      amount: widget.plan.recitationAmount,
      ascendingSurahs: _ascending,
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: _date(widget.plan.startDate),
      lastDate: _date(widget.plan.endDate),
    );
    if (selected != null && mounted) {
      setState(() => _selectedDate = selected);
    }
  }

  Future<void> _save() async {
    final range = _suggestedRange;
    if (range == null || range.segments.isEmpty || !widget.plan.isActive) {
      _message(
        widget.plan.isActive
            ? 'تعذر تكوين نطاق السرد من نقطة البداية'
            : 'الخطة غير نشطة؛ السجل متاح للعرض فقط',
        error: true,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      final sessionId = const Uuid().v4();
      final createdAt = DateTime.now();
      final notes = _notesController.text.trim();
      final rows = <PlanRecitationRecord>[
        for (var index = 0; index < range.segments.length; index++)
          PlanRecitationRecord(
            sessionId: sessionId,
            planId: widget.plan.id,
            studentId: widget.student.id,
            surahId: range.segments[index].surahId,
            fromAyah: range.segments[index].fromAyah,
            toAyah: range.segments[index].toAyah,
            segmentOrder: index,
            date: _selectedDate,
            qualityRating: _qualityRating,
            notes: notes.isEmpty ? null : notes,
            createdAt: createdAt,
            updatedAt: createdAt,
          ),
      ];
      await _db.savePlanRecitationSession(rows);
      _notesController.clear();
      _message('تم حفظ السرد وإضافته إلى إنجاز الخطة');
      await _load();
    } catch (error) {
      _message('تعذر حفظ السرد: $error', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const AppDialogTitle(
              icon: Icons.delete_outline,
              title: 'حذف جلسة السرد؟',
              iconColor: Colors.red,
            ),
            content: const Text(
              'سيُحذف كل نطاق الجلسة وتُعاد نسبة إنجاز الخطة تلقائيًا.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('رجوع'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _db.deletePlanRecitationSession(sessionId);
    await _load();
  }

  Map<String, List<PlanRecitationRecord>> get _sessions {
    final result = <String, List<PlanRecitationRecord>>{};
    for (final record in _records) {
      result.putIfAbsent(record.sessionId, () => []).add(record);
    }
    for (final rows in result.values) {
      rows.sort((left, right) => left.segmentOrder.compareTo(right.segmentOrder));
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('السرد والتلاوة المرتبط بالخطة')),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  AppPageIntro(
                    title: widget.student.name,
                    subtitle:
                        'يسجل هذا القسم التلاوة فقط؛ لا يزيد محفوظ الطالب ولا يمنحها حكم الحفظ.',
                    icon: Icons.record_voice_over_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildEntryCard(),
                  const SizedBox(height: 20),
                  AppSectionHeader(
                    title: 'سجل السرد',
                    subtitle: '${_sessions.length} جلسة محفوظة لهذه الخطة',
                  ),
                  const SizedBox(height: 10),
                  if (_sessions.isEmpty)
                    const AppEmptyState(
                      icon: Icons.auto_stories_outlined,
                      title: 'لا توجد جلسات سرد بعد',
                      message: 'اختر نقطة البداية ثم اعتمد المقرر اليومي.',
                    )
                  else
                    for (final entry in _sessions.entries)
                      _buildSessionCard(entry.key, entry.value),
                ],
              ),
      ),
    );
  }

  Widget _buildEntryCard() {
    final surah = _quran.getSurah(_startSurahId)!;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionHeader(
              title: 'تسجيل جلسة جديدة',
              subtitle: 'يُنشأ نطاق متصل تلقائيًا بحسب مقدار السرد في الخطة.',
            ),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('تاريخ الجلسة'),
              subtitle: Text(_dateLabel(_selectedDate)),
              trailing: TextButton(
                onPressed: widget.plan.isActive ? _pickDate : null,
                child: const Text('تغيير'),
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _startSurahId,
              decoration: const InputDecoration(
                labelText: 'سورة البداية',
                prefixIcon: Icon(Icons.menu_book_outlined),
              ),
              items: [
                for (final item in _quran.surahs)
                  DropdownMenuItem(
                    value: item.number,
                    child: Text('${item.number}. ${item.name}'),
                  ),
              ],
              onChanged: widget.plan.isActive
                  ? (value) {
                      if (value == null) return;
                      setState(() {
                        _startSurahId = value;
                        _startAyah = 1;
                        _rebuildRange();
                      });
                    }
                  : null,
            ),
            const SizedBox(height: 14),
            AyahRangePicker(
              key: ValueKey('$_startSurahId-$_startAyah'),
              maxAyahs: surah.totalAyahs,
              initialFrom: _startAyah,
              initialTo: _startAyah,
              singleValue: true,
              enabled: widget.plan.isActive,
              onRangeChanged: (from, _) {
                setState(() {
                  _startAyah = from;
                  _rebuildRange();
                });
              },
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.route_outlined,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _rangeLabel(_suggestedRange),
                      style: TextStyle(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<int>(
              initialValue: _qualityRating,
              decoration: const InputDecoration(
                labelText: 'جودة التلاوة',
                prefixIcon: Icon(Icons.star_outline),
              ),
              items: const [
                DropdownMenuItem(value: 5, child: Text('ممتاز')),
                DropdownMenuItem(value: 4, child: Text('جيد جدًا')),
                DropdownMenuItem(value: 3, child: Text('جيد')),
                DropdownMenuItem(value: 2, child: Text('يحتاج متابعة')),
                DropdownMenuItem(value: 1, child: Text('يحتاج إعادة')),
              ],
              onChanged: widget.plan.isActive
                  ? (value) => setState(() => _qualityRating = value ?? 3)
                  : null,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              enabled: widget.plan.isActive,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'ملاحظات اختيارية',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: widget.plan.isActive && !_isSaving ? _save : null,
              icon: _isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.task_alt),
              label: Text(
                widget.plan.isActive
                    ? 'اعتماد السرد إلى نهاية المقرر'
                    : 'الخطة غير نشطة — عرض فقط',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCard(
    String sessionId,
    List<PlanRecitationRecord> rows,
  ) {
    final first = rows.first;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Text('${first.qualityRating}'),
        ),
        title: Text(_sessionRangeLabel(rows)),
        subtitle: Text(
          '${_dateLabel(first.date)} · ${_qualityLabel(first.qualityRating)}'
          '${first.notes?.trim().isNotEmpty == true ? '\n${first.notes}' : ''}',
        ),
        isThreeLine: first.notes?.trim().isNotEmpty == true,
        trailing: IconButton(
          tooltip: 'حذف الجلسة',
          onPressed: () => _deleteSession(sessionId),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      ),
    );
  }

  String _rangeLabel(QuranCrossSurahRange? range) {
    if (range == null || range.segments.isEmpty) return 'لا يوجد نطاق متاح';
    final first = range.segments.first;
    final last = range.segments.last;
    final prefix =
        'المقرر: ${widget.plan.recitationAmount} ${_unitLabel(widget.plan.unit)}';
    if (first.surahId == last.surahId) {
      return '$prefix\n${_quran.getSurahName(first.surahId)} '
          'من ${first.fromAyah} إلى ${last.toAyah}';
    }
    return '$prefix\n${_quran.getSurahName(first.surahId)} ${first.fromAyah} — '
        '${_quran.getSurahName(last.surahId)} ${last.toAyah}';
  }

  String _sessionRangeLabel(List<PlanRecitationRecord> rows) {
    final first = rows.first;
    final last = rows.last;
    if (first.surahId == last.surahId) {
      return '${_quran.getSurahName(first.surahId)} '
          '${first.fromAyah} — ${last.toAyah}';
    }
    return '${_quran.getSurahName(first.surahId)} ${first.fromAyah} — '
        '${_quran.getSurahName(last.surahId)} ${last.toAyah}';
  }

  DateTime _clampDate(DateTime value) {
    final day = _date(value);
    final start = _date(widget.plan.startDate);
    final end = _date(widget.plan.endDate);
    if (day.isBefore(start)) return start;
    if (day.isAfter(end)) return end;
    return day;
  }

  DateTime _date(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateLabel(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/'
      '${value.day.toString().padLeft(2, '0')}';

  String _unitLabel(String unit) {
    if (unit == 'pages') return 'صفحة';
    if (unit == 'lines') return 'سطرًا';
    if (unit == 'hizbs') return 'حزبًا';
    return 'آية';
  }

  String _qualityLabel(int value) {
    if (value >= 5) return 'ممتاز';
    if (value == 4) return 'جيد جدًا';
    if (value == 3) return 'جيد';
    if (value == 2) return 'يحتاج متابعة';
    return 'يحتاج إعادة';
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: error ? Colors.red : Colors.green,
      ),
    );
  }
}
