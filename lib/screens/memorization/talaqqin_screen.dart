import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/daily_record.dart';
import '../../models/student.dart';
import '../../models/talaqqin_record.dart';
import '../../services/database_service.dart';
import '../../services/quran_cross_surah_range_service.dart';
import '../../services/quran_service.dart';
import '../../services/memorization_progression_service.dart';
import '../../services/student_learning_policy.dart';
import '../../services/recitation_attendance_guard.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../widgets/quran_endpoint_picker.dart';
import '../../widgets/surah_picker.dart';

class TalaqqinScreen extends StatefulWidget {
  const TalaqqinScreen({super.key, required this.student});

  final Student student;

  @override
  State<TalaqqinScreen> createState() => _TalaqqinScreenState();
}

class _TalaqqinScreenState extends State<TalaqqinScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  final TextEditingController _notesController = TextEditingController();
  int? _surahId;
  int _fromAyah = 1;
  int _toAyah = 1;
  QuranCrossSurahRange? _range;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _quran.initialize();
    final progress = await _db.getStudentMemorization(widget.student.id);
    final start = MemorizationProgressionService.nextStartingPoint(
      student: widget.student,
      progress: progress,
      getSurah: _quran.getSurah,
    );
    if (!mounted) return;
    setState(() {
      _surahId = start?['surahId'] ??
          (_quran.surahs.isEmpty ? null : _quran.surahs.first.number);
      _fromAyah = start?['fromAyah'] ?? 1;
      _toAyah = _fromAyah;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  QuranCrossSurahRange? get _effectiveRange {
    if (_range != null) return _range;
    if (_surahId == null) return null;
    return QuranCrossSurahRangeService.fromAyahs(
      _quran.getAyahRange(_surahId!, _fromAyah, _toAyah),
    );
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surahId == null ? null : _quran.getSurah(_surahId!);
    final range = _effectiveRange;
    final eligible = StudentLearningPolicy.canReceiveTalaqqin(widget.student);
    return Scaffold(
      appBar: AppBar(
        title: Text('التلقين — ${widget.student.name}'),
        actions: eligible
            ? [
                IconButton(
                  tooltip: 'إنهاء مرحلة التلقين',
                  onPressed: _finishTalaqqinStage,
                  icon: const Icon(Icons.flag_outlined),
                ),
              ]
            : null,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !eligible
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'هذا الطالب ليس في مرحلة التلقين. فعّل مرحلة التلقين من ملف الطالب عند الحاجة.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.record_voice_over_outlined),
                      title: const Text('جلسة تلقين'),
                      subtitle: const Text(
                        'سجل ما لقّنه المعلم للطالب دون إضافته إلى المحفوظ أو المراجعة.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(surah == null
                          ? 'اختر السورة'
                          : 'سورة ${surah.name}'),
                      subtitle: const Text('نقطة بداية التلقين'),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: _selectSurah,
                    ),
                  ),
                  if (surah != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AyahRangePicker(
                          key: ValueKey(_surahId),
                          maxAyahs: surah.totalAyahs,
                          initialFrom: _fromAyah,
                          initialTo: _toAyah,
                          onRangeChanged: (from, to) => setState(() {
                            _fromAyah = from;
                            _toAyah = to;
                            _range = null;
                          }),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _selectCrossSurahEnd,
                      icon: const Icon(Icons.route_outlined),
                      label: const Text('تحديد النهاية في سورة أخرى'),
                    ),
                  ],
                  if (range != null) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.format_list_numbered),
                        title: Text('${range.ayahs.length} آية'),
                        subtitle: Text(_rangeLabel(range)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظات التلقين (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: const Text('حفظ جلسة التلقين'),
                  ),
                ],
              ),
            ),
    );
  }


  Future<void> _finishTalaqqinStage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إنهاء مرحلة التلقين'),
        content: Text(
          'سيخرج ${widget.student.name} من قائمة التلقين، وتبقى جميع جلساته السابقة محفوظة. يمكن إعادة تفعيل المرحلة لاحقًا من ملف الطالب.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء المرحلة'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _db.updateStudent(widget.student.copyWith(talaqqinEnabled: false));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إنهاء مرحلة التلقين للطالب')),
    );
    Navigator.pop(context, true);
  }

  Future<void> _selectSurah() async {
    final selected = await showSurahPicker(
      context,
      selectedSurahId: _surahId,
      title: 'اختر سورة التلقين',
    );
    if (selected == null) return;
    setState(() {
      _surahId = selected;
      _fromAyah = 1;
      _toAyah = 1;
      _range = null;
    });
  }

  Future<void> _selectCrossSurahEnd() async {
    final start = _surahId;
    if (start == null) return;
    final endpoint = await showQuranEndpointPicker(
      context,
      initialSurahId: start,
      initialAyah: _toAyah,
      title: 'نهاية التلقين',
    );
    if (endpoint == null || !mounted) return;
    final range = QuranCrossSurahRangeService.between(
      surahs: _quran.surahs,
      startSurahId: start,
      startAyah: _fromAyah,
      endSurahId: endpoint.surahId,
      endAyah: endpoint.ayah,
      ascendingSurahs: widget.student.memorizationDirection != 'desc',
    );
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نهاية التلقين لا تقع بعد البداية')),
      );
      return;
    }
    setState(() {
      _range = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  Future<void> _save() async {
    final range = _effectiveRange;
    if (range == null || range.ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدد نطاق التلقين أولًا')),
      );
      return;
    }
    final canRecord = await RecitationAttendanceGuard.confirmPresentIfAbsent(
      context,
      database: _db,
      student: widget.student,
    );
    if (!canRecord || !mounted) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final sessionId = const Uuid().v4();
      final note = _notesController.text.trim();
      final rows = range.segments
          .map(
            (segment) => TalaqqinRecord(
              sessionId: sessionId,
              studentId: widget.student.id,
              surahId: segment.surahId,
              fromAyah: segment.fromAyah,
              toAyah: segment.toAyah,
              date: now,
              notes: note.isEmpty ? null : note,
            ),
          )
          .toList();
      final existing = await _db.getDailyRecord(widget.student.id, now);
      final daily = (existing ?? DailyRecord(
        studentId: widget.student.id,
        date: now,
      )).copyWith(
        attendance: 'present',
        arrivalTime: existing?.arrivalTime ?? now,
        clearAbsenceReason: true,
        clearAbsenceNote: true,
        talaqqinDone: true,
        talaqqinAmount: (existing?.talaqqinAmount ?? 0) + range.ayahs.length,
        talaqqinNote: note.isEmpty ? existing?.talaqqinNote : note,
      );
      await _db.saveTalaqqinSession(records: rows, dailyRecord: daily);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ التلقين دون إضافته إلى المحفوظ'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ التلقين: $error')),
      );
    }
  }

  String _rangeLabel(QuranCrossSurahRange range) {
    final first = range.ayahs.first;
    final last = range.ayahs.last;
    final firstName = _quran.getSurahName(first.surahNumber);
    final lastName = _quran.getSurahName(last.surahNumber);
    if (first.surahNumber == last.surahNumber) {
      return 'سورة $firstName: ${first.number}–${last.number}';
    }
    return 'من $firstName (${first.number}) إلى $lastName (${last.number})';
  }
}
