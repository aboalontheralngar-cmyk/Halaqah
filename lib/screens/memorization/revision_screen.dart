import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/quran_service.dart';
import '../../services/quran_cross_surah_range_service.dart';
import '../../services/revision_progression_service.dart';
import '../../services/revision_system_policy.dart';
import '../../services/recitation_attendance_guard.dart';
import '../../services/backdated_entry_policy.dart';
import '../../services/mandatory_revision_schedule_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/homework_grade.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/quality_rating.dart';
import '../../widgets/ayah_range_picker.dart';
import '../students/student_form_screen.dart';

class RevisionScreen extends StatefulWidget {
  final Student student;
  final String? reviewUnitOverride;
  final int? reviewAmountOverride;
  final String? courseTitle;

  const RevisionScreen({
    super.key,
    required this.student,
    this.reviewUnitOverride,
    this.reviewAmountOverride,
    this.courseTitle,
  });

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  List<MemorizedSurah> _memorizedSurahs = [];
  Set<int> _selectedSurahs = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _ascending = true;
  int _qualityRating = 3;
  String _reviewUnit = 'pages';
  int _reviewAmount = 1;
  String? _resumeText;
  int? _suggestedSurahId;
  int? _suggestedFromAyah;
  Student? _resolvedStudent;
  bool _hasUnmappedMemorizedTotal = false;
  String _surahQuery = '';
  String _revisionSystem = RevisionSystemPolicy.defaultSystem;
  DateTime _recordDate = BackdatedEntryPolicy.dateOnly(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadMemorizedSurahs();
  }

  Future<void> _loadMemorizedSurahs() async {
    setState(() => _isLoading = true);
    try {
      await _quran.initialize();
      final currentStudent =
          await _db.getStudent(widget.student.id) ?? widget.student;
      final revisionSystem = RevisionSystemPolicy.resolve(
        currentStudent.reviewSystem,
      );
      final memorizedRanges =
          await _db.getStudentMemorizedRanges(widget.student.id);
      final surahIds = memorizedRanges.keys.toList()..sort();
      final allProgress = await _db.getStudentMemorization(widget.student.id);
      final settings = await _db.getSettings();
      final activePlan = await _db.getActiveStudentPlan(widget.student.id);
      _ascending = settings.revisionOrder != 'descending';
      final configuredUnit = widget.reviewUnitOverride ??
          activePlan?.reviewUnit ??
          currentStudent.reviewPlanType;
      _reviewUnit = const <String>{'ayahs', 'lines', 'pages', 'hizbs'}
              .contains(configuredUnit)
          ? configuredUnit
          : 'pages';
      _reviewAmount = widget.reviewAmountOverride ??
          activePlan?.reviewAmount ??
          currentStudent.reviewPlanAmount;

      final surahs = <MemorizedSurah>[];
      final requiredSurahs = <int>{};
      for (final surahId in surahIds) {
        final memorizedRange = memorizedRanges[surahId];
        if (memorizedRange == null) continue;
        final surahData = QuranData.surahs.firstWhere(
          (s) => s['id'] == surahId,
          orElse: () => {},
        );
        if (surahData.isEmpty) continue;

        final revisions = allProgress
            .where((p) => p.surahId == surahId && p.isRevision)
            .toList();

        DateTime? lastRevision;
        if (revisions.isNotEmpty) {
          revisions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          lastRevision = revisions.first.date;
        }

        final completionDate = _getCompletionDate(
          surahId,
          surahData['ayahs'],
          allProgress,
          currentStudent,
        );
        final revisionDaysAfterCompletion = completionDate == null
            ? const <String>{}
            : revisions
                .where(
                  (revision) =>
                      revision.createdAt.isAfter(completionDate),
                )
                .map(
                  (revision) =>
                      '${revision.date.year}-'
                      '${revision.date.month.toString().padLeft(2, '0')}-'
                      '${revision.date.day.toString().padLeft(2, '0')}',
                )
                .toSet();
        MandatoryRevisionChunk? mandatoryChunk;
        if (completionDate != null &&
            revisionSystem.id == 'five_day_stabilization') {
          final quranSurah = _quran.getSurah(surahId);
          if (quranSurah != null) {
            mandatoryChunk = MandatoryRevisionScheduleService.chunkForDay(
              surah: quranSurah,
              fromAyah: memorizedRange.fromAyah,
              toAyah: memorizedRange.toAyah,
              completedDays: revisionDaysAfterCompletion.length,
            );
          }
        }
        final requiresCompletionRevision = completionDate != null &&
            (revisionSystem.id == 'five_day_stabilization'
                ? mandatoryChunk != null
                : revisionDaysAfterCompletion.isEmpty);
        if (requiresCompletionRevision) requiredSurahs.add(surahId);

        surahs.add(MemorizedSurah(
          id: surahId,
          name: surahData['name'],
          ayahs: surahData['ayahs'],
          juz: surahData['juz'],
          lastRevision: lastRevision,
          requiresCompletionRevision: requiresCompletionRevision,
          minMemorizedAyah: memorizedRange.fromAyah,
          maxMemorizedAyah: memorizedRange.toAyah,
          selectedFromAyah: mandatoryChunk?.fromAyah,
          selectedToAyah: mandatoryChunk?.toAyah,
          mandatoryDayNumber: mandatoryChunk?.dayNumber,
          mandatoryTotalDays: mandatoryChunk?.totalDays,
          mandatoryFromPage: mandatoryChunk?.fromPage,
          mandatoryToPage: mandatoryChunk?.toPage,
        ));
      }

      _revisionSystem = revisionSystem.id;
      _sortSurahs(surahs);

      String? resumeText;
      int? suggestedSurahId;
      int? suggestedFromAyah;
      if (requiredSurahs.isEmpty && surahs.isNotEmpty) {
        final next = RevisionProgressionService.nextStartingPoint(
          memorizedSurahIds: surahs.map((surah) => surah.id).toList(),
          progress: allProgress,
          ascending: _ascending,
          getSurah: _quran.getSurah,
          memorizedRanges: memorizedRanges,
          preserveInputOrder: revisionSystem.id == 'adaptive_spaced',
        );
        if (next != null) {
          final suggested = surahs.firstWhere(
            (surah) => surah.id == next['surahId'],
          );
          final connectedRange = _connectedRange(
            availableSurahs: surahs,
            startSurahId: suggested.id,
            startAyah: next['fromAyah']!,
            unit: _reviewUnit,
            amount: _reviewAmount,
          );
          _applyConnectedRange(
            range: connectedRange,
            availableSurahs: surahs,
            selectedSurahs: requiredSurahs,
          );
          final hasPreviousRevision =
              allProgress.any((progress) => progress.isRevision);
          resumeText = _connectedRangeLabel(
            connectedRange,
            availableSurahs: surahs,
            prefix: hasPreviousRevision
                ? 'استئناف المراجعة'
                : 'بداية دورة المراجعة',
          );
          suggestedSurahId = suggested.id;
          suggestedFromAyah = next['fromAyah'];
        }
      }

      if (!mounted) return;
      setState(() {
        _memorizedSurahs = surahs;
        _selectedSurahs = requiredSurahs;
        _resumeText = resumeText;
        _suggestedSurahId = suggestedSurahId;
        _suggestedFromAyah = suggestedFromAyah;
        _resolvedStudent = currentStudent;
        _hasUnmappedMemorizedTotal =
            memorizedRanges.isEmpty && currentStudent.totalMemorized > 0;
        _revisionSystem = revisionSystem.id;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  QuranCrossSurahRange? _connectedRange({
    required List<MemorizedSurah> availableSurahs,
    required int startSurahId,
    required int startAyah,
    required String unit,
    required int amount,
  }) {
    final start = availableSurahs.where((item) => item.id == startSurahId);
    if (start.isEmpty) return null;
    final startSurah = start.first;
    final safeStart = startAyah
        .clamp(startSurah.minMemorizedAyah, startSurah.maxMemorizedAyah)
        .toInt();
    final allowedRanges = <int, QuranRangeSegment>{
      for (final surah in availableSurahs)
        surah.id: QuranRangeSegment(
          surahId: surah.id,
          fromAyah: surah.minMemorizedAyah,
          toAyah: surah.maxMemorizedAyah,
        ),
    };
    return QuranCrossSurahRangeService.toAmount(
      surahs: _quran.surahs,
      startSurahId: startSurahId,
      startAyah: safeStart,
      unit: QuranCrossSurahRangeService.unitFromPlanType(unit),
      amount: amount,
      allowedRanges: allowedRanges,
      ascendingSurahs: _ascending,
    );
  }

  void _applyConnectedRange({
    required QuranCrossSurahRange? range,
    required List<MemorizedSurah> availableSurahs,
    required Set<int> selectedSurahs,
  }) {
    if (range == null) return;
    for (final segment in range.segments) {
      final matches = availableSurahs.where((item) => item.id == segment.surahId);
      if (matches.isEmpty) break;
      final surah = matches.first;
      if (!surah.requiresCompletionRevision) {
        surah.selectedFromAyah = segment.fromAyah;
        surah.selectedToAyah = segment.toAyah;
        surah.rangeVersion++;
      }
      selectedSurahs.add(surah.id);
    }
  }

  String _connectedRangeLabel(
    QuranCrossSurahRange? range, {
    required List<MemorizedSurah> availableSurahs,
    required String prefix,
  }) {
    if (range == null || range.segments.isEmpty) return prefix;
    String name(int id) {
      for (final item in availableSurahs) {
        if (item.id == id) return item.name;
      }
      return _quran.getSurahName(id);
    }
    final first = range.segments.first;
    final last = range.segments.last;
    if (first.surahId == last.surahId) {
      return '$prefix: ${name(first.surahId)} من ${first.fromAyah} إلى ${last.toAyah}';
    }
    return '$prefix: ${name(first.surahId)} ${first.fromAyah} — '
        '${name(last.surahId)} ${last.toAyah}';
  }

  void _sortSurahs(List<MemorizedSurah> surahs) {
    surahs.sort((a, b) {
      if (a.requiresCompletionRevision != b.requiresCompletionRevision) {
        return a.requiresCompletionRevision ? -1 : 1;
      }
      if (_revisionSystem == 'adaptive_spaced') {
        if (a.lastRevision == null && b.lastRevision != null) return -1;
        if (a.lastRevision != null && b.lastRevision == null) return 1;
        if (a.lastRevision != null && b.lastRevision != null) {
          final oldestFirst = a.lastRevision!.compareTo(b.lastRevision!);
          if (oldestFirst != 0) return oldestFirst;
        }
      }
      return _ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
    });
  }

  DateTime? _getCompletionDate(
    int surahId,
    int totalAyahs,
    List<MemorizationProgress> allProgress,
    Student student,
  ) {
    final memorized = <int>{};
    for (var ayah = 1; ayah <= totalAyahs; ayah++) {
      if (_isPreMemorizedAyah(student, surahId, ayah)) memorized.add(ayah);
    }
    if (memorized.length == totalAyahs) return null;

    final rows = allProgress
        .where((row) => !row.isRevision && row.surahId == surahId)
        .toList()
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : a.createdAt.compareTo(b.createdAt);
      });
    for (final row in rows) {
      for (var ayah = row.fromAyah; ayah <= row.toAyah; ayah++) {
        if (ayah >= 1 && ayah <= totalAyahs) memorized.add(ayah);
      }
      if (memorized.length == totalAyahs) return row.createdAt;
    }
    return null;
  }

  bool _isPreMemorizedAyah(Student student, int surahId, int ayah) {
    final startSurah = student.preMemorizedStartSurah;
    final endSurah = student.preMemorizedEndSurah;
    if (startSurah == null || endSurah == null) return false;
    final startAyah = student.preMemorizedStartAyah ?? 1;
    final endAyah = student.preMemorizedEndAyah ?? 1;
    if (startSurah == endSurah) {
      if (surahId != startSurah) return false;
      final first = startAyah < endAyah ? startAyah : endAyah;
      final last = startAyah > endAyah ? startAyah : endAyah;
      return ayah >= first && ayah <= last;
    }
    final firstSurah = startSurah < endSurah ? startSurah : endSurah;
    final lastSurah = startSurah > endSurah ? startSurah : endSurah;
    if (surahId < firstSurah || surahId > lastSurah) return false;
    if (surahId == startSurah) return ayah >= startAyah;
    if (surahId == endSurah) return ayah <= endAyah;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('مراجعة ${widget.student.name}'),
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
          IconButton(
            icon: Icon(_ascending ? Icons.arrow_downward : Icons.arrow_upward),
            onPressed: () {
              setState(() {
                _ascending = !_ascending;
                _sortSurahs(_memorizedSurahs);
              });
            },
            tooltip: _ascending ? 'ترتيب تنازلي' : 'ترتيب تصاعدي',
          ),
        ],
      ),
      bottomNavigationBar: !_isLoading &&
              _memorizedSurahs.isNotEmpty &&
              _selectedSurahs.isNotEmpty
          ? SafeArea(top: false, child: _buildBottomSheet())
          : null,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _memorizedSurahs.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildWorkspaceHeader(),
                      Expanded(child: _buildSurahList()),
                    ],
                  ),
      ),
    );
  }


  Future<void> _pickRecordDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: BackdatedEntryPolicy.earliestAllowed(now),
      lastDate: BackdatedEntryPolicy.dateOnly(now),
      helpText: 'تاريخ المراجعة (حتى 3 أيام سابقة)',
      confirmText: 'اعتماد',
    );
    if (picked == null || !mounted) return;
    setState(() => _recordDate = BackdatedEntryPolicy.dateOnly(picked));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book, size: 60, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              _hasUnmappedMemorizedTotal
                  ? 'يوجد إجمالي محفوظ دون نطاق سور وآيات'
                  : 'لا يوجد حفظ مسجل لهذا الطالب',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              _hasUnmappedMemorizedTotal
                  ? 'حدّث ملف الطالب وحدد بداية المحفوظ ونهايته مرة واحدة، ثم سيظهر كامل النطاق هنا وفي الاختبارات.'
                  : 'سجّل محفوظ الطالب في ملفه أو أضف تسميع حفظ جديدًا أولاً.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            if (_hasUnmappedMemorizedTotal && _resolvedStudent != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _repairStudentMemorizedRange,
                icon: const Icon(Icons.edit_note),
                label: const Text('تحديد نطاق المحفوظ الآن'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _repairStudentMemorizedRange() async {
    final student = _resolvedStudent;
    if (student == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => StudentFormScreen(student: student),
      ),
    );
    if (changed == true && mounted) await _loadMemorizedSurahs();
  }

  Widget _buildWorkspaceHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.menu_book_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'اختر السورة ونطاق الآيات',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${_selectedSurahs.length} محددة'),
                ),
                IconButton(
                  onPressed: _showConnectedRevisionRange,
                  tooltip: 'مراجعة متصلة من سورة إلى سورة',
                  icon: const Icon(Icons.route_outlined),
                ),
                IconButton(
                  onPressed: _showReviewSettings,
                  tooltip: 'إعداد مقدار المراجعة',
                  icon: const Icon(Icons.tune),
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _showRevisionSystemInfo,
              child: Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.repeat_on_outlined,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'النظام: ${RevisionSystemPolicy.resolve(_revisionSystem).title}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.info_outline, size: 18),
                  ],
                ),
              ),
            ),
            if (_resumeText != null) ...[
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _resumeText!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _surahQuery = value),
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'ابحث باسم السورة أو رقمها',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (_suggestedSurahId != null && _suggestedFromAyah != null) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.auto_fix_high_outlined, size: 18),
                    label: Text(
                      _suggestedSurahName == null
                          ? 'مقترح الخطة'
                          : 'مقترح: ${_suggestedSurahName!}',
                      overflow: TextOverflow.ellipsis,
                    ),
                    tooltip:
                        'تطبيق المقرر على موضع الاستئناف: $_reviewAmount ${_unitLabel(_reviewUnit)}'
                        '${widget.courseTitle == null ? '' : ' · دورة ${widget.courseTitle}'}',
                    onPressed: _reapplySuggestedRange,
                  ),
                ],
                if (_selectedSurahs.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: _clearOptionalSelection,
                    tooltip: 'إلغاء التحديد الاختياري',
                    icon: const Icon(Icons.deselect_outlined),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRevisionSystemInfo() {
    final system = RevisionSystemPolicy.resolve(_revisionSystem);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(system.title,
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(system.summary),
              const SizedBox(height: 8),
              Text(
                system.workflow,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _repairStudentMemorizedRange();
                  },
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('تغيير النظام من ملف الطالب'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _clearOptionalSelection() {
    // Build 78: حتى مقترحات التثبيت ليست إلزامية. يستطيع المعلم مسح
    // الاختيار كله ثم تسجيل ما سمعه الطالب فعلًا فقط.
    setState(_selectedSurahs.clear);
  }

  Future<void> _showConnectedRevisionRange() async {
    if (_memorizedSurahs.isEmpty) return;
    final ordered = List<MemorizedSurah>.from(_memorizedSurahs)
      ..sort((a, b) => _ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));
    var startSurahId = ordered.first.id;
    var endSurahId = ordered.first.id;
    var startAyah = ordered.first.minMemorizedAyah;
    var endAyah = ordered.first.maxMemorizedAyah;

    MemorizedSurah byId(int id) => ordered.firstWhere((item) => item.id == id);
    int indexOf(int id) => ordered.indexWhere((item) => item.id == id);

    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final startSurah = byId(startSurahId);
          final allowedEndSurahs = ordered.skip(indexOf(startSurahId)).toList();
          if (!allowedEndSurahs.any((item) => item.id == endSurahId)) {
            endSurahId = startSurahId;
            endAyah = startSurah.maxMemorizedAyah;
          }
          final endSurah = byId(endSurahId);
          List<DropdownMenuItem<int>> ayahItems(MemorizedSurah surah) => [
                for (var ayah = surah.minMemorizedAyah;
                    ayah <= surah.maxMemorizedAyah;
                    ayah++)
                  DropdownMenuItem(value: ayah, child: Text('آية $ayah')),
              ];
          return Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              4,
              20,
              20 + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نطاق مراجعة متصل',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر بداية المراجعة ونهايتها؛ سيملأ التطبيق كل السور الواقعة بينهما بالترتيب دون تجاوز محفوظ الطالب.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('connected_start_surah_$startSurahId'),
                        initialValue: startSurahId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'من سورة'),
                        items: ordered
                            .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            startSurahId = value;
                            final selected = byId(value);
                            startAyah = selected.minMemorizedAyah;
                            if (indexOf(endSurahId) < indexOf(value)) {
                              endSurahId = value;
                              endAyah = selected.maxMemorizedAyah;
                            }
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(
                          'connected_start_ayah_${startSurah.id}_$startAyah',
                        ),
                        initialValue: startAyah,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'من آية'),
                        items: ayahItems(startSurah),
                        onChanged: (value) {
                          if (value != null) setSheetState(() => startAyah = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey('connected_end_surah_$endSurahId'),
                        initialValue: endSurahId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'إلى سورة'),
                        items: allowedEndSurahs
                            .map((item) => DropdownMenuItem(
                                  value: item.id,
                                  child: Text(item.name),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setSheetState(() {
                            endSurahId = value;
                            endAyah = byId(value).maxMemorizedAyah;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(
                          'connected_end_ayah_${endSurah.id}_$endAyah',
                        ),
                        initialValue: endAyah,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'إلى آية'),
                        items: ayahItems(endSurah),
                        onChanged: (value) {
                          if (value != null) setSheetState(() => endAyah = value);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, true),
                    icon: const Icon(Icons.check),
                    label: const Text('تطبيق النطاق المتصل'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
    if (apply != true || !mounted) return;

    final allowedRanges = <int, QuranRangeSegment>{
      for (final surah in _memorizedSurahs)
        surah.id: QuranRangeSegment(
          surahId: surah.id,
          fromAyah: surah.minMemorizedAyah,
          toAyah: surah.maxMemorizedAyah,
        ),
    };
    final range = QuranCrossSurahRangeService.between(
      surahs: _quran.surahs,
      startSurahId: startSurahId,
      startAyah: startAyah,
      endSurahId: endSurahId,
      endAyah: endAyah,
      allowedRanges: allowedRanges,
      ascendingSurahs: _ascending,
    );
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تكوين النطاق؛ تأكد أن البداية والنهاية داخل محفوظ الطالب وبالترتيب.'),
        ),
      );
      return;
    }
    setState(() {
      _selectedSurahs.clear();
      _applyConnectedRange(
        range: range,
        availableSurahs: _memorizedSurahs,
        selectedSurahs: _selectedSurahs,
      );
      _resumeText = _connectedRangeLabel(
        range,
        availableSurahs: _memorizedSurahs,
        prefix: 'نطاق مراجعة متصل',
      );
    });
  }

  Future<void> _showReviewSettings() async {
    var unit = _reviewUnit;
    var amount = _reviewAmount;
    final apply = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.tune),
                  SizedBox(width: 8),
                  Text(
                    'إعداد مقرر جلسة المراجعة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: unit,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'طريقة القياس',
                  prefixIcon: Icon(Icons.straighten),
                ),
                items: const [
                  DropdownMenuItem(value: 'ayahs', child: Text('آيات')),
                  DropdownMenuItem(value: 'lines', child: Text('أسطر المصحف')),
                  DropdownMenuItem(value: 'pages', child: Text('صفحات')),
                  DropdownMenuItem(value: 'hizbs', child: Text('أحزاب')),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => unit = value);
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'المقدار: $amount ${_unitLabel(unit)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: amount <= 1
                        ? null
                        : () => setSheetState(() => amount--),
                    icon: const Icon(Icons.remove),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    onPressed: () => setSheetState(() => amount++),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'يحوّل التطبيق المقدار إلى نطاق سورة وآيات، ويكمل إلى السورة التالية عند الحاجة دون تجاوز محفوظ الطالب.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(Icons.check),
                  label: const Text('اعتماد وتطبيق على موضع الاستئناف'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (apply != true || !mounted) return;
    setState(() {
      _reviewUnit = unit;
      _reviewAmount = amount;
    });
    _reapplySuggestedRange();
  }

  void _reapplySuggestedRange() {
    final surahId = _suggestedSurahId;
    final fromAyah = _suggestedFromAyah;
    if (surahId == null || fromAyah == null) return;
    setState(() {
      _selectedSurahs.clear();
      final range = _connectedRange(
        availableSurahs: _memorizedSurahs,
        startSurahId: surahId,
        startAyah: fromAyah,
        unit: _reviewUnit,
        amount: _reviewAmount,
      );
      _applyConnectedRange(
        range: range,
        availableSurahs: _memorizedSurahs,
        selectedSurahs: _selectedSurahs,
      );
      _resumeText = _connectedRangeLabel(
        range,
        availableSurahs: _memorizedSurahs,
        prefix: 'مقرر المراجعة المقترح',
      );
    });
  }

  String? get _suggestedSurahName {
    final id = _suggestedSurahId;
    if (id == null) return null;
    for (final surah in _memorizedSurahs) {
      if (surah.id == id) return surah.name;
    }
    return null;
  }

  Widget _buildSurahList() {
    final query = _surahQuery.trim();
    final visible = (query.isEmpty
            ? List<MemorizedSurah>.from(_memorizedSurahs)
            : _memorizedSurahs
                .where(
                  (surah) =>
                      surah.name.contains(query) ||
                      surah.name.startsWith(query) ||
                      '${surah.id}' == query,
                )
                .toList());

    if (query.isEmpty && _suggestedSurahId != null) {
      visible.sort((a, b) {
        if (a.id == _suggestedSurahId && b.id != _suggestedSurahId) return -1;
        if (b.id == _suggestedSurahId && a.id != _suggestedSurahId) return 1;
        final aSelected = _selectedSurahs.contains(a.id);
        final bSelected = _selectedSurahs.contains(b.id);
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        return _memorizedSurahs.indexOf(a).compareTo(_memorizedSurahs.indexOf(b));
      });
    } else if (query.isNotEmpty) {
      int relevance(MemorizedSurah surah) {
        if ('${surah.id}' == query || surah.name == query) return 0;
        if (surah.name.startsWith(query)) return 1;
        return 2;
      }
      visible.sort((a, b) {
        if (a.id == _suggestedSurahId && b.id != _suggestedSurahId) return -1;
        if (b.id == _suggestedSurahId && a.id != _suggestedSurahId) return 1;
        final byRelevance = relevance(a).compareTo(relevance(b));
        if (byRelevance != 0) return byRelevance;
        return a.id.compareTo(b.id);
      });
    }

    if (visible.isEmpty) {
      return const Center(child: Text('لا توجد سورة محفوظة تطابق البحث'));
    }
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final surah = visible[index];
        final isSelected = _selectedSurahs.contains(surah.id);
        return _buildSurahCard(
          surah,
          isSelected,
          isSuggested: surah.id == _suggestedSurahId,
        );
      },
    );
  }

  Widget _buildSurahCard(
    MemorizedSurah surah,
    bool isSelected, {
    bool isSuggested = false,
  }) {
    final needsRevision = surah.lastRevision == null ||
        DateTime.now().difference(surah.lastRevision!).inDays > 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  _selectedSurahs.remove(surah.id);
                } else {
                  _selectPlanFrom(
                    surah,
                    fromAyah: surah.minMemorizedAyah,
                  );
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectPlanFrom(
                            surah,
                            fromAyah: surah.minMemorizedAyah,
                          );
                        } else {
                          _selectedSurahs.remove(surah.id);
                        }
                      });
                    },
                  ),
                  CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Text(
                      '${surah.id}',
                      style: TextStyle(
                        color: isSelected ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSuggested) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'مقترح الخطة — يبدأ من هنا',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSecondaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                        Text(
                          surah.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${surah.ayahs} آية - الجزء ${surah.juz}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        if (surah.minMemorizedAyah != 1 ||
                            surah.maxMemorizedAyah != surah.ayahs)
                          Text(
                            'المحفوظ المتاح: ${surah.minMemorizedAyah}–${surah.maxMemorizedAyah}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        if (surah.requiresCompletionRevision &&
                            surah.mandatoryFromPage != null)
                          Text(
                            surah.mandatoryFromPage == surah.mandatoryToPage
                                ? 'مقرر اليوم: الصفحة ${surah.mandatoryFromPage}'
                                : 'مقرر اليوم: الصفحات ${surah.mandatoryFromPage}–${surah.mandatoryToPage}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 5,
                          runSpacing: 3,
                          children: [
                            _revisionStatusTag(
                              surah.requiresCompletionRevision
                                  ? surah.mandatoryDayNumber != null
                                      ? 'مقترح تثبيت — اليوم ${surah.mandatoryDayNumber}/${surah.mandatoryTotalDays}'
                                      : 'مراجعة مقترحة بعد الإتمام'
                                  : needsRevision
                                      ? 'تحتاج مراجعة'
                                      : 'مراجعة حديثة',
                              surah.requiresCompletionRevision
                                  ? Colors.red
                                  : needsRevision
                                      ? Colors.orange
                                      : Colors.green,
                            ),
                            Text(
                              surah.lastRevision != null
                                  ? 'آخر مراجعة: ${Helpers.formatHijriDate(surah.lastRevision!)}'
                                  : 'لم تراجع سابقًا',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isSelected) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: AyahRangePicker(
                key: ValueKey('${surah.id}_${surah.rangeVersion}'),
                minAyah: surah.minMemorizedAyah,
                maxAyahs: surah.maxMemorizedAyah,
                initialFrom: surah.selectedFromAyah,
                initialTo: surah.selectedToAyah,
                enabled: true,
                onRangeChanged: (from, to) {
                  setState(() {
                    surah.selectedFromAyah = from;
                    surah.selectedToAyah = to;
                  });
                },
              ),
            ),
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _setRevisionBoundary(surah, 'page'),
                        child: const Text('نهاية الصفحة'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _setRevisionBoundary(surah, 'hizb'),
                        child: const Text('نهاية الحزب'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'السورة كاملة',
                      onPressed: () {
                        setState(() {
                          surah.selectedFromAyah = surah.minMemorizedAyah;
                          surah.selectedToAyah = surah.maxMemorizedAyah;
                          surah.rangeVersion++;
                        });
                      },
                      icon: const Icon(Icons.select_all),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _revisionStatusTag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9.5,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  void _selectPlanFrom(
    MemorizedSurah surah, {
    required int fromAyah,
  }) {
    final range = _connectedRange(
      availableSurahs: _memorizedSurahs,
      startSurahId: surah.id,
      startAyah: fromAyah,
      unit: _reviewUnit,
      amount: _reviewAmount,
    );
    _applyConnectedRange(
      range: range,
      availableSurahs: _memorizedSurahs,
      selectedSurahs: _selectedSurahs,
    );
  }

  void _setRevisionBoundary(MemorizedSurah surah, String boundary) {
    setState(() {
      final range = _connectedRange(
        availableSurahs: _memorizedSurahs,
        startSurahId: surah.id,
        startAyah: surah.selectedFromAyah,
        unit: boundary == 'page' ? 'pages' : 'hizbs',
        amount: 1,
      );
      _applyConnectedRange(
        range: range,
        availableSurahs: _memorizedSurahs,
        selectedSurahs: _selectedSurahs,
      );
      _resumeText = _connectedRangeLabel(
        range,
        availableSurahs: _memorizedSurahs,
        prefix: boundary == 'page' ? 'إلى نهاية الصفحة' : 'إلى نهاية الحزب',
      );
    });
  }

  String _unitLabel(String unit) {
    if (unit == 'ayahs') return 'آية';
    if (unit == 'lines') return 'سطر';
    if (unit == 'hizbs') return 'حزب';
    return 'صفحة';
  }

  Widget _buildBottomSheet() {
    int totalSelectedAyahs = 0;
    for (final surahId in _selectedSurahs) {
      final surah = _memorizedSurahs.firstWhere((s) => s.id == surahId, orElse: () => _memorizedSurahs.first);
      totalSelectedAyahs += (surah.selectedToAyah - surah.selectedFromAyah + 1);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'السور المحددة: ${_selectedSurahs.length} (إجمالي $totalSelectedAyahs آية)',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              QualityRating(
                rating: _qualityRating,
                onRatingChanged: (rating) {
                  setState(() => _qualityRating = rating);
                },
                size: 24,
                showLabel: false,
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveRevision,
              child: _isSaving
                  ? const CircularProgressIndicator(strokeWidth: 2)
                  : const Text('تسجيل المراجعة'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'يُحفظ نطاق المراجعة في سجل الطالب ويمكن استئنافه من آخر موضع.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRevision() async {
    final canRecord = await RecitationAttendanceGuard.confirmPresentIfAbsent(
      context,
      database: _db,
      student: widget.student,
      date: _recordDate,
    );
    if (!canRecord || !mounted) return;
    setState(() => _isSaving = true);

    try {
      int totalAyahs = 0;
      final progressRows = <MemorizationProgress>[];
      final grades = <HomeworkGrade>[];
      final selectedIds = _selectedSurahs.toList()
        ..sort((a, b) => _ascending ? a.compareTo(b) : b.compareTo(a));
      final sessionStartedAt = DateTime.now();
      final recordDate = _recordDate;

      for (var index = 0; index < selectedIds.length; index++) {
        final surahId = selectedIds[index];
        final surah = _memorizedSurahs.firstWhere((s) => s.id == surahId);
        final isInsideMemorizedRange =
            surah.selectedFromAyah >= surah.minMemorizedAyah &&
            surah.selectedToAyah <= surah.maxMemorizedAyah &&
            surah.selectedFromAyah <= surah.selectedToAyah;
        if (!isInsideMemorizedRange) {
          throw StateError(
            'نطاق ${surah.name} خارج المحفوظ المسجل '
            '(${surah.minMemorizedAyah}–${surah.maxMemorizedAyah})',
          );
        }
        final count = surah.selectedToAyah - surah.selectedFromAyah + 1;
        totalAyahs += count;

        final createdAt = sessionStartedAt.add(Duration(microseconds: index));
        final progress = MemorizationProgress(
          studentId: widget.student.id,
          surahId: surahId,
          fromAyah: surah.selectedFromAyah,
          toAyah: surah.selectedToAyah,
          date: recordDate,
          qualityRating: _qualityRating,
          isRevision: true,
          createdAt: createdAt,
        );

        progressRows.add(progress);
        final grade = HomeworkGrade(
          studentId: widget.student.id,
          surahId: surahId,
          fromAyah: surah.selectedFromAyah,
          toAyah: surah.selectedToAyah,
          date: recordDate,
          gradeMark: _qualityToGrade(_qualityRating),
          isRevision: true,
          createdAt: createdAt,
        );
        grades.add(grade);
      }

      final existingRecord = await _db.getDailyRecord(
        widget.student.id,
        recordDate,
      );

      final record = (existingRecord ?? DailyRecord(
        studentId: widget.student.id,
        date: recordDate,
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ??
            (BackdatedEntryPolicy.daysAgo(recordDate) == 0 ? sessionStartedAt : null),
        revisionDone: true,
        revisionAmount: (existingRecord?.revisionAmount ?? 0) + totalAyahs,
      );

      await _db.saveRevisionSession(
        progress: progressRows,
        grades: grades,
        dailyRecord: record,
      );
      for (final grade in grades) {
        try {
          await MushafService().updateProgressAfterGrading(grade);
        } catch (_) {
          // The revision record remains valid even if the visual map refresh fails.
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تسجيل مراجعة ${_selectedSurahs.length} سورة'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _qualityToGrade(int quality) {
    if (quality >= 5) return 'excellent';
    if (quality == 4) return 'very_good';
    if (quality == 3) return 'good';
    return 'needs_work';
  }
}

class MemorizedSurah {
  final int id;
  final String name;
  final int ayahs;
  final int juz;
  final int minMemorizedAyah;
  final int maxMemorizedAyah;
  final DateTime? lastRevision;
  final bool requiresCompletionRevision;
  final int? mandatoryDayNumber;
  final int? mandatoryTotalDays;
  final int? mandatoryFromPage;
  final int? mandatoryToPage;
  int selectedFromAyah;
  int selectedToAyah;
  int rangeVersion;

  MemorizedSurah({
    required this.id,
    required this.name,
    required this.ayahs,
    required this.juz,
    required this.minMemorizedAyah,
    required this.maxMemorizedAyah,
    this.lastRevision,
    this.requiresCompletionRevision = false,
    this.mandatoryDayNumber,
    this.mandatoryTotalDays,
    this.mandatoryFromPage,
    this.mandatoryToPage,
    int? selectedFromAyah,
    int? selectedToAyah,
    this.rangeVersion = 0,
  }) : this.selectedFromAyah = selectedFromAyah ?? minMemorizedAyah,
       this.selectedToAyah = selectedToAyah ?? maxMemorizedAyah;
}
