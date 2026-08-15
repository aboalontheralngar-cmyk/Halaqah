class RevisionSystemDefinition {
  final String id;
  final String title;
  final String summary;
  final String workflow;
  final List<int> targetIntervalsDays;

  const RevisionSystemDefinition({
    required this.id,
    required this.title,
    required this.summary,
    required this.workflow,
    required this.targetIntervalsDays,
  });
}

class RevisionSystemPolicy {
  const RevisionSystemPolicy._();

  static const String defaultSystem = 'adaptive_spaced';

  static const List<RevisionSystemDefinition> systems = [
    RevisionSystemDefinition(
      id: 'adaptive_spaced',
      title: 'التباعد المتكيف',
      summary: 'مراجعة أقرب لما تعثر فيه الطالب وأبعد لما أتقنه.',
      workflow:
          'استرجاع بعد 1، 2، 4، 7، 14، ثم 30 يومًا، وتُقرب المراجعة عند انخفاض التقييم.',
      targetIntervalsDays: [1, 2, 4, 7, 14, 30],
    ),
    RevisionSystemDefinition(
      id: 'five_day_stabilization',
      title: 'التثبيت حسب الصفحات',
      summary: 'تقسيم المحفوظ الجديد على أيام تثبيت متوازنة بحسب صفحات المصحف، حتى خمسة أيام.',
      workflow:
          'توزع صفحات المقطع على أيام التثبيت دون كسر الصفحة، ثم يدخل المقطع في دورة المراجعة المعتادة.',
      targetIntervalsDays: [1, 2, 3, 4, 5, 12, 30],
    ),
    RevisionSystemDefinition(
      id: 'sabaq_sabqi_manzil',
      title: 'سبق · سبقي · منزل',
      summary: 'الجديد، والمحفوظ القريب، ثم القديم في دورة يومية واحدة.',
      workflow:
          'سبق اليوم، ثم سبقي الأيام القريبة، ثم منزل من المحفوظ القديم يدور بانتظام.',
      targetIntervalsDays: [1, 2, 7, 14, 30],
    ),
    RevisionSystemDefinition(
      id: 'teacher_custom',
      title: 'خطة المعلم المخصصة',
      summary: 'المعلم يحدد المقدار والترتيب وفق حال الطالب.',
      workflow:
          'يستخدم مقدار المراجعة في ملف الطالب أو الخطة النشطة دون جدول آلي ملزم.',
      targetIntervalsDays: [],
    ),
  ];

  static RevisionSystemDefinition resolve(String? id) {
    return systems.firstWhere(
      (system) => system.id == id,
      orElse: () => systems.first,
    );
  }

  static int nextIntervalDays({
    required String systemId,
    required int successfulRepetitions,
    required int qualityRating,
  }) {
    final system = resolve(systemId);
    if (system.targetIntervalsDays.isEmpty) return 1;
    if (qualityRating <= 2) return 1;
    final index = successfulRepetitions
        .clamp(0, system.targetIntervalsDays.length - 1)
        .toInt();
    final base = system.targetIntervalsDays[index];
    return qualityRating == 3
        ? (base / 2).ceil().clamp(1, base).toInt()
        : base;
  }
}
