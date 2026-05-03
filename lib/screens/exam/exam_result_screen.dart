import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/student.dart';
import '../../models/exam.dart';
import '../../services/pdf_service.dart';
import '../../utils/quran_data.dart';
import '../../utils/helpers.dart';

class ExamResultScreen extends StatelessWidget {
  final Exam exam;
  final Student student;
  final PdfService _pdf = PdfService();

  ExamResultScreen({
    super.key,
    required this.exam,
    required this.student,
  });

  Future<void> _printResult(BuildContext context) async {
    try {
      final pdfBytes = await _pdf.generateExamResult(student, exam, 'حلقتي');
      await Printing.layoutPdf(onLayout: (_) => pdfBytes);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الطباعة: $e')),
        );
      }
    }
  }

  String get _scoreLabel {
    if (exam.score >= 90) return 'ممتاز';
    if (exam.score >= 80) return 'جيد جداً';
    if (exam.score >= 70) return 'جيد';
    if (exam.score >= 60) return 'مقبول';
    return 'ضعيف';
  }

  Color get _scoreColor {
    if (exam.score >= 90) return Colors.green;
    if (exam.score >= 75) return Colors.lightGreen;
    if (exam.score >= 60) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final fromSurah = QuranData.getSurahName(exam.fromSurah);
    final toSurah = QuranData.getSurahName(exam.toSurah);

    return Scaffold(
      appBar: AppBar(
        title: const Text('نتيجة الامتحان'),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printResult(context),
            tooltip: 'طباعة',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildScoreCard(context),
            const SizedBox(height: 16),
            _buildDetailsCard(context, fromSurah, toSurah),
            if (exam.notes != null && exam.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildNotesCard(context),
            ],
            const SizedBox(height: 16),
            _buildStudentCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              student.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _scoreColor.withOpacity(0.2),
                    _scoreColor.withOpacity(0.05),
                  ],
                ),
                border: Border.all(color: _scoreColor, width: 6),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${exam.score}',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _scoreColor,
                    ),
                  ),
                  Text(
                    '%',
                    style: TextStyle(
                      fontSize: 20,
                      color: _scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              decoration: BoxDecoration(
                color: _scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _scoreLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _scoreColor,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (exam.score >= 60)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  const Text(
                    '+10 نقاط',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsCard(BuildContext context, String fromSurah, String toSurah) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تفاصيل الامتحان',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(
              'التاريخ',
              Helpers.getFullHijriDate(exam.date),
              Icons.calendar_today,
            ),
            _buildDetailRow(
              'نوع الامتحان',
              exam.type == 'oral' ? 'شفهي' : 'تحريري',
              Icons.quiz,
            ),
            _buildDetailRow(
              'النطاق',
              fromSurah == toSurah
                  ? 'سورة $fromSurah'
                  : 'من $fromSurah إلى $toSurah',
              Icons.menu_book,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey[600])),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNotesCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.note, color: Colors.grey[600]),
                const SizedBox(width: 8),
                const Text(
                  'ملاحظات وتوصيات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Text(exam.notes!),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(BuildContext context) {
    return Card(
      color: Theme.of(context).primaryColor.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Text(
                student.name.isNotEmpty ? student.name[0] : '؟',
                style: TextStyle(
                  fontSize: 24,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'إجمالي الحفظ: ${student.totalMemorized} آية',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
