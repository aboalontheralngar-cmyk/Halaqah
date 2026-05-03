import 'package:flutter/material.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../widgets/surah_picker.dart';

class ExamGeneratorScreen extends StatefulWidget {
  final Student? student;

  const ExamGeneratorScreen({super.key, this.student});

  @override
  State<ExamGeneratorScreen> createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends State<ExamGeneratorScreen> {
  final QuranService _quran = QuranService.instance;
  final DatabaseService _db = DatabaseService();
  
  Student? _selectedStudent;
  List<Student> _students = [];
  List<int> _memorizedSurahs = [];
  int? _selectedSurah;
  int _fromAyah = 1;
  int _toAyah = 1;
  int _questionCount = 5;
  bool _isLoading = true;
  Map<String, dynamic>? _generatedExam;

  @override
  void initState() {
    super.initState();
    _selectedStudent = widget.student;
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      final students = await _db.getStudents(status: 'active');
      setState(() {
        _students = students;
        _isLoading = false;
      });
      if (_selectedStudent != null) {
        _loadMemorizedSurahs();
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMemorizedSurahs() async {
    if (_selectedStudent == null) return;
    try {
      final surahs = await _db.getMemorizedSurahs(_selectedStudent!.id);
      setState(() {
        _memorizedSurahs = surahs;
        if (surahs.isNotEmpty) {
          _selectedSurah = surahs.first;
          _updateAyahRange();
        }
      });
    } catch (e) {}
  }

  void _updateAyahRange() {
    if (_selectedSurah == null) return;
    final surah = _quran.getSurah(_selectedSurah!);
    if (surah != null) {
      setState(() {
        _fromAyah = 1;
        _toAyah = surah.totalAyahs;
      });
    }
  }

  void _generateExam() {
    if (_selectedSurah == null) return;
    
    final exam = _quran.generateExamRange(
      surahNumber: _selectedSurah!,
      fromAyah: _fromAyah,
      toAyah: _toAyah,
      questionCount: _questionCount,
    );
    
    setState(() => _generatedExam = exam);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مولد نماذج الاختبارات'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStudentSelector(),
                  const SizedBox(height: 16),
                  if (_memorizedSurahs.isNotEmpty) ...[
                    _buildSurahSelector(),
                    const SizedBox(height: 16),
                    _buildAyahRange(),
                    const SizedBox(height: 16),
                    _buildQuestionCount(),
                    const SizedBox(height: 24),
                    _buildGenerateButton(),
                  ],
                  if (_generatedExam != null) ...[
                    const SizedBox(height: 24),
                    _buildExamPreview(),
                  ],
                ],
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
            const Text('اختر الطالب', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<Student>(
              value: _selectedStudent,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              hint: const Text('اختر طالباً'),
              items: _students.map((student) {
                return DropdownMenuItem(value: student, child: Text(student.name));
              }).toList(),
              onChanged: (student) {
                setState(() {
                  _selectedStudent = student;
                  _selectedSurah = null;
                  _memorizedSurahs = [];
                  _generatedExam = null;
                });
                _loadMemorizedSurahs();
              },
            ),
          ],
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
            const Text('اختر السورة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final surahId = await showSurahPicker(
                  context,
                  selectedSurahId: _selectedSurah,
                  allowedSurahIds: _memorizedSurahs,
                  title: 'اختر سورة من المحفوظ',
                );
                if (surahId != null) {
                  setState(() {
                    _selectedSurah = surahId;
                    _generatedExam = null;
                  });
                  _updateAyahRange();
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
                      child: Text(
                        _selectedSurah != null
                            ? 'سورة ${_quran.getSurahName(_selectedSurah!)}'
                            : 'اختر السورة',
                        style: TextStyle(
                          fontWeight: _selectedSurah != null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
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

  Widget _buildAyahRange() {
    if (_selectedSurah == null) return const SizedBox();
    final surah = _quran.getSurah(_selectedSurah!);
    if (surah == null) return const SizedBox();

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
                Text(
                  '${_toAyah - _fromAyah + 1} آية',
                  style: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(_fromAyah.toDouble(), _toAyah.toDouble()),
              min: 1,
              max: surah.totalAyahs.toDouble(),
              divisions: surah.totalAyahs > 1 ? surah.totalAyahs - 1 : 1,
              labels: RangeLabels('آية $_fromAyah', 'آية $_toAyah'),
              onChanged: (values) {
                setState(() {
                  _fromAyah = values.start.round();
                  _toAyah = values.end.round();
                  _generatedExam = null;
                });
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('من: $_fromAyah'),
                Text('إلى: $_toAyah'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'عدد الأسطر: ${_quran.calculateLines(_selectedSurah!, _fromAyah, _toAyah).toStringAsFixed(1)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCount() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('عدد الأسئلة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                for (int count in [3, 5, 7, 10])
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text('$count'),
                        selected: _questionCount == count,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _questionCount = count;
                              _generatedExam = null;
                            });
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _generateExam,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('توليد نموذج الاختبار'),
      ),
    );
  }

  Widget _buildExamPreview() {
    final exam = _generatedExam!;
    final questions = exam['questions'] as List;

    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'نموذج الاختبار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _generateExam,
                  tooltip: 'توليد نموذج جديد',
                ),
              ],
            ),
            Text(
              '${exam['surah']} - الآيات ${exam['range']}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            Text(
              'إجمالي الأسطر: ${(exam['total_lines'] as double).toStringAsFixed(1)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 24),
            const Text(
              'أكمل الآيات التالية:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _buildQuestion(index + 1, question);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestion(int number, Map<String, dynamic> question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: Theme.of(context).primaryColor,
                child: Text(
                  '$number',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'الآية ${question['ayah_number']}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${question['start_text']} ...',
            style: const TextStyle(
              fontSize: 18,
              fontFamily: 'Amiri',
              fontWeight: FontWeight.w500,
            ),
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('عرض الإجابة', style: TextStyle(fontSize: 12)),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 8),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  question['full_text'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: 'Amiri',
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
