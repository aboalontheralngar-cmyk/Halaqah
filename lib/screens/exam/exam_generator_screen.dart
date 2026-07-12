import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../services/quran_service.dart';
import '../../services/database_service.dart';
import '../../services/exam_question_generator_service.dart';
import '../../services/pdf_service.dart';
import '../../models/student.dart';
import '../../models/exam_template.dart';
import '../../widgets/surah_picker.dart';
import '../../widgets/ayah_range_picker.dart';

class ExamGeneratorScreen extends StatefulWidget {
  final Student? student;
  final ExamTemplate? template;

  const ExamGeneratorScreen({super.key, this.student, this.template});

  @override
  State<ExamGeneratorScreen> createState() => _ExamGeneratorScreenState();
}

class _ExamGeneratorScreenState extends State<ExamGeneratorScreen> {
  final QuranService _quran = QuranService.instance;
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  
  Student? _selectedStudent;
  List<Student> _students = [];
  List<int> _memorizedSurahs = [];
  int? _selectedSurah;
  int _fromAyah = 1;
  int _toAyah = 1;
  int _questionCount = 5;
  String _category = 'memorized';
  int _fromJuz = 1;
  int _toJuz = 30;
  int _fromHizb = 1;
  int _toHizb = 60;
  int _difficulty = 0;
  double _linesPerQuestion = 3;
  bool _preventDuplicates = true;
  final Set<String> _usedQuestionKeys = {};
  String? _savedTemplateId;
  String? _savedTemplateTitle;
  DateTime? _savedTemplateCreatedAt;
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
      final allStudents = await _db.getStudents();
      final selectedId = widget.student?.id ?? widget.template?.studentId;
      final students = allStudents
          .where(
            (student) => student.status == 'active' || student.id == selectedId,
          )
          .toList();
      Student? templateStudent;
      if (widget.template != null) {
        for (final student in students) {
          if (student.id == widget.template!.studentId) {
            templateStudent = student;
            break;
          }
        }
      }
      setState(() {
        _students = students;
        _selectedStudent ??= templateStudent;
        _isLoading = false;
      });
      if (_selectedStudent != null) {
        await _loadMemorizedSurahs();
      }
      if (widget.template != null) {
        await _loadTemplate(widget.template!);
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
        if (surahs.isNotEmpty && _selectedSurah == null) {
          _selectedSurah = surahs.first;
          _updateAyahRange();
        }
      });
    } catch (e) {}
  }

  Future<void> _loadTemplate(ExamTemplate template) async {
    final rows = await _db.getExamTemplateQuestions(template.id);
    dynamic decoded;
    try {
      decoded = jsonDecode(template.criteriaJson);
    } catch (_) {
      decoded = <String, dynamic>{};
    }
    final criteria = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (!mounted) return;
    setState(() {
      _savedTemplateId = template.id;
      _savedTemplateTitle = template.title;
      _savedTemplateCreatedAt = template.createdAt;
      _category = criteria['category'] as String? ?? template.category;
      _fromJuz = criteria['fromJuz'] as int? ?? 1;
      _toJuz = criteria['toJuz'] as int? ?? 30;
      _fromHizb = criteria['fromHizb'] as int? ?? 1;
      _toHizb = criteria['toHizb'] as int? ?? 60;
      _selectedSurah = criteria['surahId'] as int?;
      _fromAyah = criteria['fromAyah'] as int? ?? 1;
      _toAyah = criteria['toAyah'] as int? ?? 1;
      _difficulty = criteria['difficulty'] as int? ?? 0;
      _linesPerQuestion =
          (criteria['linesPerQuestion'] as num?)?.toDouble() ?? 3;
      _preventDuplicates = criteria['preventDuplicates'] as bool? ?? true;
      _questionCount = rows.length;
      final questions = rows.map((row) => <String, dynamic>{
        'key': '${row.surahId}:${row.fromAyah}',
        'surah_id': row.surahId,
        'surah_name': _quran.getSurahName(row.surahId),
        'ayah_number': row.fromAyah,
        'to_ayah': row.toAyah,
        'page': row.page,
        'juz': row.juz,
        'hizb': row.hizb,
        'difficulty': row.difficulty,
        'question_type': row.questionType,
        'start_text': row.promptText,
        'full_text': row.answerText,
        'lines': row.lines,
      }).toList();
      _generatedExam = {
        'category': _categoryLabel,
        'questions': questions,
        'total_lines': questions.fold<double>(
          0,
          (sum, question) => sum + (question['lines'] as num).toDouble(),
        ),
      };
      _usedQuestionKeys
        ..clear()
        ..addAll(questions.map((question) => question['key'] as String));
    });
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
    if (_category == 'surah' && _selectedSurah == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر السورة أولاً')),
      );
      return;
    }
    if (_category == 'memorized' && _memorizedSurahs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد محفوظ مسجل؛ اختر الجزء أو الحزب أو السورة'),
        ),
      );
      return;
    }
    final questions = ExamQuestionGeneratorService.generate(
      surahs: _quran.surahs,
      category: _category,
      allowedSurahIds: _memorizedSurahs.toSet(),
      selectedSurahId: _selectedSurah,
      fromAyah: _fromAyah,
      toAyah: _toAyah,
      fromJuz: _fromJuz,
      toJuz: _toJuz,
      fromHizb: _fromHizb,
      toHizb: _toHizb,
      difficulty: _difficulty,
      questionCount: _questionCount,
      approximateLines: _linesPerQuestion,
      excludedQuestionKeys:
          _preventDuplicates ? _usedQuestionKeys : const {},
    );
    if (questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد آيات مطابقة للمعايير، غيّر النطاق أو الصعوبة'),
        ),
      );
      return;
    }
    setState(() {
      if (_preventDuplicates) {
        _usedQuestionKeys.addAll(
          questions.map((question) => question['key'] as String),
        );
      }
      _generatedExam = {
        'category': _categoryLabel,
        'questions': questions,
        'total_lines': questions.fold<double>(
          0,
          (sum, question) => sum + (question['lines'] as double),
        ),
      };
      _savedTemplateId = null;
      _savedTemplateTitle = null;
      _savedTemplateCreatedAt = null;
    });
  }

  String get _categoryLabel {
    switch (_category) {
      case 'juz':
        return 'الأجزاء من $_fromJuz إلى $_toJuz';
      case 'hizb':
        return 'الأحزاب من $_fromHizb إلى $_toHizb';
      case 'surah':
        return _selectedSurah == null
            ? 'سورة محددة'
            : 'سورة ${_quran.getSurahName(_selectedSurah!)}';
      default:
        return 'محفوظ الطالب';
    }
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
                  if (_selectedStudent != null) ...[
                    _buildCategorySelector(),
                    const SizedBox(height: 16),
                    _buildCategoryCriteria(),
                    const SizedBox(height: 16),
                    _buildQuestionCount(),
                    const SizedBox(height: 16),
                    _buildGenerationOptions(),
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
                  _usedQuestionKeys.clear();
                });
                _loadMemorizedSurahs();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    const categories = <String, String>{
      'memorized': 'محفوظ الطالب',
      'juz': 'حسب الجزء',
      'hizb': 'حسب الحزب',
      'surah': 'حسب السورة',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('فئة الأسئلة', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _category == entry.key,
                  onSelected: (_) {
                    setState(() {
                      _category = entry.key;
                      _generatedExam = null;
                      _usedQuestionKeys.clear();
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCriteria() {
    if (_category == 'surah') {
      return Column(
        children: [
          _buildSurahSelector(),
          const SizedBox(height: 16),
          _buildAyahRange(),
        ],
      );
    }
    if (_category == 'juz') {
      return _buildNumericRangeCard(
        title: 'نطاق الأجزاء',
        max: 30,
        from: _fromJuz,
        to: _toJuz,
        onChanged: (from, to) {
          setState(() {
            _fromJuz = from;
            _toJuz = to;
            _generatedExam = null;
          });
        },
      );
    }
    if (_category == 'hizb') {
      return _buildNumericRangeCard(
        title: 'نطاق الأحزاب',
        max: 60,
        from: _fromHizb,
        to: _toHizb,
        onChanged: (from, to) {
          setState(() {
            _fromHizb = from;
            _toHizb = to;
            _generatedExam = null;
          });
        },
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.verified, color: Colors.green),
        title: Text('${_memorizedSurahs.length} سورة متاحة'),
        subtitle: Text(
          _memorizedSurahs.isEmpty
              ? 'لا يوجد محفوظ مسجل؛ اختر فئة الجزء أو الحزب أو السورة'
              : 'سيتم التوليد من السور المسجلة والمحفوظ السابق',
        ),
      ),
    );
  }

  Widget _buildNumericRangeCard({
    required String title,
    required int max,
    required int from,
    required int to,
    required void Function(int from, int to) onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: from,
                    decoration: const InputDecoration(labelText: 'من'),
                    items: List.generate(
                      to,
                      (index) => DropdownMenuItem(
                        value: index + 1,
                        child: Text('${index + 1}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) onChanged(value, to);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: to,
                    decoration: const InputDecoration(labelText: 'إلى'),
                    items: List.generate(
                      max - from + 1,
                      (index) => DropdownMenuItem(
                        value: from + index,
                        child: Text('${from + index}'),
                      ),
                    ),
                    onChanged: (value) {
                      if (value != null) onChanged(from, value);
                    },
                  ),
                ),
              ],
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
                  allowedSurahIds:
                      _memorizedSurahs.isEmpty ? null : _memorizedSurahs,
                  title: _memorizedSurahs.isEmpty
                      ? 'اختر السورة'
                      : 'اختر سورة من المحفوظ',
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
        child: AyahRangePicker(
          maxAyahs: surah.totalAyahs,
          initialFrom: _fromAyah,
          initialTo: _toAyah,
          onRangeChanged: (from, to) {
            setState(() {
              _fromAyah = from;
              _toAyah = to;
              _generatedExam = null;
            });
          },
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

  Widget _buildGenerationOptions() {
    const difficultyLabels = <int, String>{
      0: 'كل المستويات',
      1: 'سهل',
      2: 'متوسط',
      3: 'صعب',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('معايير السؤال', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _difficulty,
              decoration: const InputDecoration(
                labelText: 'درجة الصعوبة',
                prefixIcon: Icon(Icons.speed),
              ),
              items: difficultyLabels.entries.map((entry) {
                return DropdownMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                );
              }).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _difficulty = value;
                  _generatedExam = null;
                  _usedQuestionKeys.clear();
                });
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الأسطر التقريبية لكل سؤال'),
                Text(
                  _linesPerQuestion.toStringAsFixed(0),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Slider(
              value: _linesPerQuestion,
              min: 1,
              max: 10,
              divisions: 9,
              label: _linesPerQuestion.toStringAsFixed(0),
              onChanged: (value) {
                setState(() {
                  _linesPerQuestion = value;
                  _generatedExam = null;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('منع تكرار الأسئلة'),
              subtitle: const Text('لا يعيد بدايات الأسئلة في التوليد التالي'),
              value: _preventDuplicates,
              onChanged: (value) {
                setState(() {
                  _preventDuplicates = value;
                  if (!value) _usedQuestionKeys.clear();
                });
              },
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
      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.35),
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
              exam['category'] as String,
              style: TextStyle(color: Colors.grey[700]),
            ),
            Text(
              'إجمالي الأسطر: ${(exam['total_lines'] as double).toStringAsFixed(1)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const Divider(height: 24),
            const Text(
              'أسئلة النموذج:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...questions.asMap().entries.map((entry) {
              final index = entry.key;
              final question = entry.value;
              return _buildQuestion(index + 1, question);
            }),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saveTemplate,
                icon: const Icon(Icons.save),
                label: Text(
                  _savedTemplateId == null
                      ? 'اعتماد وحفظ النموذج'
                      : 'تحديث النموذج المحفوظ',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printExam(PdfPageFormat.a4),
                    icon: const Icon(Icons.print),
                    label: const Text('طباعة A4'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _printExam(PdfPageFormat.a5),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('طباعة A5'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _printExam(PdfPageFormat format) async {
    if (_selectedStudent == null || _generatedExam == null) return;
    final questions = (_generatedExam!['questions'] as List)
        .map((question) => Map<String, dynamic>.from(question as Map))
        .toList();
    final bytes = await _pdf.generateExamPaper(
      student: _selectedStudent!,
      category: _generatedExam!['category'] as String,
      questions: questions,
      pageFormat: format,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Widget _buildQuestion(int number, Map<String, dynamic> question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
              Expanded(
                child: Text(
                  'سورة ${question['surah_name']} — الآية ${question['ayah_number']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ),
              Text(
                _questionTypeLabel(question['question_type'] as String?),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 11,
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'إدارة السؤال',
                onSelected: (action) => _handleQuestionAction(
                  action,
                  number - 1,
                ),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'up', child: Text('تحريك للأعلى')),
                  PopupMenuItem(value: 'down', child: Text('تحريك للأسفل')),
                  PopupMenuItem(value: 'edit', child: Text('تعديل النطاق والنوع')),
                  PopupMenuItem(value: 'replace', child: Text('استبدال السؤال')),
                  PopupMenuItem(value: 'delete', child: Text('حذف السؤال')),
                ],
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
                  color: Colors.green.withOpacity(0.12),
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

  String _questionTypeLabel(String? type) {
    switch (type) {
      case 'complete_ayah':
        return 'إكمال آية';
      case 'ayah_location':
        return 'موضع آية';
      default:
        return 'تسميع';
    }
  }

  void _handleQuestionAction(String action, int index) {
    switch (action) {
      case 'up':
        _moveQuestion(index, index - 1);
        break;
      case 'down':
        _moveQuestion(index, index + 1);
        break;
      case 'edit':
        _editQuestion(index);
        break;
      case 'replace':
        _replaceQuestion(index);
        break;
      case 'delete':
        _deleteQuestion(index);
        break;
    }
  }

  List<Map<String, dynamic>> _questionList() {
    return List<Map<String, dynamic>>.from(
      _generatedExam?['questions'] as List? ?? const [],
    );
  }

  void _setQuestions(List<Map<String, dynamic>> questions) {
    setState(() {
      _generatedExam = {
        ...?_generatedExam,
        'questions': questions,
        'total_lines': questions.fold<double>(
          0,
          (sum, question) => sum + (question['lines'] as num).toDouble(),
        ),
      };
    });
  }

  void _moveQuestion(int from, int to) {
    final questions = _questionList();
    if (from < 0 || from >= questions.length || to < 0 || to >= questions.length) {
      return;
    }
    final question = questions.removeAt(from);
    questions.insert(to, question);
    _setQuestions(questions);
  }

  void _deleteQuestion(int index) {
    final questions = _questionList();
    if (index < 0 || index >= questions.length) return;
    questions.removeAt(index);
    _setQuestions(questions);
  }

  Future<void> _replaceQuestion(int index) async {
    final questions = _questionList();
    if (index < 0 || index >= questions.length) return;
    final excluded = questions.map((question) => question['key'] as String).toSet();
    final replacement = ExamQuestionGeneratorService.generate(
      surahs: _quran.surahs,
      category: _category,
      allowedSurahIds: _memorizedSurahs.toSet(),
      selectedSurahId: _selectedSurah,
      fromAyah: _fromAyah,
      toAyah: _toAyah,
      fromJuz: _fromJuz,
      toJuz: _toJuz,
      fromHizb: _fromHizb,
      toHizb: _toHizb,
      difficulty: _difficulty,
      questionCount: 1,
      approximateLines: _linesPerQuestion,
      excludedQuestionKeys: excluded,
    );
    if (replacement.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد سؤال بديل ضمن المعايير الحالية')),
      );
      return;
    }
    questions[index] = replacement.first;
    _setQuestions(questions);
  }

  Future<void> _editQuestion(int index) async {
    final questions = _questionList();
    if (index < 0 || index >= questions.length) return;
    final question = questions[index];
    final surah = _quran.getSurah(question['surah_id'] as int);
    if (surah == null) return;
    final fromController = TextEditingController(text: '${question['ayah_number']}');
    final toController = TextEditingController(text: '${question['to_ayah']}');
    var questionType = question['question_type'] as String? ?? 'recite_from';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تعديل سؤال سورة ${surah.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: questionType,
                decoration: const InputDecoration(labelText: 'نوع السؤال'),
                items: const [
                  DropdownMenuItem(value: 'recite_from', child: Text('اقرأ من قوله تعالى')),
                  DropdownMenuItem(value: 'complete_ayah', child: Text('أكمل الآية')),
                  DropdownMenuItem(value: 'ayah_location', child: Text('حدد موضع الآية')),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => questionType = value);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fromController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'من آية'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: toController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'إلى آية'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
          ],
        ),
      ),
    );
    if (accepted == true) {
      final from = int.tryParse(fromController.text);
      final to = int.tryParse(toController.text);
      if (from != null && to != null && from >= 1 && to >= from && to <= surah.totalAyahs) {
        final ayahs = surah.getAyahRange(from, to);
        question
          ..['key'] = '${surah.number}:$from'
          ..['ayah_number'] = from
          ..['to_ayah'] = to
          ..['question_type'] = questionType
          ..['page'] = ayahs.first.page
          ..['juz'] = ayahs.first.juz
          ..['hizb'] = ayahs.first.hizb
          ..['difficulty'] = ayahs.first.difficulty
          ..['start_text'] = ayahs.first.text.split(' ').take(5).join(' ')
          ..['full_text'] = ayahs.map((ayah) => ayah.text).join(' ')
          ..['lines'] = ayahs.fold<double>(0, (sum, ayah) => sum + ayah.lines);
        questions[index] = question;
        _setQuestions(questions);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('النطاق يجب أن يكون بين 1 و${surah.totalAyahs}')),
        );
      }
    }
    fromController.dispose();
    toController.dispose();
  }

  Future<void> _saveTemplate() async {
    if (_selectedStudent == null || _generatedExam == null) return;
    if (_questionList().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف سؤالًا واحدًا على الأقل قبل الحفظ')),
      );
      return;
    }
    final titleController = TextEditingController(
      text: _savedTemplateTitle ??
          'اختبار ${_selectedStudent!.name} — $_categoryLabel',
    );
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اعتماد نموذج الاختبار'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'اسم النموذج'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, titleController.text.trim()),
            child: const Text('حفظ النموذج'),
          ),
        ],
      ),
    );
    titleController.dispose();
    if (title == null || title.isEmpty) return;

    final questions = _questionList();
    final template = ExamTemplate(
      id: _savedTemplateId,
      studentId: _selectedStudent!.id,
      title: title,
      category: _category,
      criteriaJson: jsonEncode({
        'category': _category,
        'fromJuz': _fromJuz,
        'toJuz': _toJuz,
        'fromHizb': _fromHizb,
        'toHizb': _toHizb,
        'surahId': _selectedSurah,
        'fromAyah': _fromAyah,
        'toAyah': _toAyah,
        'difficulty': _difficulty,
        'linesPerQuestion': _linesPerQuestion,
        'preventDuplicates': _preventDuplicates,
      }),
      questionsCount: questions.length,
      createdAt: _savedTemplateCreatedAt,
    );
    final rows = questions.asMap().entries.map((entry) {
      final question = entry.value;
      return ExamTemplateQuestion(
        templateId: template.id,
        questionOrder: entry.key + 1,
        surahId: question['surah_id'] as int,
        fromAyah: question['ayah_number'] as int,
        toAyah: question['to_ayah'] as int,
        questionType: question['question_type'] as String? ?? 'recite_from',
        promptText: question['start_text'] as String,
        answerText: question['full_text'] as String,
        page: question['page'] as int,
        juz: question['juz'] as int,
        hizb: question['hizb'] as int,
        difficulty: question['difficulty'] as int,
        lines: (question['lines'] as num).toDouble(),
      );
    }).toList();
    await _db.saveExamTemplate(template, rows);
    if (!mounted) return;
    setState(() {
      _savedTemplateId = template.id;
      _savedTemplateTitle = title;
      _savedTemplateCreatedAt = template.createdAt;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم اعتماد نموذج الاختبار وحفظ أسئلته')),
    );
  }
}
