import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/quran_service.dart';
import '../../services/memorization_progression_service.dart';
import '../../services/quran_cross_surah_range_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/student_learning_policy.dart';
import '../../services/recitation_flow_coordinator.dart';
import '../../services/recitation_attendance_guard.dart';
import '../../services/backdated_entry_policy.dart';
import '../../app/design_tokens.dart';
import '../../widgets/app_design_widgets.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/homework_grade.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/surah_picker.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../widgets/quran_endpoint_picker.dart';
import '../../widgets/quality_rating.dart';

class AddMemorizationScreen extends StatefulWidget {
  final Student? student;
  final String? planUnitOverride;
  final int? planAmountOverride;
  final String? courseTitle;

  const AddMemorizationScreen({
    super.key,
    this.student,
    this.planUnitOverride,
    this.planAmountOverride,
    this.courseTitle,
  });

  @override
  State<AddMemorizationScreen> createState() => _AddMemorizationScreenState();
}

class _AddMemorizationScreenState extends State<AddMemorizationScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  final _formKey = GlobalKey<FormState>();

  Student? _selectedStudent;
  List<Student> _students = [];
  int? _selectedSurahId;
  int _fromAyah = 1;
  int _toAyah = 1;
  int _qualityRating = 3;
  String _notes = '';
  bool _isLoading = true;
  bool _isSaving = false;
  bool _ownsRecitationFlow = false;
  String? _flowStudentId;
  QuranCrossSurahRange? _connectedRange;
  DateTime _recordDate = BackdatedEntryPolicy.dateOnly(DateTime.now());


  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student;
    if (widget.student != null) {
      _ownsRecitationFlow = RecitationFlowCoordinator.acquire(
        widget.student!.id,
        this,
      );
      if (_ownsRecitationFlow) _flowStudentId = widget.student!.id;
      if (!_ownsRecitationFlow) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'توجد شاشة تسميع أو حفظ مفتوحة لهذا الطالب. أغلقها أولًا ثم أعد المحاولة.',
              ),
            ),
          );
          Navigator.maybePop(context);
        });
        return;
      }
    }
    _loadStudents();
  }

  @override
  void dispose() {
    if (_ownsRecitationFlow && _flowStudentId != null) {
      RecitationFlowCoordinator.release(_flowStudentId!, this);
    }
    super.dispose();
  }

  bool _switchRecitationFlow(Student? student) {
    final nextId = student?.id;
    if (nextId == _flowStudentId) return true;
    if (_ownsRecitationFlow && _flowStudentId != null) {
      RecitationFlowCoordinator.release(_flowStudentId!, this);
    }
    _ownsRecitationFlow = false;
    _flowStudentId = null;
    if (nextId == null) return true;
    final acquired = RecitationFlowCoordinator.acquire(nextId, this);
    if (acquired) {
      _ownsRecitationFlow = true;
      _flowStudentId = nextId;
    }
    return acquired;
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      await _quran.initialize();
      final students = (await _db.getStudents(status: 'active'))
          .where(StudentLearningPolicy.canReceiveNewMemorization)
          .toList();
      setState(() {
        _students = students;
        if (_selectedStudent != null) {
          _selectedStudent = students.firstWhere(
            (s) => s.id == _selectedStudent!.id,
            orElse: () => _selectedStudent!,
          );
        }
      });
      if (_selectedStudent != null) {
        final startPoint = await _getNextMemorizationStartingPoint(_selectedStudent!);
        if (startPoint != null) {
          final range = _buildPlanRange(
            _selectedStudent!,
            startPoint['surahId']!,
            startPoint['fromAyah']!,
          );
          setState(() {
            _selectedSurahId = startPoint['surahId'];
            _fromAyah = startPoint['fromAyah']!;
            _toAyah = range?.segments.first.toAyah ?? startPoint['toAyah']!;
            _connectedRange = range;
          });
        }
      }
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickRecordDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recordDate,
      firstDate: BackdatedEntryPolicy.earliestAllowed(now),
      lastDate: BackdatedEntryPolicy.dateOnly(now),
      helpText: 'تاريخ الحفظ (حتى 3 أيام سابقة)',
      confirmText: 'اعتماد',
    );
    if (picked == null || !mounted) return;
    setState(() => _recordDate = BackdatedEntryPolicy.dateOnly(picked));
  }

  Map<String, dynamic>? get _selectedSurah {
    if (_selectedSurahId == null) return null;
    return QuranData.surahs.firstWhere(
      (s) => s['id'] == _selectedSurahId,
      orElse: () => {},
    );
  }

  QuranCrossSurahRange? get _effectiveRange {
    if (_connectedRange != null) return _connectedRange;
    if (_selectedSurahId == null) return null;
    return QuranCrossSurahRangeService.fromAyahs(
      _quran.getAyahRange(_selectedSurahId!, _fromAyah, _toAyah),
    );
  }

  int get _ayahCount => _effectiveRange?.ayahs.length ?? 0;
  double get _estimatedLines {
    return _effectiveRange?.ayahs.fold<double>(
          0,
          (sum, ayah) => sum + ayah.lines,
        ) ??
        0;
  }

  QuranCrossSurahRange? _buildPlanRange(
    Student student,
    int surahId,
    int fromAyah,
  ) {
    return QuranCrossSurahRangeService.toAmount(
      surahs: _quran.surahs,
      startSurahId: surahId,
      startAyah: fromAyah,
      unit: QuranCrossSurahRangeService.unitFromPlanType(
        widget.planUnitOverride ?? student.planType,
      ),
      amount: widget.planAmountOverride ?? student.planAmount,
      ascendingSurahs: student.memorizationDirection != 'desc',
    );
  }

  String _rangeLabel(QuranCrossSurahRange range) {
    final first = range.ayahs.first;
    final last = range.ayahs.last;
    final firstName = _quran.getSurahName(first.surahNumber);
    final lastName = _quran.getSurahName(last.surahNumber);
    if (first.surahNumber == last.surahNumber) {
      return 'سورة $firstName: ${first.number} - ${last.number}';
    }
    return 'من $firstName (${first.number}) إلى $lastName (${last.number})';
  }

  String _qualityToGrade(int quality) {
    if (quality >= 5) return 'excellent';
    if (quality == 4) return 'very_good';
    if (quality == 3) return 'good';
    return 'needs_work';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحفظ المباشر'),
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
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : AppScreenBody(
                scrollable: true,
                maxWidth: 760,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AppPageIntro(
                        title: 'اعتماد الحفظ المنفّذ',
                        subtitle:
                            'راجع الطالب والنطاق والتقييم، ثم احفظ التسجيل مرة واحدة.',
                        icon: Icons.auto_stories_outlined,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (widget.student == null) ...[
                        _buildStudentSelector(),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      if (_selectedStudent != null) ...[
                        _buildStudentInfo(),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      _buildSurahSelector(),
                      if (_selectedSurahId != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        _buildAyahRangePicker(),
                        const SizedBox(height: AppSpacing.sm),
                        OutlinedButton.icon(
                          onPressed: _selectCrossSurahEnd,
                          icon: const Icon(Icons.route_outlined),
                          label: const Text('تحديد النهاية في سورة أخرى'),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildEstimatedLines(),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _buildQualityRating(),
                      const SizedBox(height: AppSpacing.sm),
                      _buildNotesField(),
                      const SizedBox(height: AppSpacing.lg),
                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildStudentSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الطالب',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Student>(
              initialValue: _selectedStudent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              hint: const Text('اختر طالباً'),
              items: _students.map((student) {
                return DropdownMenuItem(
                  value: student,
                  child: Text(student.name),
                );
              }).toList(),
              onChanged: (student) async {
                if (!_switchRecitationFlow(student)) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'توجد شاشة تسميع أو حفظ مفتوحة لهذا الطالب.',
                      ),
                    ),
                  );
                  return;
                }
                setState(() {
                  _selectedStudent = student;
                  _selectedSurahId = null;
                  _connectedRange = null;
                });
                if (student != null) {
                  final startPoint = await _getNextMemorizationStartingPoint(student);
                  if (startPoint != null && _selectedStudent?.id == student.id) {
                    final range = _buildPlanRange(
                      student,
                      startPoint['surahId']!,
                      startPoint['fromAyah']!,
                    );
                    setState(() {
                      _selectedSurahId = startPoint['surahId'];
                      _fromAyah = startPoint['fromAyah']!;
                      _toAyah = range?.segments.first.toAyah ??
                          startPoint['toAyah']!;
                      _connectedRange = range;
                    });
                  }
                }
              },
              validator: (value) {
                if (value == null) return 'يرجى اختيار طالب';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentInfo() {
    final student = _selectedStudent!;
    final planUnit = widget.planUnitOverride ?? student.planType;
    final planAmount = widget.planAmountOverride ?? student.planAmount;
    final courseSuffix = widget.courseTitle == null
        ? ''
        : ' · دورة ${widget.courseTitle}';
    return AppFocusPanel(
      eyebrow: 'الطالب المحدد',
      title: student.name,
      description:
          'المقرر $planAmount ${_getPlanLabel(planUnit)}$courseSuffix · المحفوظ ${student.totalMemorized} آية',
      icon: Icons.person_outline_rounded,
    );
  }

  Widget _buildSurahSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر السورة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectSurah,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedSurah != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedSurah!['name'],
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${_selectedSurah!['ayahs']} آية - الجزء ${_selectedSurah!['juz']}',
                                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                ),
                              ],
                            )
                          : Text(
                              'اضغط لاختيار السورة',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                    ),
                    const Icon(Icons.arrow_back_ios_new_rounded, size: 15),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAyahRangePicker() {
    final maxAyahs = _selectedSurah?['ayahs'] ?? 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: AyahRangePicker(
          maxAyahs: maxAyahs,
          initialFrom: _fromAyah,
          initialTo: _toAyah,
          onRangeChanged: (from, to) {
            setState(() {
              _fromAyah = from;
              _toAyah = to;
              _connectedRange = null;
            });
          },
        ),
      ),
    );
  }

  Future<void> _selectCrossSurahEnd() async {
    final student = _selectedStudent;
    final startSurahId = _selectedSurahId;
    if (student == null || startSurahId == null) return;
    final endpoint = await showQuranEndpointPicker(
      context,
      initialSurahId: startSurahId,
      initialAyah: _toAyah,
      title: 'نهاية الحفظ',
    );
    if (endpoint == null || !mounted) return;
    final range = QuranCrossSurahRangeService.between(
      surahs: _quran.surahs,
      startSurahId: startSurahId,
      startAyah: _fromAyah,
      endSurahId: endpoint.surahId,
      endAyah: endpoint.ayah,
      ascendingSurahs: student.memorizationDirection != 'desc',
    );
    if (range == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('نهاية النطاق يجب أن تأتي بعد البداية في اتجاه حفظ الطالب'),
        ),
      );
      return;
    }
    setState(() {
      _connectedRange = range;
      _toAyah = range.segments.first.toAyah;
    });
  }

  Widget _buildEstimatedLines() {
    final lines = _estimatedLines;
    final range = _effectiveRange;
    final pages = range?.ayahs.map((ayah) => ayah.page).toSet().length ?? 0;
    final semantic = context.semanticColors;
    return Card(
      color: semantic.infoContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.straighten, color: semantic.info),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'التقدير',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$_ayahCount آية ≈ ${lines.toStringAsFixed(1)} سطر ($pages صفحة)',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                  ),
                  if (range != null && range.segments.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      _rangeLabel(range),
                      style: TextStyle(
                        color: semantic.info,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityRating() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: QualityRatingSelector(
          selectedRating: _qualityRating,
          onRatingSelected: (rating) {
            setState(() => _qualityRating = rating);
          },
        ),
      ),
    );
  }

  Widget _buildNotesField() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملاحظات',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظات (اختياري)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) => _notes = value,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveMemorization,
        icon: _isSaving
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check_rounded),
        label: Text(_isSaving ? 'جارٍ الحفظ...' : 'اعتماد وحفظ التسجيل'),
      ),
    );
  }

  Future<void> _selectSurah() async {
    final surahId = await showSurahPicker(
      context,
      selectedSurahId: _selectedSurahId,
    );
    if (surahId != null) {
      setState(() {
        _selectedSurahId = surahId;
        _fromAyah = 1;
        final surah = QuranData.surahs.firstWhere((s) => s['id'] == surahId);
        _toAyah = surah['ayahs'];
        _connectedRange = null;
      });
    }
  }

  Future<void> _saveMemorization() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طالب')),
      );
      return;
    }

    if (_selectedSurahId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار سورة')),
      );
      return;
    }

    if (StudentLearningPolicy.hasCompletedQuran(_selectedStudent!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الطالب أتم حفظ القرآن؛ المتاح له هو المراجعة'),
        ),
      );
      return;
    }

    final canRecord = await RecitationAttendanceGuard.confirmPresentIfAbsent(
      context,
      database: _db,
      student: _selectedStudent!,
      date: _recordDate,
    );
    if (!canRecord || !mounted) return;

    setState(() => _isSaving = true);

    try {
      final currentStudent =
          await _db.getStudent(_selectedStudent!.id) ?? _selectedStudent!;
      final range = _effectiveRange;
      if (range == null || range.ayahs.isEmpty) {
        throw StateError('نطاق الحفظ غير صالح');
      }
      var newlyMemorizedAyahs = 0;
      for (final segment in range.segments) {
        newlyMemorizedAyahs += await _db.countNewMemorizedAyahs(
          student: currentStudent,
          surahId: segment.surahId,
          fromAyah: segment.fromAyah,
          toAyah: segment.toAyah,
        );
      }

      final actualNow = DateTime.now();
      final recordDate = _recordDate;
      final isToday = BackdatedEntryPolicy.daysAgo(recordDate, now: actualNow) == 0;
      final note = _notes.trim();
      final progressRows = <MemorizationProgress>[];
      final grades = <HomeworkGrade>[];
      for (var index = 0; index < range.segments.length; index++) {
        final segment = range.segments[index];
        progressRows.add(
          MemorizationProgress(
            studentId: _selectedStudent!.id,
            surahId: segment.surahId,
            fromAyah: segment.fromAyah,
            toAyah: segment.toAyah,
            date: recordDate,
            qualityRating: _qualityRating,
            isRevision: false,
            notes: index == 0 && note.isNotEmpty ? note : null,
            createdAt: actualNow,
          ),
        );
        grades.add(
          HomeworkGrade(
            studentId: _selectedStudent!.id,
            surahId: segment.surahId,
            fromAyah: segment.fromAyah,
            toAyah: segment.toAyah,
            date: recordDate,
            gradeMark: _qualityToGrade(_qualityRating),
            isRevision: false,
            remark: index == 0 && note.isNotEmpty ? note : null,
            createdAt: actualNow,
          ),
        );
      }

      final existingRecord = await _db.getDailyRecord(
        _selectedStudent!.id,
        recordDate,
      );

      final record = (existingRecord ?? DailyRecord(
        studentId: _selectedStudent!.id,
        date: recordDate,
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ?? (isToday ? actualNow : null),
        memorizationDone: true,
        memorizationAmount:
            (existingRecord?.memorizationAmount ?? 0) + newlyMemorizedAyahs,
        memorizationNote: note.isEmpty ? existingRecord?.memorizationNote : note,
      );

      final updatedTotal = (currentStudent.totalMemorized + newlyMemorizedAyahs)
          .clamp(0, QuranData.totalAyahs)
          .toInt();
      await _db.saveRecitationSession(
        progress: progressRows,
        grades: grades,
        dailyRecord: record,
        updatedTotalMemorized: updatedTotal,
      );
      for (final grade in grades) {
        try {
          await MushafService().updateProgressAfterGrading(grade);
        } catch (_) {
          // The connected memorization record remains valid if map refresh fails.
        }
      }

      final pointsResult = await _db.recalculateDailyRecitationPoints(
        studentId: _selectedStudent!.id,
        date: recordDate,
      );

      final completedSurahNames = <String>[];
      if (newlyMemorizedAyahs > 0) {
        for (final segment in range.segments) {
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
              completedSurahNames.isNotEmpty
                  ? 'تم إتمام ${completedSurahNames.map((name) => 'سورة $name').join('، ')}، وأضيفت إلى مقترحات المراجعة'
                  : pointsResult.totalPoints > 0
                      ? 'تم حفظ التسجيل، ورصيد إنجاز اليوم ${pointsResult.totalPoints} نقاط 🎉'
                      : 'تم حفظ التسجيل بنجاح',
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
          SnackBar(
            content: Text('حدث خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, int>?> _getNextMemorizationStartingPoint(Student student) async {
    final allProgress = await _db.getStudentMemorization(student.id);
    return MemorizationProgressionService.nextStartingPoint(
      student: student,
      progress: allProgress,
      getSurah: _quran.getSurah,
    );
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      case 'hizbs':
        return 'حزب';
      default:
        return planType;
    }
  }
}
