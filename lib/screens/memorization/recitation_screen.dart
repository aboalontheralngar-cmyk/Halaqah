import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart';
import '../../services/mushaf_service.dart';
import '../../services/memorization_measure_service.dart';
import '../../services/memorization_progression_service.dart';
import '../../services/recitation_boundary_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/ayah.dart';
import '../../models/homework_grade.dart';
import '../../models/behavior_point.dart';
import '../../models/settings.dart';
import '../../widgets/surah_picker.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../utils/helpers.dart';

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
  List<Ayah> _ayahs = [];
  Map<int, int> _ayahRatings = {};
  bool _openEnded = true;

  // New Grading State Fields
  bool _isRevision = false;
  String _selectedGrade = 'good';
  int _mistakesCount = 0;
  final TextEditingController _remarkController = TextEditingController();

  // Recitation Stopwatch variables
  Duration _recitationDuration = Duration.zero;
  Timer? _timer;
  bool _isTimerRunning = false;

  Surah? get _selectedSurah => _selectedSurahId != null 
      ? _quran.getSurah(_selectedSurahId!) 
      : null;

  @override
  void initState() {
    super.initState();
    _loadInitialStartingPoint();
  }

  Future<void> _loadInitialStartingPoint() async {
    final startPoint = await _getNextMemorizationStartingPoint(widget.student);
    if (startPoint != null) {
      setState(() {
        _selectedSurahId = startPoint['surahId'];
        _fromAyah = startPoint['fromAyah']!;
        _toAyah = startPoint['toAyah']!;
      });
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

  @override
  void dispose() {
    _timer?.cancel();
    _remarkController.dispose();
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
    final effectiveTo = _openEnded
        ? (_selectedSurah?.totalAyahs ?? _toAyah)
        : _toAyah;
    final ayahs = _quran.getAyahRange(
      _selectedSurahId!,
      _fromAyah,
      effectiveTo,
    );
    if (ayahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر بدء التسميع من النطاق المحدد')),
      );
      return;
    }
    setState(() {
      _toAyah = effectiveTo;
      _ayahs = ayahs;
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
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            widget.student.name[0],
            style: const TextStyle(color: Colors.white),
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
                  setState(() {
                    _selectedSurahId = surahId;
                    _fromAyah = 1;
                    _toAyah = surah?.totalAyahs ?? 1;
                  });
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book, color: Colors.blue),
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
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : Text('اضغط لاختيار السورة', style: TextStyle(color: Colors.grey[600])),
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
                  if (value) _toAyah = _fromAyah;
                });
              },
            ),
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
                setState(() {
                  _fromAyah = from;
                  _toAyah = _openEnded ? from : to;
                });
              },
            ),
            const SizedBox(height: 12),
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

  void _setEndOfCurrentPage() {
    final surah = _selectedSurah;
    if (surah == null) return;
    final end = RecitationBoundaryService.endOfPage(surah, _fromAyah);
    setState(() {
      _openEnded = false;
      _toAyah = end;
    });
  }

  void _setEndOfCurrentHizb() {
    final surah = _selectedSurah;
    if (surah == null) return;
    final end = RecitationBoundaryService.endOfHizb(surah, _fromAyah);
    setState(() {
      _openEnded = false;
      _toAyah = end;
    });
  }

  Widget _buildSummaryCard() {
    if (_openEnded) {
      return Card(
        color: Colors.teal.shade50,
        child: ListTile(
          leading: const Icon(Icons.play_circle_outline, color: Colors.teal),
          title: Text('يبدأ التسميع من الآية $_fromAyah'),
          subtitle: const Text(
            'لا توجد نهاية مسبقة؛ يعتمد المعلم آخر آية عند التوقف.',
          ),
        ),
      );
    }
    final lines = _quran.calculateLines(_selectedSurahId!, _fromAyah, _toAyah);
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildSummaryItem('الآيات', '${_toAyah - _fromAyah + 1}'),
            _buildSummaryItem('الأسطر', lines.toStringAsFixed(1)),
            _buildSummaryItem('الصفحات', (lines / 15).toStringAsFixed(1)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
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
    final measuredTo = _openEnded && _ayahs.isNotEmpty
        ? _ayahs[_currentAyahIndex].number
        : _toAyah;
    final lines = _quran.calculateLines(
      _selectedSurahId!,
      _fromAyah,
      measuredTo,
    );
    final pages = lines / 15.0;
    final min = (pages * 1.5).round().clamp(1, 999);
    final max = (pages * 2.0).round().clamp(min + 1, 999);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isTimerRunning ? Icons.pause_circle_filled : Icons.play_circle_filled,
                  color: Colors.blue.shade700,
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
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'الوقت المقترح للتسميع',
                style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 2),
              Text(
                '$min - $max دقائق (${pages.toStringAsFixed(1)} صفحة)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Text(
            _openEnded
                ? 'تسميع مفتوح · الآية ${_ayahs[_currentAyahIndex].number}'
                : 'الآية ${_currentAyahIndex + 1} من ${_ayahs.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: _openEnded
                  ? null
                  : (_currentAyahIndex + 1) / _ayahs.length,
              backgroundColor: Colors.grey[300],
            ),
          ),
          const SizedBox(width: 12),
          if (!_openEnded)
            Text(
              '${((_currentAyahIndex + 1) / _ayahs.length * 100).round()}%',
              style: TextStyle(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildAyahCard(Ayah ayah) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'آية ${ayah.number}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  'صفحة ${ayah.page}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_showFullText)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Text(
                  ayah.text,
                  style: const TextStyle(
                    fontSize: 24,
                    fontFamily: 'Amiri',
                    height: 2,
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
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.visibility_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text(
                      'النص مخفي',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'اضغط على أيقونة العين لعرضه',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildInfoChip('الجزء ${ayah.juz}', Icons.book),
                const SizedBox(width: 8),
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
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
        
        final isLast = _currentAyahIndex == _ayahs.length - 1;
        if (!isLast) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted && _currentAyahIndex < _ayahs.length - 1) {
              setState(() {
                _currentAyahIndex++;
              });
            }
          });
        }
      },
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected ? color : Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rating',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
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
              color: isSelected ? color : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final isFirst = _currentAyahIndex == 0;
    final isLast = _currentAyahIndex == _ayahs.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isFirst ? null : () => setState(() => _currentAyahIndex--),
              icon: const Icon(Icons.arrow_back),
              label: const Text('السابق'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      _openEnded
                          ? (isLast ? 'إنهاء السورة هنا' : 'التوقف هنا')
                          : isLast
                              ? 'إنهاء التسميع'
                              : 'التالي',
                    ),
            ),
          ),
        ],
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
    final lastAyah = _ayahs[_currentAyahIndex].number;
    setState(() {
      _toAyah = lastAyah;
      _ayahs = _ayahs.take(_currentAyahIndex + 1).toList();
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
                        color: Colors.grey[300],
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
                    'الطالب: ${widget.student.name} | سورة ${_selectedSurah?.name} ($_fromAyah - $_toAyah)',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
                            label: const Text('حفظ جديد'),
                            selected: !_isRevision,
                            onSelected: (val) {
                              setModalState(() => _isRevision = !val);
                              setState(() => _isRevision = !val);
                            },
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('مراجعة'),
                            selected: _isRevision,
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
                            color: isSelected ? Colors.white : color,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selected: isSelected,
                        selectedColor: color,
                        backgroundColor: color.withOpacity(0.1),
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
                              border: Border.all(color: Colors.grey[300]!),
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSaving ? null : () => Navigator.pop(context),
                          child: const Text('إلغاء'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  Navigator.pop(context); // Close sheet
                                  await _saveRecitation(sendToParent: false);
                                },
                          icon: const Icon(Icons.save),
                          label: const Text('حفظ التقييم'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
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
                      backgroundColor: Colors.amber[800],
                      foregroundColor: Colors.white,
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
    if (!_isRevision && widget.student.totalMemorized >= 6236) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('هذا الطالب أتم حفظ القرآن؛ اختر المراجعة بدل الحفظ الجديد'),
        ),
      );
      return;
    }
    _timer?.cancel();
    setState(() => _isSaving = true);

    try {
      final avgRating = _ayahRatings.values.reduce((a, b) => a + b) ~/ _ayahRatings.length;
      final currentStudent =
          await _db.getStudent(widget.student.id) ?? widget.student;
      final newlyMemorizedAyahs = !_isRevision && _selectedGrade != 'absent'
          ? await _db.countNewMemorizedAyahs(
              student: currentStudent,
              surahId: _selectedSurahId!,
              fromAyah: _fromAyah,
              toAyah: _toAyah,
            )
          : 0;

      // 1. Save MemorizationProgress (for backward compatibility)
      final progress = MemorizationProgress(
        studentId: widget.student.id,
        surahId: _selectedSurahId!,
        fromAyah: _fromAyah,
        toAyah: _toAyah,
        date: DateTime.now(),
        qualityRating: avgRating,
        isRevision: _isRevision,
        notes: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );
      await _db.insertMemorization(progress);

      // 2. Save HomeworkGrade
      final homeworkGrade = HomeworkGrade(
        studentId: widget.student.id,
        surahId: _selectedSurahId!,
        fromAyah: _fromAyah,
        toAyah: _toAyah,
        date: DateTime.now(),
        gradeMark: _selectedGrade,
        mistakesCount: _mistakesCount,
        isRevision: _isRevision,
        remark: _remarkController.text.isNotEmpty ? _remarkController.text : null,
      );
      await _db.insertHomeworkGrade(homeworkGrade);

      // 3. Update MushafProgress using MushafService
      try {
        final mushafService = MushafService();
        await mushafService.updateProgressAfterGrading(homeworkGrade);
      } catch (mushafError) {
        debugPrint('Error updating mushaf progress: $mushafError');
      }

      // 4. Save/Update DailyRecord
      final existingRecord = await _db.getDailyRecord(widget.student.id, DateTime.now());
      final record = (existingRecord ?? DailyRecord(
        studentId: widget.student.id,
        date: DateTime.now(),
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ?? DateTime.now(),
        memorizationDone: !_isRevision ? true : (existingRecord?.memorizationDone ?? false),
        revisionDone: _isRevision ? true : (existingRecord?.revisionDone ?? false),
        memorizationAmount: !_isRevision
            ? (existingRecord?.memorizationAmount ?? 0) + newlyMemorizedAyahs
            : (existingRecord?.memorizationAmount ?? 0),
        revisionAmount: _isRevision
            ? (existingRecord?.revisionAmount ?? 0) + _ayahs.length
            : (existingRecord?.revisionAmount ?? 0),
      );
      await _db.saveDailyRecord(record);

      // 4.b تحديث إجمالي المحفوظ للطالب عند الحفظ الجديد (غير المراجعة)
      // حتى تعمل آلية اكتشاف ختم القرآن وإحصائيات التقدم.
      if (!_isRevision && _selectedGrade != 'absent') {
        final newTotal = currentStudent.totalMemorized + newlyMemorizedAyahs;
        final updatedStudent = currentStudent.copyWith(totalMemorized: newTotal);
        await _db.updateStudent(updatedStudent);
      }

      // 5. Send message to parent if selected
      if (sendToParent) {
        if (sendAsImage) {
          final bytes = await _drawReportCardImage(
            studentName: widget.student.name,
            surahName: _selectedSurah?.name ?? '',
            fromAyah: _fromAyah,
            toAyah: _toAyah,
            grade: _selectedGrade,
            mistakes: _mistakesCount,
            isRevision: _isRevision,
            remark: _remarkController.text,
          );

          final tempDir = await getTemporaryDirectory();
          final file = await File('${tempDir.path}/report_${widget.student.name}.png').create();
          await file.writeAsBytes(bytes);

          await Share.shareXFiles(
            [XFile(file.path)],
            text: 'تقرير تسميع الطالب ${widget.student.name} لليوم',
          );
        } else {
          final template = await _db.getMessageTemplate('grading');
          String templateText = template?.content ?? 
              'السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}';

          String message = templateText
              .replaceAll('{اسم_الطالب}', widget.student.name)
              .replaceAll('{السورة}', _selectedSurah?.name ?? '')
              .replaceAll('{من}', '$_fromAyah')
              .replaceAll('{إلى}', '$_toAyah')
              .replaceAll('{التقييم}', homeworkGrade.gradeMarkArabic)
              .replaceAll('{الأخطاء}', '$_mistakesCount')
              .replaceAll('{الملاحظة}', _remarkController.text.isNotEmpty ? _remarkController.text : 'لا يوجد');

          await Share.share(message);
        }
      }

      // Check for extra memorization bonus points
      bool addedExtraPoints = false;
      int extraPoints = 0;
      const bonusReason = 'زيادة عن المقرر اليومي';
      final exceedsPlan = !_isRevision &&
          _selectedSurah != null &&
          MemorizationMeasureService.exceedsPlan(
            surah: _selectedSurah!,
            fromAyah: _fromAyah,
            toAyah: _toAyah,
            planType: widget.student.planType,
            planAmount: widget.student.planAmount,
          );
      final bonusAlreadyAdded = exceedsPlan &&
          await _db.hasBehaviorPointForDate(
            widget.student.id,
            bonusReason,
            DateTime.now(),
          );
      if (exceedsPlan && !bonusAlreadyAdded) {
        final settings = await _db.getSettings();
        extraPoints = settings.pointsConfig['extra_memorization'] ?? 2;
        if (extraPoints > 0) {
          final point = BehaviorPoint(
            studentId: widget.student.id,
            type: 'positive',
            reason: bonusReason,
            points: extraPoints,
            date: DateTime.now(),
          );
          await _db.insertBehaviorPoint(point);
          addedExtraPoints = true;
        }
      }

      final requiresSurahRevision = !_isRevision &&
          newlyMemorizedAyahs > 0 &&
          _selectedSurah != null &&
          await _db.isSurahFullyMemorized(
            student: currentStudent,
            surahId: _selectedSurahId!,
            totalAyahs: _selectedSurah!.totalAyahs,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              requiresSurahRevision
                  ? 'تم إتمام السورة، وأضيفت تلقائيًا إلى المراجعة الإلزامية'
                  : addedExtraPoints
                      ? 'تم حفظ التقييم بنجاح، وإضافة $extraPoints نقاط مكافأة للزيادة 🎉'
                      : 'تم حفظ التقييم بنجاح',
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

    final paintCircle = Paint()..color = Colors.white.withOpacity(0.03);
    canvas.drawCircle(const Offset(80, 80), 150, paintCircle);
    canvas.drawCircle(const Offset(720, 420), 200, paintCircle);

    final paintCard = Paint()..color = Colors.white;
    final rrectCard = RRect.fromRectAndRadius(
      const Rect.fromLTWH(40, 40, 720, 420),
      const Radius.circular(30),
    );
    canvas.drawRRect(rrectCard, paintCard);

    final paintBorder = Paint()
      ..color = const Color(0xFF14B8A6).withOpacity(0.2)
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

    final dateText = Helpers.formatGregorianDate(DateTime.now());
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
