import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/quran_service.dart';
import '../../services/mushaf_service.dart';
import '../../models/student.dart';
import '../../models/mushaf_progress.dart';
import '../../models/ayah.dart';
import '../../utils/helpers.dart';

class MushafVisualizerScreen extends StatefulWidget {
  final Student student;

  const MushafVisualizerScreen({super.key, required this.student});

  @override
  State<MushafVisualizerScreen> createState() => _MushafVisualizerScreenState();
}

class _MushafVisualizerScreenState extends State<MushafVisualizerScreen> {
  final DatabaseService _db = DatabaseService();
  final MushafService _mushafService = MushafService();
  final QuranService _quran = QuranService.instance;

  List<MushafProgress> _progressList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getStudentMushafProgress(widget.student.id);
      setState(() {
        _progressList = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل البيانات: $e')),
        );
      }
    }
  }

  MushafProgress? _getProgress(int hizb, int thumun) {
    try {
      return _progressList.firstWhere(
        (p) => p.hizbNumber == hizb && p.thumunNumber == thumun,
      );
    } catch (_) {
      return null;
    }
  }

  // Helper translations for UI representation
  String getGradeArabic(double grade) {
    if (grade >= 4.5) return 'ممتاز';
    if (grade >= 3.5) return 'جيد جداً';
    if (grade >= 2.5) return 'جيد';
    if (grade >= 1.5) return 'يحتاج تركيز';
    return 'لم يتم التقييم';
  }

  Map<String, dynamic> _getThumunRange(int hizb, int thumun) {
    final quarterInHizb = ((thumun - 1) ~/ 2) + 1;
    
    List<Ayah> matchingAyahs = [];
    for (final surah in _quran.surahs) {
      for (final ayah in surah.ayahs) {
        if (ayah.hizb == hizb && ((ayah.quarter - 1) % 4) + 1 == quarterInHizb) {
          matchingAyahs.add(ayah);
        }
      }
    }

    if (matchingAyahs.isEmpty) return {'text': 'غير محدد'};

    final first = matchingAyahs.first;
    final last = matchingAyahs.last;
    final firstSurahName = _quran.getSurahName(first.surahNumber);
    final lastSurahName = _quran.getSurahName(last.surahNumber);

    if (first.surahNumber == last.surahNumber) {
      return {
        'text': 'سورة $firstSurahName (${first.number} - ${last.number})',
        'surahId': first.surahNumber,
        'fromAyah': first.number,
        'toAyah': last.number,
      };
    } else {
      return {
        'text': 'من $firstSurahName (${first.number}) إلى $lastSurahName (${last.number})',
        'surahId': first.surahNumber,
        'fromAyah': first.number,
        'toAyah': last.number,
      };
    }
  }

  Color _getCellColor(MushafProgress? p) {
    if (p == null) return Colors.grey.shade300;
    if (p.lastGradedDate == null) {
      return p.isPreMemorized ? Colors.green.shade400 : Colors.grey.shade300;
    }

    // Decay logic
    final days = DateTime.now().difference(p.lastGradedDate!).inDays;
    if (days < 14) {
      return Colors.green.shade600;
    } else if (days <= 30) {
      return Colors.amber.shade600;
    } else {
      return Colors.red.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final memorizedCount = _progressList.where((p) => p.lastGradedDate != null || p.isPreMemorized).length;
    final percent = (memorizedCount / 480 * 100);

    final freshCount = _progressList.where((p) => p.decayStatus == DecayStatus.fresh).length;
    final agingCount = _progressList.where((p) => p.decayStatus == DecayStatus.aging).length;
    final staleCount = _progressList.where((p) => p.decayStatus == DecayStatus.stale).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('خريطة المصحف التفاعلية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProgress,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeaderStats(memorizedCount, percent, freshCount, agingCount, staleCount),
                _buildLegend(),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: 60,
                    itemBuilder: (context, index) {
                      final hizb = index + 1;
                      return _buildHizbRow(hizb);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderStats(int count, double percent, int fresh, int aging, int stale) {
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إجمالي المحفوظ',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count من 480 ثُمن',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${percent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: count / 480,
              backgroundColor: Colors.grey[200],
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatBadge('حديث ($fresh)', Colors.green.shade600),
                _buildStatBadge('متوسط ($aging)', Colors.amber.shade600),
                _buildStatBadge('ضعيف ($stale)', Colors.red.shade600),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('1 → 8 أثمان الحزب (من اليمين لليسار)', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHizbRow(int hizb) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 65,
            child: Text(
              'الحزب $hizb',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(8, (thIndex) {
                final thumun = thIndex + 1;
                final p = _getProgress(hizb, thumun);
                final cellColor = _getCellColor(p);
                return Expanded(
                  child: InkWell(
                    onTap: () => _showThumunDetails(hizb, thumun, p),
                    child: Container(
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: cellColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: p != null ? Colors.transparent : Colors.grey.shade200,
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$thumun',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: p != null ? Colors.white : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showThumunDetails(int hizb, int thumun, MushafProgress? p) {
    final rangeInfo = _getThumunRange(hizb, thumun);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final currentP = p;
            final isSaved = currentP != null && (currentP.lastGradedDate != null || currentP.isPreMemorized);
            final displayColor = _getCellColor(currentP);
            
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(color: displayColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'الحزب $hizb | الثمن $thumun',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('الآيات التي يغطيها الثمن:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(
                    rangeInfo['text'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Divider(height: 32),
                  if (currentP != null && currentP.lastGradedDate != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('آخر تقييم:'),
                        Text(
                          getGradeArabic(currentP.averageGrade),
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('تاريخ التقييم:'),
                        Text(Helpers.formatHijriDate(currentP.lastGradedDate!)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الدرجة الرقمية:'),
                        Text(currentP.averageGrade.toStringAsFixed(1)),
                      ],
                    ),
                  ] else ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('لم يتم تسميعه وتقييمه في الحلقة بعد', style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('محفوظ مسبقاً (دون تقييم)'),
                    subtitle: const Text('ضع علامة حفظ إذا حفظه الطالب قبل الانضمام للحلقة'),
                    value: currentP?.isPreMemorized ?? false,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (val) async {
                      await _mushafService.togglePreMemorized(widget.student.id, hizb, thumun, val);
                      final updatedList = await _db.getStudentMushafProgress(widget.student.id);
                      setModalState(() {
                        p = updatedList.firstWhere((item) => item.hizbNumber == hizb && item.thumunNumber == thumun);
                      });
                      setState(() {
                        _progressList = updatedList;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إغلاق'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
