import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../models/exam_template.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/pdf_service.dart';
import '../../services/quran_service.dart';
import 'exam_generator_screen.dart';

class ExamTemplatesScreen extends StatefulWidget {
  const ExamTemplatesScreen({super.key});

  @override
  State<ExamTemplatesScreen> createState() => _ExamTemplatesScreenState();
}

class _ExamTemplatesScreenState extends State<ExamTemplatesScreen> {
  final DatabaseService _db = DatabaseService();
  final PdfService _pdf = PdfService();
  final QuranService _quran = QuranService.instance;

  List<ExamTemplate> _templates = [];
  Map<String, Student> _students = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final templates = await _db.getExamTemplates();
    final students = await _db.getStudents();
    if (!mounted) return;
    setState(() {
      _templates = templates;
      _students = {for (final student in students) student.id: student};
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل نماذج الاختبارات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) =>
                        _buildTemplateCard(_templates[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 12),
          const Text('لا توجد نماذج معتمدة بعد'),
          const SizedBox(height: 8),
          const Text('أنشئ نموذجًا ثم اضغط «اعتماد وحفظ النموذج»'),
        ],
      ),
    );
  }

  Widget _buildTemplateCard(ExamTemplate template) {
    final student = _students[template.studentId];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.assignment_outlined)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(student?.name ?? 'طالب غير متاح'),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'حذف النموذج',
                  onPressed: () => _deleteTemplate(template),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('${template.questionsCount} أسئلة')),
                Chip(label: Text(_categoryLabel(template.category))),
                Chip(label: Text(_formatDate(template.updatedAt))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: student == null
                        ? null
                        : () => _openTemplate(template, student),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('فتح وتعديل'),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<PdfPageFormat>(
                  tooltip: 'طباعة النموذج',
                  enabled: student != null,
                  onSelected: (format) =>
                      _printTemplate(template, student!, format),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: PdfPageFormat.a4,
                      child: const Text('طباعة A4'),
                    ),
                    PopupMenuItem(
                      value: PdfPageFormat.a5,
                      child: const Text('طباعة A5'),
                    ),
                  ],
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Icon(Icons.print_outlined),
                        SizedBox(width: 6),
                        Text('طباعة'),
                      ],
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

  String _categoryLabel(String category) {
    switch (category) {
      case 'juz':
        return 'حسب الجزء';
      case 'hizb':
        return 'حسب الحزب';
      case 'surah':
        return 'حسب السورة';
      default:
        return 'محفوظ الطالب';
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    return '${local.year}/${local.month.toString().padLeft(2, '0')}/'
        '${local.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openTemplate(
    ExamTemplate template,
    Student student,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ExamGeneratorScreen(
          student: student,
          template: template,
        ),
      ),
    );
    await _loadData();
  }

  Future<void> _printTemplate(
    ExamTemplate template,
    Student student,
    PdfPageFormat format,
  ) async {
    final rows = await _db.getExamTemplateQuestions(template.id);
    final questions = rows.map((row) => <String, dynamic>{
      'surah_name': _quran.getSurahName(row.surahId),
      'start_text': row.promptText,
      'question_type': row.questionType,
    }).toList();
    final bytes = await _pdf.generateExamPaper(
      student: student,
      category: _categoryLabel(template.category),
      questions: questions,
      pageFormat: format,
    );
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _deleteTemplate(ExamTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نموذج الاختبار؟'),
        content: Text('سيُحذف «${template.title}» وأسئلته نهائيًا من الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _db.deleteExamTemplate(template.id);
    await _loadData();
  }
}
