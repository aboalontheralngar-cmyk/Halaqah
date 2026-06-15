import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart';
import '../../services/mushaf_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/ayah.dart';
import '../../models/homework_grade.dart';
import '../../widgets/surah_picker.dart';

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

  // New Grading State Fields
  bool _isRevision = false;
  String _selectedGrade = 'good';
  int _mistakesCount = 0;
  final TextEditingController _remarkController = TextEditingController();

  Surah? get _selectedSurah => _selectedSurahId != null 
      ? _quran.getSurah(_selectedSurahId!) 
      : null;

  @override
  void dispose() {
    _remarkController.dispose();
    super.dispose();
  }

  void _loadAyahs() {
    if (_selectedSurahId == null) return;
    final ayahs = _quran.getAyahRange(_selectedSurahId!, _fromAyah, _toAyah);
    setState(() {
      _ayahs = ayahs;
      _currentAyahIndex = 0;
      _ayahRatings = {};
      _mistakesCount = 0;
      _selectedGrade = 'good';
      _remarkController.clear();
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
      body: _ayahs.isEmpty ? _buildSetupView() : _buildRecitationView(),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('نطاق الآيات', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('${_toAyah - _fromAyah + 1} آية', style: const TextStyle(color: Colors.blue)),
              ],
            ),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(_fromAyah.toDouble(), _toAyah.toDouble()),
              min: 1,
              max: maxAyahs.toDouble(),
              divisions: maxAyahs > 1 ? maxAyahs - 1 : 1,
              labels: RangeLabels('$_fromAyah', '$_toAyah'),
              onChanged: (values) {
                setState(() {
                  _fromAyah = values.start.round();
                  _toAyah = values.end.round();
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('من: $_fromAyah', style: TextStyle(color: Colors.grey[600])),
                Text('إلى: $_toAyah', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
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
        label: const Text('بدء التسميع'),
      ),
    );
  }

  Widget _buildRecitationView() {
    final currentAyah = _ayahs[_currentAyahIndex];
    return Column(
      children: [
        _buildProgressBar(),
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

  Widget _buildProgressBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: Row(
        children: [
          Text(
            'الآية ${_currentAyahIndex + 1} من ${_ayahs.length}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: LinearProgressIndicator(
              value: (_currentAyahIndex + 1) / _ayahs.length,
              backgroundColor: Colors.grey[300],
            ),
          ),
          const SizedBox(width: 12),
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
        setState(() => _ayahRatings[_currentAyahIndex] = rating);
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
        color: Colors.white,
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
              onPressed: isLast ? (_isSaving ? null : _showGradingSheet) : _goToNext,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(isLast ? 'إنهاء التسميع' : 'التالي'),
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
                    label: const Text('حفظ وإرسال لولي الأمر'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveRecitation({bool sendToParent = false}) async {
    setState(() => _isSaving = true);

    try {
      final avgRating = _ayahRatings.values.reduce((a, b) => a + b) ~/ _ayahRatings.length;

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
        memorizationDone: !_isRevision ? true : (existingRecord?.memorizationDone ?? false),
        revisionDone: _isRevision ? true : (existingRecord?.revisionDone ?? false),
        memorizationAmount: !_isRevision ? _ayahs.length : (existingRecord?.memorizationAmount ?? 0),
        revisionAmount: _isRevision ? _ayahs.length : (existingRecord?.revisionAmount ?? 0),
      );
      await _db.saveDailyRecord(record);

      // 5. Send message to parent if selected
      if (sendToParent) {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التقييم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
