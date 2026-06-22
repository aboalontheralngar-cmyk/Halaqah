import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/quran_service.dart';
import '../../models/student.dart';
import '../../models/memorization.dart';
import '../../models/daily_record.dart';
import '../../models/behavior_point.dart';
import '../../models/settings.dart';
import '../../utils/quran_data.dart';
import '../../widgets/surah_picker.dart';
import '../../widgets/ayah_range_picker.dart';
import '../../widgets/quality_rating.dart';

class AddMemorizationScreen extends StatefulWidget {
  final Student? student;

  const AddMemorizationScreen({super.key, this.student});

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

  HalaqahSettings _settings = HalaqahSettings();

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      await _quran.initialize();
      final students = await _db.getStudents(status: 'active');
      final settings = await _db.getSettings();
      setState(() {
        _students = students;
        _settings = settings;
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
          setState(() {
            _selectedSurahId = startPoint['surahId'];
            _fromAyah = startPoint['fromAyah']!;
            _toAyah = startPoint['toAyah']!;
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

  Map<String, dynamic>? get _selectedSurah {
    if (_selectedSurahId == null) return null;
    return QuranData.surahs.firstWhere(
      (s) => s['id'] == _selectedSurahId,
      orElse: () => {},
    );
  }

  int get _ayahCount => _toAyah - _fromAyah + 1;
  double get _estimatedLines {
    if (_selectedSurahId == null) return 0;
    return _quran.calculateLines(_selectedSurahId!, _fromAyah, _toAyah);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل حفظ جديد'),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.student == null) _buildStudentSelector(),
                    if (_selectedStudent != null) ...[
                      _buildStudentInfo(),
                      const SizedBox(height: 16),
                    ],
                    _buildSurahSelector(),
                    if (_selectedSurahId != null) ...[
                      const SizedBox(height: 16),
                      _buildAyahRangePicker(),
                      const SizedBox(height: 16),
                      _buildEstimatedLines(),
                    ],
                    const SizedBox(height: 24),
                    _buildQualityRating(),
                    const SizedBox(height: 16),
                    _buildNotesField(),
                    const SizedBox(height: 24),
                    _buildSaveButton(),
                  ],
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
              value: _selectedStudent,
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
                setState(() {
                  _selectedStudent = student;
                  _selectedSurahId = null;
                });
                if (student != null) {
                  final startPoint = await _getNextMemorizationStartingPoint(student);
                  if (startPoint != null && _selectedStudent?.id == student.id) {
                    setState(() {
                      _selectedSurahId = startPoint['surahId'];
                      _fromAyah = startPoint['fromAyah']!;
                      _toAyah = startPoint['toAyah']!;
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
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).primaryColor,
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '؟',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          'المقرر: ${student.planAmount} ${_getPlanLabel(student.planType)} | الحفظ: ${student.totalMemorized} آية',
        ),
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
            const Text(
              'اختر السورة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _selectSurah,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
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
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            )
                          : Text(
                              'اضغط لاختيار السورة',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
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
            });
          },
        ),
      ),
    );
  }

  Widget _buildEstimatedLines() {
    final lines = _estimatedLines;
    final pages = lines / 15.0;
    return Card(
      color: Colors.blue.withOpacity(0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: Colors.blue),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'التقدير',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '$_ayahCount آية ≈ ${lines.toStringAsFixed(1)} سطر (${pages.toStringAsFixed(1)} صفحة)',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
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
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveMemorization,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('حفظ التسجيل'),
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

    setState(() => _isSaving = true);

    try {
      final progress = MemorizationProgress(
        studentId: _selectedStudent!.id,
        surahId: _selectedSurahId!,
        fromAyah: _fromAyah,
        toAyah: _toAyah,
        date: DateTime.now(),
        qualityRating: _qualityRating,
        isRevision: false,
        notes: _notes.isEmpty ? null : _notes,
      );

      await _db.insertMemorization(progress);

      final existingRecord = await _db.getDailyRecord(
        _selectedStudent!.id,
        DateTime.now(),
      );

      final record = (existingRecord ?? DailyRecord(
        studentId: _selectedStudent!.id,
        date: DateTime.now(),
      )).copyWith(
        attendance: 'present',
        arrivalTime: existingRecord?.arrivalTime ?? DateTime.now(),
        memorizationDone: true,
        memorizationAmount: _ayahCount,
        memorizationNote: _notes.isEmpty ? null : _notes,
      );

      await _db.saveDailyRecord(record);

      final updatedStudent = _selectedStudent!.copyWith(
        totalMemorized: _selectedStudent!.totalMemorized + _ayahCount,
      );
      await _db.updateStudent(updatedStudent);

      bool addedExtraPoints = false;
      int extraPoints = 0;
      if (_selectedStudent!.planType == 'ayahs' && _ayahCount > _selectedStudent!.planAmount) {
        extraPoints = _settings.pointsConfig['extra_memorization'] ?? 2;
        if (extraPoints > 0) {
          final point = BehaviorPoint(
            studentId: _selectedStudent!.id,
            type: 'positive',
            reason: 'زيادة عن المقرر اليومي',
            points: extraPoints,
            date: DateTime.now(),
          );
          await _db.insertBehaviorPoint(point);
          addedExtraPoints = true;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(addedExtraPoints
                ? 'تم حفظ التسجيل بنجاح، وإضافة $extraPoints نقاط مكافأة للزيادة 🎉'
                : 'تم حفظ التسجيل بنجاح'),
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

  int _calculateToAyah({
    required Surah surah,
    required int fromAyah,
    required String planType,
    required int planAmount,
  }) {
    if (planType == 'ayahs') {
      return (fromAyah + planAmount - 1).clamp(1, surah.totalAyahs);
    }
    
    if (planType == 'pages') {
      final startAyahObj = surah.getAyah(fromAyah);
      if (startAyahObj == null) return surah.totalAyahs;
      final startPage = startAyahObj.page;
      final targetEndPage = startPage + planAmount - 1;
      
      int targetToAyah = fromAyah;
      for (int i = fromAyah; i <= surah.totalAyahs; i++) {
        final a = surah.getAyah(i);
        if (a != null && a.page <= targetEndPage) {
          targetToAyah = i;
        } else {
          break;
        }
      }
      return targetToAyah;
    }
    
    if (planType == 'lines') {
      double linesSum = 0;
      int targetToAyah = fromAyah;
      for (int i = fromAyah; i <= surah.totalAyahs; i++) {
        final a = surah.getAyah(i);
        if (a != null) {
          linesSum += a.lines;
          targetToAyah = i;
          if (linesSum >= planAmount) {
            break;
          }
        }
      }
      return targetToAyah;
    }
    
    return surah.totalAyahs;
  }

  Future<Map<String, int>?> _getNextMemorizationStartingPoint(Student student) async {
    final allProgress = await _db.getStudentMemorization(student.id);
    final memorizations = allProgress.where((p) => !p.isRevision).toList();

    if (memorizations.isNotEmpty) {
      memorizations.sort((a, b) => b.date.compareTo(a.date));
      final last = memorizations.first;
      final surah = _quran.getSurah(last.surahId);
      if (surah != null) {
        if (last.toAyah < surah.totalAyahs) {
          final nextFrom = last.toAyah + 1;
          return {
            'surahId': last.surahId,
            'fromAyah': nextFrom,
            'toAyah': _calculateToAyah(
              surah: surah,
              fromAyah: nextFrom,
              planType: student.planType,
              planAmount: student.planAmount,
            ),
          };
        } else {
          int nextSurahId = student.memorizationDirection == 'desc' 
              ? last.surahId - 1 
              : last.surahId + 1;
          
          if (nextSurahId >= 1 && nextSurahId <= 114) {
            final nextSurah = _quran.getSurah(nextSurahId);
            if (nextSurah != null) {
              return {
                'surahId': nextSurahId,
                'fromAyah': 1,
                'toAyah': _calculateToAyah(
                  surah: nextSurah,
                  fromAyah: 1,
                  planType: student.planType,
                  planAmount: student.planAmount,
                ),
              };
            }
          }
        }
      }
    }

    if (student.preMemorizedEndSurah != null) {
      int nextSurahId = student.preMemorizedEndSurah!;
      int nextFromAyah = (student.preMemorizedEndAyah ?? 1) + 1;
      final currentSurah = _quran.getSurah(nextSurahId);
      
      if (currentSurah != null && nextFromAyah <= currentSurah.totalAyahs) {
        return {
          'surahId': nextSurahId,
          'fromAyah': nextFromAyah,
          'toAyah': _calculateToAyah(
            surah: currentSurah,
            fromAyah: nextFromAyah,
            planType: student.planType,
            planAmount: student.planAmount,
          ),
        };
      } else {
        nextSurahId = student.memorizationDirection == 'desc'
            ? student.preMemorizedEndSurah! - 1
            : student.preMemorizedEndSurah! + 1;
            
        if (nextSurahId >= 1 && nextSurahId <= 114) {
          final nextSurah = _quran.getSurah(nextSurahId);
          if (nextSurah != null) {
            return {
              'surahId': nextSurahId,
              'fromAyah': 1,
              'toAyah': _calculateToAyah(
                surah: nextSurah,
                fromAyah: 1,
                planType: student.planType,
                planAmount: student.planAmount,
              ),
            };
          }
        }
      }
    }

    int defaultSurahId = student.memorizationDirection == 'desc' ? 114 : 1;
    final defaultSurah = _quran.getSurah(defaultSurahId);
    if (defaultSurah != null) {
      return {
        'surahId': defaultSurahId,
        'fromAyah': 1,
        'toAyah': _calculateToAyah(
          surah: defaultSurah,
          fromAyah: 1,
          planType: student.planType,
          planAmount: student.planAmount,
        ),
      };
    }
    return null;
  }

  String _getPlanLabel(String planType) {
    switch (planType) {
      case 'ayahs':
        return 'آية';
      case 'lines':
        return 'سطر';
      case 'pages':
        return 'صفحة';
      default:
        return planType;
    }
  }
}
