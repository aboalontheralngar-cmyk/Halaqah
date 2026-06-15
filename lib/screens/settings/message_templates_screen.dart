import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../models/message_template.dart';

class MessageTemplatesScreen extends StatefulWidget {
  const MessageTemplatesScreen({super.key});

  @override
  State<MessageTemplatesScreen> createState() => _MessageTemplatesScreenState();
}

class _MessageTemplatesScreenState extends State<MessageTemplatesScreen> {
  final DatabaseService _db = DatabaseService();
  final _assignmentController = TextEditingController();
  final _gradingController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _assignmentController.dispose();
    _gradingController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      final assignTpl = await _db.getMessageTemplate('assignment');
      final gradeTpl = await _db.getMessageTemplate('grading');

      setState(() {
        _assignmentController.text = assignTpl?.content ?? _defaultAssignmentTemplate;
        _gradingController.text = gradeTpl?.content ?? _defaultGradingTemplate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل القوالب: $e')),
        );
      }
    }
  }

  String get _defaultAssignmentTemplate =>
      'السلام عليكم ورحمة الله وبركاته، تم تكليف الطالب {اسم_الطالب} بواجب حفظ جديد: من سورة {السورة} آية {من} إلى آية {إلى}. نسأل الله له التوفيق.';

  String get _defaultGradingTemplate =>
      'السلام عليكم ورحمة الله وبركاته، تسميع الطالب {اسم_الطالب} اليوم في سورة {السورة} من آية {من} إلى آية {إلى}:\n- التقييم: {التقييم}\n- الأخطاء: {الأخطاء}\n- ملاحظة: {الملاحظة}';

  Future<void> _saveTemplates() async {
    try {
      await _db.saveMessageTemplate(
        MessageTemplate(type: 'assignment', content: _assignmentController.text),
      );
      await _db.saveMessageTemplate(
        MessageTemplate(type: 'grading', content: _gradingController.text),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ قوالب الرسائل بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحفظ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _restoreDefaults() {
    setState(() {
      _assignmentController.text = _defaultAssignmentTemplate;
      _gradingController.text = _defaultGradingTemplate;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('قوالب الرسائل لولي الأمر'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'استعادة الافتراضي',
            onPressed: _restoreDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSectionHeader('قالب تكليف الواجب الحفظ/المراجعة'),
                  const SizedBox(height: 8),
                  _buildTemplateCard(
                    controller: _assignmentController,
                    hint: 'اكتب رسالة الواجب هنا...',
                    variables: const [
                      '{اسم_الطالب}',
                      '{السورة}',
                      '{من}',
                      '{إلى}',
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionHeader('قالب تقييم التسميع التفصيلي'),
                  const SizedBox(height: 8),
                  _buildTemplateCard(
                    controller: _gradingController,
                    hint: 'اكتب رسالة تقييم التسميع هنا...',
                    variables: const [
                      '{اسم_الطالب}',
                      '{السورة}',
                      '{من}',
                      '{إلى}',
                      '{التقييم}',
                      '{الأخطاء}',
                      '{الملاحظة}',
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _saveTemplates,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ القوالب', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Colors.teal,
      ),
    );
  }

  Widget _buildTemplateCard({
    required TextEditingController controller,
    required String hint,
    required List<String> variables,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller,
              maxLines: 5,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                hintText: hint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'المتغيرات المتاحة (سيتم استبدالها تلقائياً):',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: variables.map((variable) {
                return ActionChip(
                  label: Text(variable, style: const TextStyle(fontSize: 11, color: Colors.teal)),
                  backgroundColor: Colors.teal.withOpacity(0.06),
                  onPressed: () {
                    final text = controller.text;
                    final selection = controller.selection;
                    String newText;
                    int newCursorPosition;

                    if (selection.isValid) {
                      newText = text.replaceRange(selection.start, selection.end, variable);
                      newCursorPosition = selection.start + variable.length;
                    } else {
                      newText = text + variable;
                      newCursorPosition = newText.length;
                    }

                    controller.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(offset: newCursorPosition),
                    );
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
