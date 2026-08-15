import 'dart:convert';

import 'package:flutter/material.dart';

import '../../models/exam.dart';
import '../../models/exam_template.dart';
import '../../models/memorization.dart';
import '../../models/plan.dart';
import '../../models/student.dart';
import '../../services/database_service.dart';
import '../../services/monthly_plan_exam_service.dart';
import '../../services/monthly_exam_persistence_service.dart';
import '../../services/memorized_content_service.dart';
import '../../services/plan_progress_service.dart';
import '../../services/quran_service.dart';
import '../../utils/helpers.dart';

class MonthlyPlanExamScreen extends StatefulWidget {
  const MonthlyPlanExamScreen({super.key});

  @override
  State<MonthlyPlanExamScreen> createState() => _MonthlyPlanExamScreenState();
}

class _MonthlyPlanExamScreenState extends State<MonthlyPlanExamScreen> {
  final DatabaseService _db = DatabaseService();
  final QuranService _quran = QuranService.instance;
  late final PlanProgressService _progress = PlanProgressService(database: _db);
  late final MonthlyExamPersistenceService _persistence =
      MonthlyExamPersistenceService(databaseService: _db);
  final TextEditingController _notes = TextEditingController();

  List<Student> _students = [];
  List<SmartPlan> _plans = [];
  SmartPlan? _plan;
  Student? _student;
  List<MonthlyPlanExamQuestion> _memorizationQuestions = [];
  List<MonthlyPlanExamQuestion> _reviewQuestions = [];
  List<int> _memorizationScores = [0, 0, 0];
  List<int> _reviewScores = [0, 0, 0];
  int _memorizationPlanScore = 0;
  int _reviewPlanScore = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    await _quran.initialize();
    final values = await Future.wait<dynamic>([
      _db.getStudents(status: 'active'),
      _db.getSmartPlans(),
    ]);
    if (!mounted) return;
    setState(() {
      _students = values[0] as List<Student>;
      _plans = (values[1] as List<SmartPlan>)
          .where((plan) => plan.period == 'monthly' && plan.status != 'cancelled')
          .toList();
      _loading = false;
    });
  }

  Future<void> _selectPlan(String? id) async {
    if (id == null) return;
    final matches = _plans.where((item) => item.id == id);
    if (matches.isEmpty) return;
    final plan = matches.first;
    final studentMatches = _students.where((item) => item.id == plan.studentId);
    if (studentMatches.isEmpty) return;
    final student = studentMatches.first;
    setState(() => _loading = true);
    final values = await Future.wait<dynamic>([
      _progress.calculate(plan: plan, student: student),
      _db.getStudentMemorizedRanges(student.id),
      _db.getStudentMemorizationInRange(student.id, plan.startDate, plan.endDate),
    ]);
    final progress = values[0] as SmartPlanProgress;
    final ranges = values[1] as Map<int, MemorizedAyahRange>;
    final periodRows = values[2] as List<MemorizationProgress>;
    final memorizationQuestions = MonthlyPlanExamService.buildQuestions(
      section: 'memorization',
      surahs: _quran.surahs,
      fallbackRanges: ranges,
      periodProgress: periodRows,
    );
    final reviewQuestions = MonthlyPlanExamService.buildQuestions(
      section: 'review',
      surahs: _quran.surahs,
      fallbackRanges: ranges,
      periodProgress: periodRows,
    );
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _student = student;
      _memorizationQuestions = memorizationQuestions;
      _reviewQuestions = reviewQuestions;
      _memorizationScores = List.filled(3, 0);
      _reviewScores = List.filled(3, 0);
      _memorizationPlanScore = MonthlyPlanExamService.planComponentScore(progress.memorizationRatio);
      _reviewPlanScore = MonthlyPlanExamService.planComponentScore(progress.reviewRatio);
      _loading = false;
    });
  }

  MonthlyPlanExamBreakdown get _breakdown => MonthlyPlanExamBreakdown(
        memorizationQuestionScores: _memorizationScores,
        reviewQuestionScores: _reviewScores,
        memorizationPlanScore: _memorizationPlanScore,
        reviewPlanScore: _reviewPlanScore,
      );

  Future<void> _save() async {
    final plan = _plan;
    final student = _student;
    if (plan == null || student == null) return;
    if (_memorizationQuestions.length < 3 || _reviewQuestions.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مادة محفوظة كافية لتوليد ثلاثة أسئلة لكل قسم.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final allQuestions = [..._memorizationQuestions, ..._reviewQuestions];
      final surahIds = allQuestions.map((q) => q.surahId).toList()..sort();
      final now = DateTime.now();
      final template = ExamTemplate(
        studentId: student.id,
        title: 'اختبار الخطة الشهرية — ${student.name}',
        category: 'monthly_plan',
        criteriaJson: jsonEncode({
          'schema': 'monthly_plan_template_v1',
          'plan_id': plan.id,
          'memorization_weight': 30,
          'review_weight': 30,
          'memorization_plan_weight': 20,
          'review_plan_weight': 20,
        }),
        questionsCount: allQuestions.length,
        createdAt: now,
        updatedAt: now,
      );
      final templateQuestions = <ExamTemplateQuestion>[];
      for (var index = 0; index < allQuestions.length; index++) {
        final question = allQuestions[index];
        final ayahs = _quran.getAyahRange(
          question.surahId,
          question.fromAyah,
          question.toAyah,
        );
        if (ayahs.isEmpty) {
          throw StateError('تعذر بناء مادة السؤال ${index + 1}');
        }
        final first = ayahs.first;
        final score = index < 3
            ? _memorizationScores[index]
            : _reviewScores[index - 3];
        final difficulty = ayahs.fold<int>(
              0,
              (maxValue, ayah) =>
                  ayah.difficulty > maxValue ? ayah.difficulty : maxValue,
            );
        final lines = ayahs.fold<double>(0, (sum, ayah) => sum + ayah.lines);
        templateQuestions.add(
          ExamTemplateQuestion(
            templateId: template.id,
            questionOrder: index + 1,
            surahId: question.surahId,
            fromAyah: question.fromAyah,
            toAyah: question.toAyah,
            questionType: 'recite_from',
            promptText: question.section == 'memorization'
                ? 'سؤال حفظ ${question.index}: ${question.label}'
                : 'سؤال مراجعة ${question.index}: ${question.label}',
            answerText: ayahs.map((ayah) => ayah.text).join(' '),
            page: first.page,
            juz: first.juz,
            hizb: first.hizb,
            difficulty: difficulty,
            lines: lines,
            isAssessed: true,
            questionScore: score.toDouble(),
            createdAt: now,
          ),
        );
      }
      final exam = Exam(
        studentId: student.id,
        date: now,
        type: ExamType.monthlyPlan,
        templateId: template.id,
        fromSurah: surahIds.first,
        toSurah: surahIds.last,
        score: _breakdown.total,
        notes: MonthlyPlanExamService.encodeNotes(
          planId: plan.id,
          templateId: template.id,
          breakdown: _breakdown,
          questions: allQuestions,
          teacherNotes: _notes.text,
        ),
      );
      await _persistence.save(
        template: template,
        questions: templateQuestions,
        exam: exam,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حفظ الاختبار الشهري: $error')),
      );
    }
  }

  Widget _questionSection({
    required String title,
    required List<MonthlyPlanExamQuestion> questions,
    required List<int> scores,
    required ValueChanged<List<int>> onChanged,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            for (var i = 0; i < 3; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        i < questions.length ? questions[i].label : 'لا توجد مادة كافية للسؤال ${i + 1}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: scores[i],
                      items: List.generate(11, (value) => DropdownMenuItem(value: value, child: Text('$value/10'))),
                      onChanged: (value) {
                        if (value == null) return;
                        final next = [...scores]..[i] = value;
                        onChanged(next);
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الاختبار الشهري للخطة')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _plan?.id,
                  decoration: const InputDecoration(
                    labelText: 'الخطة الشهرية',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                  ),
                  items: _plans.map((plan) {
                    final student = _students.where((item) => item.id == plan.studentId);
                    final name = student.isEmpty ? 'طالب' : student.first.name;
                    return DropdownMenuItem(
                      value: plan.id,
                      child: Text('$name — ${Helpers.formatPlanDate(plan.startDate)}'),
                    );
                  }).toList(),
                  onChanged: _selectPlan,
                ),
                if (_plan != null) ...[
                  const SizedBox(height: 16),
                  _questionSection(
                    title: 'الحفظ — 3 أسئلة / 30',
                    questions: _memorizationQuestions,
                    scores: _memorizationScores,
                    onChanged: (value) => setState(() => _memorizationScores = value),
                  ),
                  _questionSection(
                    title: 'المراجعة — 3 أسئلة / 30',
                    questions: _reviewQuestions,
                    scores: _reviewScores,
                    onChanged: (value) => setState(() => _reviewScores = value),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.task_alt_outlined),
                      title: const Text('إكمال خطة الحفظ'),
                      trailing: Text('$_memorizationPlanScore/20', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.repeat_on_outlined),
                      title: const Text('إكمال خطة المراجعة'),
                      trailing: Text('$_reviewPlanScore/20', style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('المجموع'),
                      trailing: Text('${_breakdown.total}/100', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'ملاحظات المعلم'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                    label: const Text('حفظ الاختبار الشهري'),
                  ),
                ],
              ],
            ),
    );
  }
}
