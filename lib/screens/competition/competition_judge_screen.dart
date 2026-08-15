import 'package:flutter/material.dart';

import '../../models/competition.dart';
import '../../models/exam_template.dart';
import '../../models/student.dart';
import '../../services/competition_scoring_service.dart';
import '../../services/database_service.dart';
import '../../widgets/app_design_widgets.dart';
import '../exam/exam_generator_screen.dart';

class CompetitionJudgeScreen extends StatefulWidget {
  final CompetitionEvent event;

  const CompetitionJudgeScreen({
    super.key,
    required this.event,
  });

  @override
  State<CompetitionJudgeScreen> createState() =>
      _CompetitionJudgeScreenState();
}

class _CompetitionJudgeScreenState extends State<CompetitionJudgeScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _notesController = TextEditingController();
  late final TabController _tabs;

  List<Student> _students = [];
  List<CompetitionResult> _results = [];
  List<ExamTemplate> _templates = [];
  Student? _student;
  String? _templateId;
  CompetitionResult? _existing;
  int _obvious = 0;
  int _subtle = 0;
  int _prompts = 0;
  int _stops = 0;
  int _tajweed = 0;
  bool _loading = true;
  bool _saving = false;

  double get _score => CompetitionScoringService.calculate(
        maximumScore: widget.event.maximumScore,
        obviousErrors: _obvious,
        subtleErrors: _subtle,
        promptCount: _prompts,
        stopCount: _stops,
        tajweedErrors: _tajweed,
      );

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final values = await Future.wait<dynamic>([
        _db.getStudents(status: 'active'),
        _db.getCompetitionResults(widget.event.id),
      ]);
      final students = values[0] as List<Student>;
      final results = values[1] as List<CompetitionResult>;
      if (!mounted) return;
      setState(() {
        _students = students;
        _results = results;
        _loading = false;
      });
      if (_student == null && students.isNotEmpty) {
        await _selectStudent(students.first);
      } else if (_student != null) {
        await _selectStudent(_student!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تحميل التحكيم: $error')),
      );
    }
  }

  Future<void> _selectStudent(Student student) async {
    final templates = await _db.getExamTemplates(studentId: student.id);
    CompetitionResult? existing;
    for (final result in _results) {
      if (result.studentId == student.id) {
        existing = result;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _student = student;
      _templates = templates;
      _existing = existing;
      _templateId = existing?.templateId;
      _obvious = existing?.obviousErrors ?? 0;
      _subtle = existing?.subtleErrors ?? 0;
      _prompts = existing?.promptCount ?? 0;
      _stops = existing?.stopCount ?? 0;
      _tajweed = existing?.tajweedErrors ?? 0;
      _notesController.text = existing?.notes ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        bottom: TabBar(
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.72),
          indicatorColor: Theme.of(context).colorScheme.secondary,
          controller: _tabs,
          tabs: const [
            Tab(text: 'التحكيم', icon: Icon(Icons.balance_outlined)),
            Tab(text: 'النتائج', icon: Icon(Icons.emoji_events_outlined)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabs,
              children: [
                _judgeTab(),
                _resultsTab(),
              ],
            ),
    );
  }

  Widget _judgeTab() {
    if (_students.isEmpty) {
      return const AppEmptyState(
        icon: Icons.people_outline,
        title: 'لا يوجد طلاب نشطون',
        message: 'أضف المتسابقين إلى سجل الطلاب أولًا.',
      );
    }
    return AppScreenBody(
      scrollable: true,
      maxWidth: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageIntro(
            title: 'تحكيم ${widget.event.category}',
            subtitle:
                'الدرجة تحسب مباشرة، ويمكن ربط نموذج أسئلة مولد لكل متسابق.',
            icon: Icons.balance_outlined,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Student>(
            initialValue: _student,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'المتسابق',
              prefixIcon: Icon(Icons.person_outline),
            ),
            items: _students
                .map(
                  (student) => DropdownMenuItem(
                    value: student,
                    child: Text(student.name),
                  ),
                )
                .toList(),
            onChanged: (student) {
              if (student != null) _selectStudent(student);
            },
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _templates.any((item) => item.id == _templateId)
                      ? _templateId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'نموذج الأسئلة (اختياري)',
                    prefixIcon: Icon(Icons.quiz_outlined),
                  ),
                  items: _templates
                      .map(
                        (template) => DropdownMenuItem(
                          value: template.id,
                          child: Text(
                            template.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _templateId = value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _generateQuestions,
                icon: const Icon(Icons.auto_awesome_outlined),
                tooltip: 'توليد أسئلة',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'تسجيل الأخطاء',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          _counter(
            title: 'خطأ جلي',
            subtitle: 'خطأ واضح في الحفظ (−3)',
            color: const Color(0xFFB4232F),
            value: _obvious,
            onChanged: (value) => setState(() => _obvious = value),
          ),
          _counter(
            title: 'خطأ خفي',
            subtitle: 'خطأ بسيط في الكلمات (−1)',
            color: const Color(0xFFC2410C),
            value: _subtle,
            onChanged: (value) => setState(() => _subtle = value),
          ),
          _counter(
            title: 'تلقين',
            subtitle: 'احتاج تذكيرًا أو مساعدة (−4)',
            color: const Color(0xFF7E22CE),
            value: _prompts,
            onChanged: (value) => setState(() => _prompts = value),
          ),
          _counter(
            title: 'توقف',
            subtitle: 'توقف لفترة أثناء التلاوة (−2)',
            color: const Color(0xFF1D4ED8),
            value: _stops,
            onChanged: (value) => setState(() => _stops = value),
          ),
          _counter(
            title: 'أخطاء التجويد',
            subtitle: 'مخالفة حكم تجويد (−0.5)',
            color: const Color(0xFF0F766E),
            value: _tajweed,
            onChanged: (value) => setState(() => _tajweed = value),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('الدرجة الحالية'),
                Text(
                  _score.toStringAsFixed(
                    _score == _score.roundToDouble() ? 0 : 1,
                  ),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 46,
                      ),
                ),
                Text('من ${widget.event.maximumScore.toStringAsFixed(0)}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'ملاحظات المحكم',
              prefixIcon: Icon(Icons.notes_outlined),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(
              _existing == null ? 'اعتماد النتيجة' : 'تحديث النتيجة',
            ),
          ),
        ],
      ),
    );
  }

  Widget _counter({
    required String title,
    required String subtitle,
    required Color color,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: value == 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 38,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton.filledTonal(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _resultsTab() {
    final ranked = [..._results]
      ..sort((a, b) {
        final score = b.score.compareTo(a.score);
        return score != 0 ? score : a.assessedAt.compareTo(b.assessedAt);
      });
    final highest = ranked.isEmpty ? 0 : ranked.first.score;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _resultMetric(
                  'المشاركون',
                  '${_students.length}',
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _resultMetric(
                  'تم تقييمهم',
                  '${ranked.length}',
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _resultMetric(
                  'أعلى درجة',
                  highest.toStringAsFixed(
                    highest == highest.roundToDouble() ? 0 : 1,
                  ),
                  Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ranked.isEmpty)
            const AppEmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'لم تعتمد نتائج بعد',
              message: 'اختر متسابقًا من تبويب التحكيم وسجل النتيجة.',
            )
          else
            ...ranked.asMap().entries.map((entry) {
              final student = _studentById(entry.value.studentId);
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${entry.key + 1}'),
                  ),
                  title: Text(student?.name ?? 'طالب غير متاح'),
                  subtitle: Text(widget.event.category),
                  trailing: Text(
                    entry.value.score.toStringAsFixed(
                      entry.value.score ==
                              entry.value.score.roundToDouble()
                          ? 0
                          : 1,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  onTap: student == null
                      ? null
                      : () {
                          _tabs.animateTo(0);
                          _selectStudent(student);
                        },
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _resultMetric(String label, String value, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 22,
              ),
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );

  Student? _studentById(String id) {
    for (final student in _students) {
      if (student.id == id) return student;
    }
    return null;
  }

  Future<void> _generateQuestions() async {
    final student = _student;
    if (student == null) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => ExamGeneratorScreen(student: student),
      ),
    );
    if (!mounted) return;
    final templates = await _db.getExamTemplates(studentId: student.id);
    setState(() => _templates = templates);
  }

  Future<void> _save() async {
    final student = _student;
    if (student == null) return;
    setState(() => _saving = true);
    try {
      final result = CompetitionResult(
        id: _existing?.id,
        eventId: widget.event.id,
        studentId: student.id,
        templateId: _templateId,
        obviousErrors: _obvious,
        subtleErrors: _subtle,
        promptCount: _prompts,
        stopCount: _stops,
        tajweedErrors: _tajweed,
        score: _score,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        assessedAt: _existing?.assessedAt,
      );
      await _db.saveCompetitionResult(result);
      await _load();
      if (!mounted) return;
      _tabs.animateTo(1);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اعتماد نتيجة المتسابق')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ النتيجة: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
