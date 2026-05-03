import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';
import '../../widgets/quality_rating.dart';

class RevisionScreen extends StatefulWidget {
  final Student student;

  const RevisionScreen({super.key, required this.student});

  @override
  State<RevisionScreen> createState() => _RevisionScreenState();
}

class _RevisionScreenState extends State<RevisionScreen> {
  final DatabaseService _db = DatabaseService();
  List<MemorizedSurah> _memorizedSurahs = [];
  Set<int> _selectedSurahs = {};
  bool _isLoading = true;
  bool _isSaving = false;
  bool _ascending = true;
  int _qualityRating = 3;

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

      final surahs = <MemorizedSurah>[];
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
        if (revisions.isNotEmpty) {
          revisions.sort((a, b) => b.date.compareTo(a.date));
          lastRevision = revisions.first.date;
        }

        surahs.add(MemorizedSurah(
          id: surahId,
          name: surahData['name'],
          ayahs: surahData['ayahs'],
          juz: surahData['juz'],
          lastRevision: lastRevision,
        ));
      }

      _sortSurahs(surahs);

      setState(() {
        _memorizedSurahs = surahs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _sortSurahs(List<MemorizedSurah> surahs) {
    if (_ascending) {
      surahs.sort((a, b) => a.id.compareTo(b.id));
    } else {
      surahs.sort((a, b) => b.id.compareTo(a.id));
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _memorizedSurahs.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    _buildSortingInfo(),
                    _buildSelectionInfo(),
                    Expanded(child: _buildSurahList()),
                    if (_selectedSurahs.isNotEmpty) _buildBottomSheet(),
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
              onPressed: () => setState(() => _selectedSurahs.clear()),
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
      child: InkWell(
        onTap: () {
          setState(() {
            if (isSelected) {
              _selectedSurahs.remove(surah.id);
            } else {
              _selectedSurahs.add(surah.id);
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
                      _selectedSurahs.add(surah.id);
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: needsRevision
                          ? Colors.orange.withOpacity(0.1)
                          : Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      needsRevision ? 'تحتاج مراجعة' : 'مراجعة حديثة',
                      style: TextStyle(
                        fontSize: 10,
                        color: needsRevision ? Colors.orange : Colors.green,
                      ),
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
    );
  }

  Widget _buildBottomSheet() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'السور المحددة: ${_selectedSurahs.length}',
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

      for (final surahId in _selectedSurahs) {
        final surah = _memorizedSurahs.firstWhere((s) => s.id == surahId);
        totalAyahs += surah.ayahs;

        final progress = MemorizationProgress(
          studentId: widget.student.id,
          surahId: surahId,
          fromAyah: 1,
          toAyah: surah.ayahs,
          date: DateTime.now(),
          qualityRating: _qualityRating,
          isRevision: true,
        );

        await _db.insertMemorization(progress);
      }

      final existingRecord = await _db.getDailyRecord(
        widget.student.id,
        DateTime.now(),
      );

      final record = (existingRecord ?? DailyRecord(
        studentId: widget.student.id,
        date: DateTime.now(),
      )).copyWith(
        revisionDone: true,
        revisionAmount: totalAyahs,
      );

      await _db.saveDailyRecord(record);

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
}

class MemorizedSurah {
  final int id;
  final String name;
  final int ayahs;
  final int juz;
  final DateTime? lastRevision;

  MemorizedSurah({
    required this.id,
    required this.name,
    required this.ayahs,
    required this.juz,
    this.lastRevision,
  });
}
