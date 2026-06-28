import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/student.dart';
import '../../models/exam.dart';
import '../../models/behavior_point.dart';
import '../../utils/quran_data.dart';
import '../../widgets/surah_picker.dart';

class AddExamScreen extends StatefulWidget {
  final Student? student;

  const AddExamScreen({super.key, this.student});

  @override
  State<AddExamScreen> createState() => _AddExamScreenState();
}

class _AddExamScreenState extends State<AddExamScreen> {
  final DatabaseService _db = DatabaseService();
  final _formKey = GlobalKey<FormState>();

  Student? _selectedStudent;
  List<Student> _students = [];
  List<int> _memorizedSurahs = [];
  String _examType = 'oral';
  int? _fromSurahId;
  int? _toSurahId;
  int _score = 0;
  String _notes = '';
  bool _isLoading = true;
  bool _isSaving = false;

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
          _fromSurahId = surahs.first;
          _toSurahId = surahs.last;
        }
      });
    } catch (e) {
      // Ignore error
    }
  }

  String get _scoreLabel {
    if (_score >= 90) return 'ممتاز';
    if (_score >= 80) return 'جيد جداً';
    if (_score >= 70) return 'جيد';
    if (_score >= 60) return 'مقبول';
    return 'ضعيف';
  }

  Color get _scoreColor {
    if (_score >= 90) return Colors.green;
    if (_score >= 75) return Colors.lightGreen;
    if (_score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء امتحان جديد'),
      ),
      body: _isLoading
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
                  _buildExamTypeSelector(),
                  const SizedBox(height: 16),
                  if (_selectedStudent != null) _buildSurahRange(),
                  const SizedBox(height: 16),
                  _buildScoreSlider(),
                  const SizedBox(height: 16),
                  _buildNotesField(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
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
                  _fromSurahId = null;
                  _toSurahId = null;
                  _memorizedSurahs = [];
                });
                _loadMemorizedSurahs();
              },
              validator: (value) => value == null ? 'يرجى اختيار طالب' : null,
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
        subtitle: Text('الحفظ: ${student.totalMemorized} آية | محفوظ: ${_memorizedSurahs.length} سورة'),
      ),
    );
  }

  Widget _buildExamTypeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نوع الامتحان', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'oral',
                    groupValue: _examType,
                    title: const Text('شفهي'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() => _examType = value!),
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'written',
                    groupValue: _examType,
                    title: const Text('تحريري'),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) => setState(() => _examType = value!),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSurahRange() {
    final noMemorization = _memorizedSurahs.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('نطاق الامتحان', style: TextStyle(fontWeight: FontWeight.bold)),
            if (noMemorization) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700], size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'لا يوجد حفظ مسجل لهذا الطالب — يمكنك اختيار أي سورة لإجراء الامتحان.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSurahButton('من سورة', _fromSurahId, (id) {
                    setState(() => _fromSurahId = id);
                  }),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSurahButton('إلى سورة', _toSurahId, (id) {
                    setState(() => _toSurahId = id);
                  }),
                ),
              ],
            ),
            if (_fromSurahId != null && _toSurahId != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.menu_book, color: Colors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      _fromSurahId == _toSurahId
                          ? 'سورة ${QuranData.getSurahName(_fromSurahId!)}'
                          : 'من ${QuranData.getSurahName(_fromSurahId!)} إلى ${QuranData.getSurahName(_toSurahId!)}',
                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSurahButton(String label, int? selectedId, Function(int) onSelected) {
    final surahName = selectedId != null ? QuranData.getSurahName(selectedId) : null;
    
    return InkWell(
      onTap: () async {
        final id = await showSurahPicker(
          context,
          selectedSurahId: selectedId,
          // إن لم يكن لدى الطالب حفظ مسجل، نسمح باختيار أي سورة (allowedSurahIds = null)
          allowedSurahIds: _memorizedSurahs.isEmpty ? null : _memorizedSurahs,
          title: label,
        );
        if (id != null) {
          onSelected(id);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              surahName ?? 'اختر السورة',
              style: TextStyle(
                fontWeight: surahName != null ? FontWeight.bold : FontWeight.normal,
                color: surahName != null ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreSlider() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('النتيجة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _scoreColor.withOpacity(0.1),
                  border: Border.all(color: _scoreColor, width: 4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_score',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: _scoreColor,
                      ),
                    ),
                    Text(
                      _scoreLabel,
                      style: TextStyle(
                        color: _scoreColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Slider(
              value: _score.toDouble(),
              min: 0,
              max: 100,
              divisions: 20,
              label: '$_score%',
              activeColor: _scoreColor,
              onChanged: (value) {
                setState(() => _score = value.round());
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('0%', style: TextStyle(color: Colors.grey[600])),
                Text('100%', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ],
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
            const Text('ملاحظات وتوصيات', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextFormField(
              decoration: const InputDecoration(
                hintText: 'أضف ملاحظات أو توصيات للطالب...',
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
        onPressed: _isSaving ? null : _saveExam,
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text('حفظ الامتحان'),
      ),
    );
  }

  Future<void> _saveExam() async {
    if (_selectedStudent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار طالب')),
      );
      return;
    }

    if (_fromSurahId == null || _toSurahId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تحديد نطاق الامتحان')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final exam = Exam(
        studentId: _selectedStudent!.id,
        date: DateTime.now(),
        type: _examType,
        fromSurah: _fromSurahId!,
        toSurah: _toSurahId!,
        score: _score,
        notes: _notes.isEmpty ? null : _notes,
      );

      await _db.insertExam(exam);

      if (_score >= 60) {
        final point = BehaviorPoint(
          studentId: _selectedStudent!.id,
          type: 'positive',
          reason: 'نجاح في الامتحان الشهري',
          points: 10,
          date: DateTime.now(),
        );
        await _db.insertBehaviorPoint(point);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ الامتحان بنجاح'),
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
