import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../app/theme.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/memorization_progression_service.dart';
import '../../services/quran_cross_surah_range_service.dart';
import '../../services/student_learning_policy.dart';
import '../../services/recitation_flow_coordinator.dart';
import '../../services/recitation_attendance_guard.dart';
import '../../services/backdated_entry_policy.dart';
import '../../services/share_file_name_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/ayah.dart';
import '../../models/homework_grade.dart';
import '../../widgets/surah_picker.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../widgets/quran_endpoint_picker.dart';
import '../../widgets/app_design_widgets.dart';
import '../../utils/helpers.dart';
import '../../utils/color_contrast.dart';

class RecitationScreen extends StatefulWidget {
  final Student student;

  const RecitationScreen({super.key, required this.student});

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final QuranService _quran = QuranService.instance;
  final DatabaseService _db = DatabaseService();

  int? _selectedSurahId;
  int _fromAyah = 1;
  int _toAyah = 1;
  int _currentAyahIndex = 0;
  bool _showFullText = false;
  bool _isSaving = false;
  bool _ownsRecitationFlow = false;
  List<Ayah> _ayahs = [];
  Map<int, int> _ayahRatings = {};
  bool _openEnded = true;
  QuranCrossSurahRange? _suggestedPlanRange;
  QuranCrossSurahRange? _configuredRange;
  QuranCrossSurahRange? _activeRange;

  // New Grading State Fields
  bool _isRevision = false;
  String _selectedGrade = 'good';
  int _mistakesCount = 0;
  final TextEditingController _remarkController = TextEditingController();

  // Recitation Stopwatch variables
  Duration _recitationDuration = Duration.zero;
  Timer? _timer;
  bool _isTimerRunning = false;
  DateTime _recordDate = BackdatedEntryPolicy.dateOnly(DateTime.now());

  Surah? get _selectedSurah => _selectedSurahId != null 
      ? _quran.getSurah(_selectedSurahId!) 
      : null;

  bool get _ascendingSurahs => widget.student.memorizationDirection != 'desc';

  @override
  void initState() {
    super.initState();
    _ownsRecitationFlow = RecitationFlowCoordinator.acquire(
      widget.student.id,
      this,
    );
    if (!_ownsRecitationFlow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'توجد شاشة حفظ أخرى مفتوحة لهذا الطالب. أغلقها أولًا ثم أعد المحاولة.',
            ),
          ),
        );
        Navigator.maybePop(context);
      });
      return;
    }
    _loadInitialStartingPoint();
  }

  Future<void> _loadInitialStartingPoint() async {
    await _quran.initialize();
    final startPoint = await _getNextMemorizationStartingPoint(widget.student);
    if (!mounted || startPoint == null) return;
    final surahId = startPoint['surahId']!;
    final fromAyah = startPoint['fromAyah']!;
    final suggested = _buildPlanRange(surahId, fromAyah);
    setState(() {
      _selectedSurahId = surahId;
      _fromAyah = fromAyah;
      _toAyah = suggested?.segments.first.toAyah ?? startPoint['toAyah']!;
      _suggestedPlanRange = suggested;
      _configuredRange = null;
    });
  }

  QuranCrossSurahRange? _buildPlanRange(int surahId, int fromAyah) {
    return QuranCrossSurahRangeService.toAmount(
      surahs: _quran.surahs,
      startSurahId: surahId,
      startAyah: fromAyah,
      unit: QuranCrossSurahRangeService.unitFromPlanType(
        widget.student.planType,
      ),
      amount: widget.student.planAmount,
      ascendingSurahs: _ascendingSurahs,
    );
  }

  QuranCrossSurahRange? _singleSurahConfiguredRange() {
    if (_selectedSurahId == null) return null;
    return QuranCrossSurahRangeService.fromAyahs(
      _quran.getAyahRange(_selectedSurahId!, _fromAyah, _toAyah),
    );
  }

  String _rangeLabel(QuranCrossSurahRange? range) {
    if (range == null || range.ayahs.isEmpty) return 'نطاق غير محدد';
    final first = range.ayahs.first;
    final last = range.ayahs.last;
    final firstName = _quran.getSurahName(first.surahNumber);
    final lastName = _quran.getSurahName(last.surahNumber);
    if (first.surahNumber == last.surahNumber) {
      return 'سورة $firstName من آية ${first.number} إلى آية ${last.number}';
    }
    return 'من سورة $firstName آية ${first.number} إلى سورة $lastName آية ${last.number}';
  }

  String _surahRangeLabel(QuranCrossSurahRange range) {
    final firstName = _quran.getSurahName(range.fromSurahId);
    final lastName = _quran.getSurahName(range.toSurahId);
    return range.fromSurahId == range.toSurahId
        ? firstName
        : '$firstName إلى $lastName';
  }

  Future<Map<String, int>?> _getNextMemorizationStartingPoint(Student student) async {
    final allProgress = await _db.getStudentMemorization(student.id);
    return MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: allProgress,
      getSurah: _quran.getSurah,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _remarkController.dispose();
    if (_ownsRecitationFlow) {
      RecitationFlowCoordinator.release(widget.student.id, this);
    }
    super.dispose();
  }

  void _toggleTimer() {
    if (_isTimerRunning) {
      _timer?.cancel();
      setState(() => _isTimerRunning = false);
    } else {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _recitationDuration += const Duration(seconds: 1);
        });
      });
      setState(() => _isTimerRunning = true);
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  void _loadAyahs() {
    if (_selectedSurahId == null) return;
    final range = _openEnded
        ? QuranCrossSurahRangeService.toEnd(
            surahs: _quran.surahs,
            startSurahId: _selectedSurahId!,
            startAyah: _fromAyah,
            ascendingSurahs: _ascendingSurahs,
          )
        : (_configuredRange ?? _singleSurahConfiguredRange());
    if (range == null || range.ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر بدء التسميع من النطاق المحدد')),
      );
      return;
    }
    setState(() {
      _toAyah = range.toAyah;
      _activeRange = range;
      _ayahs = range.ayahs;
      _currentAyahIndex = 0;
      _ayahRatings = {};
      _mistakesCount = 0;
      _selectedGrade = 'good';
      _remarkController.clear();
      _recitationDuration = Duration.zero;
      _isTimerRunning = true;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recitationDuration += const Duration(seconds: 1);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تسميع ${widget.student.name}'),
        actions: [
          IconButton(
            onPressed: _pickRecordDate,
            tooltip: 'تاريخ التسجيل: ${Helpers.formatPlanDate(_recordDate)}',
            icon: Badge(
              isLabelVisible: BackdatedEntryPolicy.daysAgo(_recordDate) > 0,
              label: Text('${BackdatedEntryPolicy.daysAgo(_recordDate)}'),
              child: const Icon(Icons.calendar_month_outlined),
            ),
          ),
          if (_ayahs.isNotEmpty)
            IconButton(
              icon: Icon(_showFullText ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showFullText = !_showFullText),
              tooltip: _showFullText ? 'إخفاء النص' : 'عرض النص',
            ),
        ],
      ),
      body: SafeArea(
        child: _ayahs.isEmpty ? _buildSetupView() : _buildRecitationView(),
      ),
      bottomNavigationBar: _ayahs.isNotEmpty ? _buildBottomBar() : null,
    );
  }


  Future<void> _pickRecordDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: BackdatedEntryPolicy.earliestAllowed(now),
      lastDate: BackdatedEntryPolicy.dateOnly(now),
      helpText: 'تاريخ التسميع (حتى 3 أيام سابقة)',
      confirmText: 'اعتماد',
    );
    if (picked == null || !mounted) return;
    setState(() => _recordDate = BackdatedEntryPolicy.dateOnly(picked));
  }

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStudentCard(),
          const SizedBox(height: 16),
          _buildSurahSelector(),
          if (_selectedSurahId != null) ...[
            const SizedBox(height: 16),
            _buildAyahRangeSelector(),
            const SizedBox(height: 16),
            _buildSummaryCard(),
            const SizedBox(height: 24),
            _buildStartButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildStudentCard() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            widget.student.name[0],
            style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
        title: Text(widget.student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('الحفظ الكلي: ${widget.student.totalMemorized} آية'),
      ),
    );
  }

  Widget _buildSurahSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اختر السورة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final surahId = await showSurahPicker(
                  context,
                  selectedSurahId: _selectedSurahId,
                  title: 'اختر سورة للتسميع',
                );
                if (surahId != null) {
                  final surah = _quran.getSurah(surahId);
                  final suggested = _buildPlanRange(surahId, 1);
                  setState(() {
                    _selectedSurahId = surahId;
                    _fromAyah = 1;
                    _toAyah = suggested?.segments.first.toAyah ??
                        surah?.totalAyahs ??
                        1;
                    _suggestedPlanRange = suggested;
                    _configuredRange = null;
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.menu_book, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedSurah != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'سورة ${_selectedSurah!.name}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_selectedSurah!.totalAyahs} آية',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            )
                          : Text('اضغط لاختيار السورة', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahRangeSelector() {
    final maxAyahs = _selectedSurah?.totalAyahs ?? 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'تسميع مفتوح',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'ابدأ من آية محددة، ثم اضغط «التوقف هنا» عند انتهاء الطالب.',
              ),
              value: _openEnded,
              onChanged: (value) {
                setState(() {
                  _openEnded = value;
                  if (value) {
                    _toAyah = _fromAyah;
                    _configuredRange = null;
                  } else if (_suggestedPlanRange != null) {
                    _configuredRange = _suggestedPlanRange;
                    _toAyah = _suggestedPlanRange!.segments.first.toAyah;
                  }
                });
              },
            ),
            if (_suggestedPlanRange != null) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مقرر الطالب: ${widget.student.planAmount} ${_planUnitLabel(widget.student.planType)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _rangeLabel(_suggestedPlanRange),
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: TextButton.icon(
                        onPressed: _applySuggestedPlan,
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: const Text('تحديد الجلسة بالمقرر'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Divider(),
            AyahRangePicker(
              key: ValueKey(
                '${_selectedSurahId}_$_openEnded',
              ),
              maxAyahs: maxAyahs,
              initialFrom: _fromAyah,
              initialTo: _openEnded ? _fromAyah : _toAyah,
              singleValue: _openEnded,
              onRangeChanged: (from, to) {
                final suggested = _buildPlanRange(_selectedSurahId!, from);
                setState(() {
                  _fromAyah = from;
                  _toAyah = _openEnded ? from : to;
                  _suggestedPlanRange = suggested;
                  _configuredRange = null;
                });
              },
            ),
            const SizedBox(height: 12),
            if (!_openEnded) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _selectExplicitEnd,
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('تحديد «إلى» في سورة أخرى'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _setEndOfCurrentPage,
                    icon: const Icon(Icons.menu_book_outlined),
                    label: const Text('نهاية الصفحة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _setEndOfCurrentHizb,
                    icon: const Icon(Icons.bookmark_outline),
                    label: const Text('نهاية الحزب'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applySuggestedPlan() {
    final range = _suggestedPlanRange;
    if (range == null) return;
    setState(() {
      _openEnded = false;
      _configuredRange = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  Future<void> _selectExplicitEnd() async {
    final startSurahId = _selectedSurahId;
    if (startSurahId == null) return;
    final endpoint = await showQuranEndpointPicker(
      context,
      initialSurahId: startSurahId,
      initialAyah: _toAyah,
      title: 'نهاية التسميع',
    );
    if (endpoint == null || !mounted) return;
    final range = QuranCrossSurahRangeService.between(
      surahs: _quran.surahs,
      startSurahId: startSurahId,
      startAyah: _fromAyah,
      endSurahId: endpoint.surahId,
      endAyah: endpoint.ayah,
      ascendingSurahs: widget.student.memorizationDirection != 'desc',
    );
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('نهاية التسميع لا تقع بعد نقطة البداية')),
      );
      return;
    }
    setState(() {
      _openEnded = false;
      _configuredRange = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  void _setEndOfCurrentPage() {
    if (_selectedSurahId == null) return;
    final range = QuranCrossSurahRangeService.toBoundary(
      surahs: _quran.surahs,
      startSurahId: _selectedSurahId!,
      startAyah: _fromAyah,
      boundary: QuranRangeBoundary.page,
      ascendingSurahs: _ascendingSurahs,
    );
    if (range == null) return;
    setState(() {
      _openEnded = false;
      _configuredRange = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  void _setEndOfCurrentHizb() {
    if (_selectedSurahId == null) return;
    final range = QuranCrossSurahRangeService.toBoundary(
      surahs: _quran.surahs,
      startSurahId: _selectedSurahId!,
      startAyah: _fromAyah,
      boundary: QuranRangeBoundary.hizb,
      ascendingSurahs: _ascendingSurahs,
    );
    if (range == null) return;
    setState(() {
      _openEnded = false;
      _configuredRange = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  Widget _buildSummaryCard() {
    if (_openEnded) {
      return Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: ListTile(
          leading: Icon(Icons.play_circle_outline, color: Theme.of(context).colorScheme.onPrimaryContainer),
          title: Text('يبدأ التسميع من الآية $_fromAyah'),
          subtitle: Text(
            'يستمر عبر السور باتجاه خطة الطالب، ويعتمد المعلم آخر آية عند التوقف.'
            '${_suggestedPlanRange == null ? '' : '\nنهاية المقرر المقترحة: ${_rangeLabel(_suggestedPlanRange)}'}',
          ),
        ),
      );
    }
    final range = _configuredRange ?? _singleSurahConfiguredRange();
    final ayahs = range?.ayahs ?? const <Ayah>[];
    final lines = ayahs.fold<double>(0, (sum, ayah) => sum + ayah.lines);
    final pages = ayahs.map((ayah) => ayah.page).toSet().length;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          alignment: WrapAlignment.spaceAround,
          spacing: 16,
          runSpacing: 12,
          children: [
            _buildSummaryItem('الآيات', '${ayahs.length}'),
            _buildSummaryItem('الأسطر', lines.toStringAsFixed(1)),
            _buildSummaryItem('الصفحات', '$pages'),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  String _planUnitLabel(String planType) {
    switch (planType) {
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      case 'hizbs':
        return 'حزب';
      default:
        return 'آية';
    }
  }

  Widget _buildStartButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _loadAyahs,
        icon: const Icon(Icons.play_arrow),
        label: Text(_openEnded ? 'بدء التسميع المفتوح' : 'بدء التسميع'),
      ),
    );
  }

  Widget _buildRecitationView() {
    final currentAyah = _ayahs[_currentAyahIndex];
    return Column(
      children: [
        _buildProgressBar(),
        _buildTimerRow(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildAyahCard(currentAyah),
                const SizedBox(height: 16),
                _buildAyahRating(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimerRow() {
    final measuredAyahs = _ayahs.take(_currentAyahIndex + 1);
    final lines = measuredAyahs.fold<double>(
      0,
      (sum, ayah) => sum + ayah.lines,
    );
    final pages = lines / 15.0;
    final min = (pages * 1.5).round().clamp(1, 999);
    final max = (pages * 2.0).round().clamp(min + 1, 999);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppSemanticColors.of(context).info.withValues(alpha: 0.45)),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        runSpacing: 10,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: AppSemanticColors.of(context).info,
                  size: 36,
                ),
                onPressed: _toggleTimer,
              ),
              const SizedBox(width: 12),
              Text(
                _formatDuration(_recitationDuration),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [ui.FontFeature.tabularFigures()],
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الوقت المقترح للتسميع',
                style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                '$min - $max دقائق (${pages.toStringAsFixed(1)} صفحة)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    final currentAyah = _ayahs[_currentAyahIndex];
    final currentSurahName = _quran.getSurahName(currentAyah.surahNumber);
    final label = Text(
      _openEnded
          ? 'سورة $currentSurahName · آية ${currentAyah.number}'
          : 'الآية ${_currentAyahIndex + 1} من ${_ayahs.length}',
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
    final progress = LinearProgressIndicator(
      value: _openEnded ? null : (_currentAyahIndex + 1) / _ayahs.length,
      backgroundColor: Theme.of(context).colorScheme.outlineVariant,
    );
    final percentage = !_openEnded
        ? Text(
            '${((_currentAyahIndex + 1) / _ayahs.length * 100).round()}%',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          )
        : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          if (constraints.maxWidth < 360 || textScale > 1.2) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  children: [label, if (percentage != null) percentage],
                ),
                const SizedBox(height: 8),
                progress,
              ],
            );
          }
          return Row(
            children: [
              label,
              const SizedBox(width: 12),
              Expanded(child: progress),
              if (percentage != null) ...[
                const SizedBox(width: 12),
                percentage,
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildAyahCard(Ayah ayah) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'سورة ${_quran.getSurahName(ayah.surahNumber)} · آية ${ayah.number}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'صفحة ${ayah.page}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_showFullText)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppSemanticColors.of(context).warningContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppSemanticColors.of(context).warning.withValues(alpha: 0.55),
                  ),
                ),
                child: Text(
                  ayah.text,
                  style: TextStyle(
                    fontSize: 24,
                    fontFamily: 'Tajawal',
                    height: 2,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.visibility_off,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'النص مخفي',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط على أيقونة العين لعرضه',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildInfoChip('الجزء ${ayah.juz}', Icons.book),
                _buildInfoChip('الحزب ${ayah.hizb}', Icons.bookmark_outline),
                _buildInfoChip('${ayah.lines.toStringAsFixed(1)} سطر', Icons.straighten),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildAyahRating() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('تقييم هذه الآية', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildRatingButton(5, 'ممتاز', Colors.green),
                _buildRatingButton(4, 'جيد جداً', Colors.lightGreen),
                _buildRatingButton(3, 'جيد', Colors.orange),
                _buildRatingButton(2, 'مقبول', Colors.deepOrange),
                _buildRatingButton(1, 'ضعيف', Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton(int rating, String label, Color color) {
    final isSelected = _ayahRatings[_currentAyahIndex] == rating;
    return InkWell(
      onTap: () {
        setState(() {
          _ayahRatings[_currentAyahIndex] = rating;
        });
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? color
                  : Theme.of(context).colorScheme.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rating',
                style: TextStyle(
                  color: isSelected ? ColorContrast.on(color) : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? color : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isFirst = _currentAyahIndex == 0;
    final isLast = _currentAyahIndex == _ayahs.length - 1;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        child: AppResponsiveButtonRow(
          children: [
            OutlinedButton(
              onPressed:
                  isFirst ? null : () => setState(() => _currentAyahIndex--),
              child: const Text('السابق'),
            ),
            if (_openEnded)
              OutlinedButton(
                onPressed: _isSaving || isLast ? null : _goToNext,
                child: const Text('التالي'),
              ),
            ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : _openEnded
                      ? _stopHere
                      : isLast
                          ? _showGradingSheet
                          : _goToNext,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _openEnded
                          ? 'التوقف هنا'
                          : isLast
                              ? 'إنهاء التسميع'
                              : 'التالي',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToNext() {
    if (_ayahRatings[_currentAyahIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تقييم الآية قبل الانتقال')),
      );
      return;
    }
    setState(() => _currentAyahIndex++);
  }

  void _stopHere() {
    if (_ayahRatings[_currentAyahIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('قيّم آية التوقف أولًا ثم اعتمد النهاية')),
      );
      return;
    }
    final stoppedRange = QuranCrossSurahRangeService.fromAyahs(
      _ayahs.take(_currentAyahIndex + 1),
    );
    if (stoppedRange == null) return;
    setState(() {
      _toAyah = stoppedRange.toAyah;
      _activeRange = stoppedRange;
      _ayahs = stoppedRange.ayahs;
      _ayahRatings.removeWhere((index, _) => index > _currentAyahIndex);
      _currentAyahIndex = _ayahs.length - 1;
    });
    _showGradingSheet();
  }

  void _showGradingSheet() {
    if (_ayahRatings[_currentAyahIndex] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تقييم الآية الأخيرة أولاً')),
      );
      return;
    }

    // Pre-calculate grade based on average rating
    if (_ayahRatings.isNotEmpty) {
      final avg = _ayahRatings.values.reduce((a, b) => a + b) / _ayahRatings.length;
      if (avg >= 4.5) {
        _selectedGrade = 'excellent';
      } else if (avg >= 3.5) {
        _selectedGrade = 'very_good';
      } else if (avg >= 2.5) {
        _selectedGrade = 'good';
      } else {
        _selectedGrade = 'needs_work';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Color getGradeColor(String grade) {
            switch (grade) {
              case 'excellent': return Colors.green;
              case 'very_good': return Colors.lightGreen;
              case 'good': return Colors.orange;
              case 'needs_work': return Colors.deepOrange;
              case 'absent': return Colors.red;
              default: return Colors.blue;
            }
          }

          String getGradeArabic(String grade) {
            switch (grade) {
              case 'excellent': return 'ممتاز';
              case 'very_good': return 'جيد جداً';
              case 'good': return 'جيد';
              case 'needs_work': return 'يحتاج تركيز';
              case 'absent': return 'غائب';
              default: return '';
            }
          }

          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.only(
              top: 20,
              left: 20,
              right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'تسجيل تقييم التسميع',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'الطالب: ${widget.student.name} | ${_rangeLabel(_activeRange)}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const Divider(height: 24),
                  
                  // Revision vs Memorization toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('نوع التسميع:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          ChoiceChip(
                            label: Text(
                              'حفظ جديد',
                              style: TextStyle(
                                color: !_isRevision
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: !_isRevision,
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                            onSelected: (val) {
                              setModalState(() => _isRevision = !val);
                              setState(() => _isRevision = !val);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'مراجعة',
                              style: TextStyle(
                                color: _isRevision
                                    ? Theme.of(context).colorScheme.onPrimaryContainer
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            selected: _isRevision,
                            selectedColor: Theme.of(context).colorScheme.primaryContainer,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                            onSelected: (val) {
                              setModalState(() => _isRevision = val);
                              setState(() => _isRevision = val);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Grade Selection
                  const Text('التقييم العام:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.spaceEvenly,
                    spacing: 4,
                    runSpacing: 8,
                    children: ['excellent', 'very_good', 'good', 'needs_work', 'absent'].map((grade) {
                      final isSelected = _selectedGrade == grade;
                      final color = getGradeColor(grade);
                      return ChoiceChip(
                        label: Text(
                          getGradeArabic(grade),
                          style: TextStyle(
                            color: isSelected ? ColorContrast.on(color) : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: color),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() => _selectedGrade = grade);
                            setState(() => _selectedGrade = grade);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Mistakes Counter
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('عدد الأخطاء:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _mistakesCount > 0
                                ? () {
                                    setModalState(() => _mistakesCount--);
                                    setState(() => _mistakesCount--);
                                  }
                                : null,
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$_mistakesCount',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setModalState(() => _mistakesCount++);
                              setState(() => _mistakesCount++);
                            },
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Remarks
                  const Text('ملاحظات إضافية:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _remarkController,
                    decoration: InputDecoration(
                      hintText: 'اكتب أي ملاحظات هنا...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),

                  // Save Buttons
                  AppResponsiveButtonRow(
                    children: [
                      OutlinedButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                Navigator.pop(context);
                                await _saveRecitation(sendToParent: false);
                              },
                        icon: const Icon(Icons.save),
                        label: const Text('حفظ التقييم'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppSemanticColors.of(context).success,
                      foregroundColor: AppSemanticColors.of(context).onSuccess,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            Navigator.pop(context); // Close sheet
                            await _saveRecitation(sendToParent: true);
                          },
                    icon: const Icon(Icons.share),
                    label: const Text('حفظ وإرسال لولي الأمر (نص)'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppSemanticColors.of(context).warning,
                      foregroundColor: AppSemanticColors.of(context).onWarning,
                    ),
                    onPressed: _isSaving
                        ? null
                        : () async {
                            Navigator.pop(context); // Close sheet
                            await _saveRecitation(sendToParent: true, sendAsImage: true);
                          },
                    icon: const Icon(Icons.image),
                    label: const Text('حفظ وإرسال كصورة'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveRecitation({bool sendToParent = false, bool sendAsImage = false}) async {
    if (!_isRevision &&
        StudentLearningPolicy.hasCompletedQuran(widget.student)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الطالب أتم حفظ القرآن؛ اختر المراجعة بدل الحفظ الجديد'),
        ),
      );
      return;
    }
    if (_selectedGrade != 'absent') {
      final canRecord = await RecitationAttendanceGuard.confirmPresentIfAbsent(
        context,
        database: _db,
        student: widget.student,
        date: _recordDate,
      );
      if (!canRecord || !mounted) return;
    }
    _timer?.cancel();
    setState(() => _isSaving = true);

    try {
      final sessionRange = _activeRange ??
          QuranCrossSurahRangeService.fromAyahs(_ayahs);
      if (sessionRange == null) {
        throw StateError('لا يوجد نطاق تسميع صالح للحفظ');
      }
      // Some valid flows (most notably recording an absence, or legacy
      // sessions without per-ayah ratings) reach save with an empty rating
      // map. `reduce()` on an empty iterable was one source of the generic
      // ErrorWidget seen by teachers. Fall back to the selected grade instead.
      const gradeRating = <String, int>{
        'excellent': 5,
        'very_good': 4,
        'good': 3,
        'needs_work': 2,
        'absent': 1,
      };
      final avgRating = _ayahRatings.isEmpty
          ? (gradeRating[_selectedGrade] ?? 3)
          : (_ayahRatings.values.fold<int>(0, (sum, value) => sum + value) /
                  _ayahRatings.length)
              .round()
              .clamp(1, 5)
              .toInt();
      final currentStudent =
          await _db.getStudent(widget.student.id) ?? widget.student;
      final sessionCompleted = _selectedGrade != 'absent';
      var newlyMemorizedAyahs = 0;
      if (!_isRevision && sessionCompleted) {
        for (final segment in sessionRange.segments) {
          newlyMemorizedAyahs += await _db.countNewMemorizedAyahs(
            student: currentStudent,
            surahId: segment.surahId,
            fromAyah: segment.fromAyah,
            toAyah: segment.toAyah,
          );
        }
      }

      final actualNow = DateTime.now();
      final recordDate = _recordDate;
      final remark = _remarkController.text.trim();
      final progressRows = <MemorizationProgress>[];
      final grades = <HomeworkGrade>[];
      for (var index = 0; index < sessionRange.segments.length; index++) {
        final segment = sessionRange.segments[index];
        if (sessionCompleted) {
          progressRows.add(
            MemorizationProgress(
              studentId: widget.student.id,
              surahId: segment.surahId,
              fromAyah: segment.fromAyah,
              toAyah: segment.toAyah,
              date: recordDate,
              qualityRating: avgRating,
              isRevision: _isRevision,
              notes: index == 0 && remark.isNotEmpty ? remark : null,
              createdAt: actualNow,
            ),
          );
        }
        grades.add(
          HomeworkGrade(
            studentId: widget.student.id,
            surahId: segment.surahId,
            fromAyah: segment.fromAyah,
            toAyah: segment.toAyah,
            date: recordDate,
            gradeMark: _selectedGrade,
            // The teacher enters one total for the connected session. Keeping
            // it on the first segment prevents reports from multiplying it.
            mistakesCount: index == 0 ? _mistakesCount : 0,
            isRevision: _isRevision,
            remark: index == 0 && remark.isNotEmpty ? remark : null,
            createdAt: actualNow,
          ),
        );
      }

      final existingRecord = await _db.getDailyRecord(widget.student.id, recordDate);
      final record = (existingRecord ?? DailyRecord(
        studentId: widget.student.id,
        date: recordDate,
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ??
            (BackdatedEntryPolicy.daysAgo(recordDate) == 0 ? actualNow : null),
        memorizationDone: !_isRevision && sessionCompleted
            ? true
            : (existingRecord?.memorizationDone ?? false),
        revisionDone: _isRevision && sessionCompleted
            ? true
            : (existingRecord?.revisionDone ?? false),
        memorizationAmount: !_isRevision && sessionCompleted
            ? (existingRecord?.memorizationAmount ?? 0) + newlyMemorizedAyahs
            : (existingRecord?.memorizationAmount ?? 0),
        revisionAmount: _isRevision && sessionCompleted
            ? (existingRecord?.revisionAmount ?? 0) + sessionRange.ayahs.length
            : (existingRecord?.revisionAmount ?? 0),
        memorizationNote: !_isRevision && remark.isNotEmpty
            ? remark
            : existingRecord?.memorizationNote,
        revisionNote: _isRevision && remark.isNotEmpty
            ? remark
            : existingRecord?.revisionNote,
      );

      final updatedTotalMemorized = !_isRevision && sessionCompleted
          ? (currentStudent.totalMemorized + newlyMemorizedAyahs)
              .clamp(0, 6236)
              .toInt()
          : null;
      await _db.saveRecitationSession(
        progress: progressRows,
        grades: grades,
        dailyRecord: record,
        updatedTotalMemorized: updatedTotalMemorized,
      );

      if (sessionCompleted) {
        for (final grade in grades) {
          try {
            await MushafService().updateProgressAfterGrading(grade);
          } catch (mushafError) {
            debugPrint('Error updating mushaf progress: $mushafError');
          }
        }
      }

      var shareFailed = false;
      if (sendToParent) {
        try {
          if (sendAsImage) {
            final bytes = await _drawReportCardImage(
              studentName: widget.student.name,
              surahName: _surahRangeLabel(sessionRange),
              fromAyah: sessionRange.fromAyah,
              toAyah: sessionRange.toAyah,
              grade: _selectedGrade,
              mistakes: _mistakesCount,
              isRevision: _isRevision,
              remark: _remarkController.text,
            );

            final tempDir = await getTemporaryDirectory();
            final file = await File(
              '${tempDir.path}/${ShareFileNameService.dated(label: 'تقرير_تسميع_${widget.student.name}', extension: 'png', date: recordDate)}',
            ).create();
            await file.writeAsBytes(bytes);

            await Share.shareXFiles(
              [XFile(file.path)],
              text: '${ShareFileNameService.appName} — تقرير تسميع الطالب ${widget.student.name}',
            );
          } else {
            final template = await _db.getMessageTemplate('grading');
            String templateText = template?.content ??
                'السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}';

            String message = templateText
                .replaceAll('{اسم_الطالب}', widget.student.name)
                .replaceAll('{السورة}', _surahRangeLabel(sessionRange))
                .replaceAll('{من}', '${sessionRange.fromAyah}')
                .replaceAll('{إلى}', '${sessionRange.toAyah}')
                .replaceAll('{التقييم}', grades.first.gradeMarkArabic)
                .replaceAll('{الأخطاء}', '$_mistakesCount')
                .replaceAll(
                  '{الملاحظة}',
                  remark.isNotEmpty ? remark : 'لا يوجد',
                );

            await Share.share(message);
          }
        } catch (shareError) {
          shareFailed = true;
          debugPrint('Recitation saved but sharing failed: $shareError');
        }
      }

      final pointsResult = _isRevision
          ? null
          : await _db.recalculateDailyRecitationPoints(
              studentId: widget.student.id,
              date: recordDate,
            );

      final completedSurahNames = <String>[];
      if (!_isRevision && newlyMemorizedAyahs > 0) {
        for (final segment in sessionRange.segments) {
          final surah = _quran.getSurah(segment.surahId);
          if (surah == null || segment.toAyah != surah.totalAyahs) continue;
          final completed = await _db.isSurahFullyMemorized(
            student: currentStudent,
            surahId: segment.surahId,
            totalAyahs: surah.totalAyahs,
          );
          if (completed) {
            completedSurahNames.add(surah.name);
            await _db.ensureSurahCompletionNotification(
              student: currentStudent,
              surahName: surah.name,
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${completedSurahNames.isNotEmpty
                  ? 'تم إتمام ${completedSurahNames.map((name) => 'سورة $name').join('، ')}، وأضيفت للمراجعة الإلزامية'
                  : pointsResult != null && pointsResult.totalPoints > 0
                      ? 'تم حفظ التقييم، ورصيد إنجاز اليوم ${pointsResult.totalPoints} نقاط 🎉'
                      : 'تم حفظ التقييم بنجاح'}'
              '${shareFailed ? '، لكن تعذرت المشاركة؛ يمكنك مشاركته من السجل لاحقًا' : ''}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء حفظ التقييم: $e')),
        );
      }
    }
  }

  Future<Uint8List> _drawReportCardImage({
    required String studentName,
    required String surahName,
    required int fromAyah,
    required int toAyah,
    required String grade,
    required int mistakes,
    required bool isRevision,
    required String remark,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 800, 500));

    // Paint background gradient
    final paintBg = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(800, 500),
        [
          const Color(0xFF0F766E),
          const Color(0xFF115E59),
        ],
      );
    canvas.drawRect(const Rect.fromLTWH(0, 0, 800, 500), paintBg);

    final paintCircle = Paint()..color = Colors.white.withValues(alpha: 0.03);
    canvas.drawCircle(const Offset(80, 80), 150, paintCircle);
    canvas.drawCircle(const Offset(720, 420), 200, paintCircle);

    final paintCard = Paint()..color = Colors.white;
    final rrectCard = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 40, 720, 420),
      const Radius.circular(30),
    );
    canvas.drawRRect(rrectCard, paintCard);

    final paintBorder = Paint()
      ..color = const Color(0xFF14B8A6).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawRRect(rrectCard, paintBorder);

    final paintBanner = Paint()..color = const Color(0xFF14B8A6);
    final rrectBanner = RRect.fromRectAndRadius(
      const Rect.fromLTWH(250, 20, 300, 50),
      const Radius.circular(15),
    );
    canvas.drawRRect(rrectBanner, paintBanner);

    _drawText(
      canvas: canvas,
      text: 'بطاقة تقييم التسميع اليومي 📖',
      offset: const Offset(400, 45),
      fontSize: 20,
      color: Colors.white,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );

    const rightAlignX = 700.0;
    
    _drawText(
      canvas: canvas,
      text: 'اسم الطالب: $studentName',
      offset: const Offset(rightAlignX, 110),
      fontSize: 26,
      color: const Color(0xFF0F172A),
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.right,
    );

    _drawText(
      canvas: canvas,
      text: 'الواجب المنجز: سورة $surahName (الآيات $fromAyah إلى $toAyah)',
      offset: const Offset(rightAlignX, 175),
      fontSize: 21,
      color: const Color(0xFF334155),
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.right,
    );

    final typeText = isRevision ? 'مراجعة' : 'حفظ جديد';
    _drawText(
      canvas: canvas,
      text: 'نوع التسميع: $typeText',
      offset: const Offset(rightAlignX, 225),
      fontSize: 21,
      color: const Color(0xFF334155),
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.right,
    );

    if (grade != 'absent') {
      _drawText(
        canvas: canvas,
        text: 'عدد الأخطاء: $mistakes',
        offset: const Offset(rightAlignX, 275),
        fontSize: 21,
        color: mistakes > 0 ? Colors.red : const Color(0xFF0F766E),
        fontWeight: FontWeight.bold,
        textAlign: TextAlign.right,
      );
    }

    if (remark.isNotEmpty) {
      _drawText(
        canvas: canvas,
        text: 'ملاحظات المعلم: $remark',
        offset: const Offset(rightAlignX, 325),
        fontSize: 18,
        color: const Color(0xFF475569),
        fontWeight: FontWeight.w500,
        textAlign: TextAlign.right,
      );
    }

    final dateText = Helpers.formatPlanDate(_recordDate);
    _drawText(
      canvas: canvas,
      text: 'التاريخ: $dateText',
      offset: const Offset(rightAlignX, 375),
      fontSize: 16,
      color: const Color(0xFF94A3B8),
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.right,
    );

    Color badgeBg;
    Color badgeText;
    String badgeLabel;

    switch (grade) {
      case 'excellent':
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        badgeLabel = 'ممتاز';
        break;
      case 'very_good':
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF166534);
        badgeLabel = 'جيد جداً';
        break;
      case 'good':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFB45309);
        badgeLabel = 'جيد';
        break;
      case 'needs_work':
        badgeBg = const Color(0xFFFFEDD5);
        badgeText = const Color(0xFFC2410C);
        badgeLabel = 'مقبول';
        break;
      case 'absent':
      default:
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFFB91C1C);
        badgeLabel = 'غائب';
        break;
    }

    final paintBadge = Paint()..color = badgeBg;
    final rrectBadge = RRect.fromRectAndRadius(
      const Rect.fromLTWH(80, 160, 200, 160),
      const Radius.circular(20),
    );
    canvas.drawRRect(rrectBadge, paintBadge);

    _drawText(
      canvas: canvas,
      text: badgeLabel,
      offset: const Offset(180, 225),
      fontSize: 34,
      color: badgeText,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );

    _drawText(
      canvas: canvas,
      text: 'التقييم العام',
      offset: const Offset(180, 280),
      fontSize: 16,
      color: badgeText,
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );

    _drawText(
      canvas: canvas,
      text: 'مقرأة حلقة القرآن الكريم الإلكترونية',
      offset: const Offset(400, 435),
      fontSize: 18,
      color: const Color(0xFF0F766E),
      fontWeight: FontWeight.bold,
      textAlign: TextAlign.center,
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(800, 500);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  void _drawText({
    required Canvas canvas,
    required String text,
    required Offset offset,
    required double fontSize,
    required Color color,
    required FontWeight fontWeight,
    required TextAlign textAlign,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: fontSize,
        color: color,
        fontWeight: fontWeight,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.rtl,
      textAlign: textAlign,
    );
    textPainter.layout(minWidth: 0, maxWidth: 650);

    double x = offset.dx;
    if (textAlign == TextAlign.right) {
      x = offset.dx - textPainter.width;
    } else if (textAlign == TextAlign.center) {
      x = offset.dx - (textPainter.width / 2);
    }
    final y = offset.dy - (textPainter.height / 2);
    textPainter.paint(canvas, Offset(x, y));
  }
}
