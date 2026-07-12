import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/memorization_measure_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/quran_service.dart';
import '../../services/recitation_boundary_service.dart';
import '../../services/revision_progression_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/homework_grade.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/quality_rating.dart';
import '../../widgets/ayah_range_picker.dart';

class RevisionScreen extends StatefulWidget {
  final Student student;

  const RevisionScreen({super.key, required this.student});

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

  @override
  void initState() {
    super.initState();
    _loadMemorizedSurahs();
  }

  Future<void> _loadMemorizedSurahs() async {
    setState(() => _isLoading = true);
    try {
      final surahIds = await _db.getMemorizedSurahs(widget.student.id);
      final allProgress = await _db.getStudentMemorization(widget.student.id);
      final settings = await _db.getSettings();
      final activePlan = await _db.getActiveStudentPlan(widget.student.id);
      _ascending = settings.revisionOrder != 'descending';
      _reviewUnit = activePlan?.unit ?? 'pages';
      _reviewAmount = activePlan?.reviewAmount ?? 1;

      final surahs = <MemorizedSurah>[];
      final requiredSurahs = <int>{};
      for (final surahId in surahIds) {
        final surahData = QuranData.surahs.firstWhere(
          (s) => s['id'] == surahId,
          orElse: () => {},
        );
        if (surahData.isEmpty) continue;

        final revisions = allProgress
            .where((p) => p.surahId == surahId && p.isRevision)
            .toList();

        DateTime? lastRevision;
        DateTime? lastRevisionAt;
        if (revisions.isNotEmpty) {
          revisions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          lastRevision = revisions.first.date;
          lastRevisionAt = revisions.first.createdAt;
        }

        final completionDate = _getCompletionDate(
          surahId,
          surahData['ayahs'],
          allProgress,
        );
        final requiresCompletionRevision = completionDate != null &&
            (lastRevisionAt == null || lastRevisionAt.isBefore(completionDate));
        if (requiresCompletionRevision) requiredSurahs.add(surahId);

        surahs.add(MemorizedSurah(
          id: surahId,
          name: surahData['name'],
          ayahs: surahData['ayahs'],
          juz: surahData['juz'],
          lastRevision: lastRevision,
          requiresCompletionRevision: requiresCompletionRevision,
        ));
      }

      _sortSurahs(surahs);

      String? resumeText;
      if (requiredSurahs.isEmpty && surahs.isNotEmpty) {
        final next = RevisionProgressionService.nextStartingPoint(
          memorizedSurahIds: surahs.map((surah) => surah.id).toList(),
          progress: allProgress,
          ascending: _ascending,
          getSurah: _quran.getSurah,
        );
        if (next != null) {
          final suggested = surahs.firstWhere(
            (surah) => surah.id == next['surahId'],
          );
          _applyDefaultRange(
            suggested,
            fromAyah: next['fromAyah']!,
          );
          requiredSurahs.add(suggested.id);
          final hasPreviousRevision =
              allProgress.any((progress) => progress.isRevision);
          resumeText = hasPreviousRevision
              ? 'استئناف المراجعة: ${suggested.name} من الآية ${suggested.selectedFromAyah}'
              : 'بداية دورة المراجعة: ${suggested.name} من الآية ${suggested.selectedFromAyah}';
        }
      }

      setState(() {
        _memorizedSurahs = surahs;
        _selectedSurahs = requiredSurahs;
        _resumeText = resumeText;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _applyDefaultRange(
    MemorizedSurah surah, {
    required int fromAyah,
  }) {
    final detailed = _quran.getSurah(surah.id);
    final safeFrom = fromAyah.clamp(1, surah.ayahs).toInt();
    surah.selectedFromAyah = safeFrom;
    if (detailed == null) {
      surah.selectedToAyah = safeFrom;
    } else {
      surah.selectedToAyah = MemorizationMeasureService.calculateToAyah(
        surah: detailed,
        fromAyah: safeFrom,
        planType: _reviewUnit,
        planAmount: _reviewAmount,
      );
    }
    surah.rangeVersion++;
  }

  void _sortSurahs(List<MemorizedSurah> surahs) {
    surahs.sort((a, b) {
      if (a.requiresCompletionRevision != b.requiresCompletionRevision) {
        return a.requiresCompletionRevision ? -1 : 1;
      }
      return _ascending ? a.id.compareTo(b.id) : b.id.compareTo(a.id);
    });
  }

  DateTime? _getCompletionDate(
    int surahId,
    int totalAyahs,
    List<MemorizationProgress> allProgress,
  ) {
    final memorized = <int>{};
    for (var ayah = 1; ayah <= totalAyahs; ayah++) {
      if (_isPreMemorizedAyah(surahId, ayah)) memorized.add(ayah);
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

  bool _isPreMemorizedAyah(int surahId, int ayah) {
    final startSurah = widget.student.preMemorizedStartSurah;
    final endSurah = widget.student.preMemorizedEndSurah;
    if (startSurah == null || endSurah == null) return false;
    final startAyah = widget.student.preMemorizedStartAyah ?? 1;
    final endAyah = widget.student.preMemorizedEndAyah ?? 1;
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
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _memorizedSurahs.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildSortingInfo(),
                      if (_resumeText != null) _buildResumeInfo(),
                      _buildSelectionInfo(),
                      Expanded(child: _buildSurahList()),
                      if (_selectedSurahs.isNotEmpty) _buildBottomSheet(),
                    ],
                  ),
      ),
    );
  }

  Widget _buildResumeInfo() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.play_circle_outline, color: Colors.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _resumeText!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'المقرر المقترح: $_reviewAmount ${_unitLabel(_reviewUnit)}',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book, size: 60, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'لا يوجد حفظ مسجل لهذا الطالب',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'قم بتسجيل الحفظ أولاً',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _ascending ? Icons.arrow_downward : Icons.arrow_upward,
            size: 16,
            color: Theme.of(context).primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            _ascending
                ? 'مراجعة تصاعدية (من الفاتحة)'
                : 'مراجعة تنازلية (من آخر ما حفظ)',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionInfo() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'السور المحفوظة: ${_memorizedSurahs.length}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_selectedSurahs.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _selectedSurahs.removeWhere((surahId) {
                  final surah = _memorizedSurahs.firstWhere(
                    (item) => item.id == surahId,
                  );
                  return !surah.requiresCompletionRevision;
                });
              }),
              child: Text('إلغاء التحديد (${_selectedSurahs.length})'),
            ),
        ],
      ),
    );
  }

  Widget _buildSurahList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _memorizedSurahs.length,
      itemBuilder: (context, index) {
        final surah = _memorizedSurahs[index];
        final isSelected = _selectedSurahs.contains(surah.id);
        return _buildSurahCard(surah, isSelected);
      },
    );
  }

  Widget _buildSurahCard(MemorizedSurah surah, bool isSelected) {
    final needsRevision = surah.lastRevision == null ||
        DateTime.now().difference(surah.lastRevision!).inDays > 7;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  if (!surah.requiresCompletionRevision) {
                    _selectedSurahs.remove(surah.id);
                  }
                } else {
                  _selectedSurahs.add(surah.id);
                  _applyDefaultRange(surah, fromAyah: 1);
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
                    onChanged: surah.requiresCompletionRevision ? null : (value) {
                      setState(() {
                        if (value == true) {
                          _selectedSurahs.add(surah.id);
                          _applyDefaultRange(surah, fromAyah: 1);
                        } else {
                          _selectedSurahs.remove(surah.id);
                        }
                      });
                    },
                  ),
                  CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Text(
                      '${surah.id}',
                      style: TextStyle(
                        color: isSelected ? Colors.white : Theme.of(context).primaryColor,
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
                        Text(
                          surah.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${surah.ayahs} آية - الجزء ${surah.juz}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: surah.requiresCompletionRevision
                              ? Colors.red.withOpacity(0.1)
                              : needsRevision
                                  ? Colors.orange.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          surah.requiresCompletionRevision
                              ? 'مراجعة إلزامية بعد إتمام السورة'
                              : needsRevision
                                  ? 'تحتاج مراجعة'
                                  : 'مراجعة حديثة',
                          style: TextStyle(
                            fontSize: 10,
                            color: surah.requiresCompletionRevision
                                ? Colors.red
                                : needsRevision
                                    ? Colors.orange
                                    : Colors.green,
                          ),
                          maxLines: 2,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        surah.lastRevision != null
                            ? Helpers.formatHijriDate(surah.lastRevision!)
                            : 'لم تراجع',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                    ],
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
                maxAyahs: surah.ayahs,
                initialFrom: surah.selectedFromAyah,
                initialTo: surah.selectedToAyah,
                enabled: !surah.requiresCompletionRevision,
                onRangeChanged: (from, to) {
                  setState(() {
                    surah.selectedFromAyah = from;
                    surah.selectedToAyah = to;
                  });
                },
              ),
            ),
            if (!surah.requiresCompletionRevision)
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
                          surah.selectedToAyah = surah.ayahs;
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

  void _setRevisionBoundary(MemorizedSurah surah, String boundary) {
    final detailed = _quran.getSurah(surah.id);
    if (detailed == null) return;
    setState(() {
      surah.selectedToAyah = boundary == 'page'
          ? RecitationBoundaryService.endOfPage(
              detailed,
              surah.selectedFromAyah,
            )
          : RecitationBoundaryService.endOfHizb(
              detailed,
              surah.selectedFromAyah,
            );
      surah.rangeVersion++;
    });
  }

  String _unitLabel(String unit) {
    if (unit == 'ayahs') return 'آية';
    if (unit == 'lines') return 'سطر';
    return 'صفحة';
  }

  Widget _buildBottomSheet() {
    int totalSelectedAyahs = 0;
    for (final surahId in _selectedSurahs) {
      final surah = _memorizedSurahs.firstWhere((s) => s.id == surahId, orElse: () => _memorizedSurahs.first);
      totalSelectedAyahs += (surah.selectedToAyah - surah.selectedFromAyah + 1);
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تسجيل المراجعة'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRevision() async {
    setState(() => _isSaving = true);

    try {
      int totalAyahs = 0;
      final progressRows = <MemorizationProgress>[];
      final grades = <HomeworkGrade>[];
      final selectedIds = _selectedSurahs.toList()
        ..sort((a, b) => _ascending ? a.compareTo(b) : b.compareTo(a));
      final sessionStartedAt = DateTime.now();

      for (var index = 0; index < selectedIds.length; index++) {
        final surahId = selectedIds[index];
        final surah = _memorizedSurahs.firstWhere((s) => s.id == surahId);
        final count = surah.selectedToAyah - surah.selectedFromAyah + 1;
        totalAyahs += count;

        final createdAt = sessionStartedAt.add(Duration(microseconds: index));
        final progress = MemorizationProgress(
          studentId: widget.student.id,
          surahId: surahId,
          fromAyah: surah.selectedFromAyah,
          toAyah: surah.selectedToAyah,
          date: DateTime.now(),
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
          date: DateTime.now(),
          gradeMark: _qualityToGrade(_qualityRating),
          isRevision: true,
          createdAt: createdAt,
        );
        grades.add(grade);
      }

      final existingRecord = await _db.getDailyRecord(
        widget.student.id,
        DateTime.now(),
      );

      final record = (existingRecord ?? DailyRecord(
        studentId: widget.student.id,
        date: DateTime.now(),
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ?? DateTime.now(),
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
  final DateTime? lastRevision;
  final bool requiresCompletionRevision;
  int selectedFromAyah;
  int selectedToAyah;
  int rangeVersion;

  MemorizedSurah({
    required this.id,
    required this.name,
    required this.ayahs,
    required this.juz,
    this.lastRevision,
    this.requiresCompletionRevision = false,
    int? selectedFromAyah,
    int? selectedToAyah,
    this.rangeVersion = 0,
  }) : this.selectedFromAyah = selectedFromAyah ?? 1,
       this.selectedToAyah = selectedToAyah ?? ayahs;
}
