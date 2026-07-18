import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../widgets/app_design_widgets.dart';

class UsageGuideScreen extends StatefulWidget {
  const UsageGuideScreen({super.key});

  @override
  State<UsageGuideScreen> createState() => _UsageGuideScreenState();
}

class _UsageGuideScreenState extends State<UsageGuideScreen> {
  String _query = '';

  static const _sections = <_GuideSection>[
    _GuideSection(
      title: 'البداية اليومية',
      icon: Icons.today_outlined,
      steps: [
        'ابدأ من الحضور وسجّل حاضرًا أو غائبًا أو مستأذنًا لكل طالب.',
        'بعد التحضير افتح الحفظ أو المراجعة من شاشة الحضور نفسها.',
        'عند انتهاء الدوام راجع تنبيهات من لم يسمّع والنقاط التلقائية.',
      ],
    ),
    _GuideSection(
      title: 'تسجيل الحفظ والمراجعة',
      icon: Icons.menu_book_outlined,
      steps: [
        'اختر الطالب؛ تظهر المراجعة من كامل المحفوظ المسجل في ملفه وخريطة المصحف.',
        'حدد آية البداية، ثم استخدم «التوقف هنا» أو نهاية الصفحة أو الحزب.',
        'يجمع التطبيق كل تسجيلات الحفظ في اليوم قبل حساب إنجاز المقرر والنقاط.',
        'يمكن تصحيح أي تسجيل أو حذفه من سجل التسميع مع إعادة الحساب تلقائيًا.',
      ],
    ),
    _GuideSection(
      title: 'الخطط الذكية',
      icon: Icons.track_changes_outlined,
      steps: [
        'حدد مقرر الحفظ والمراجعة الافتراضيين داخل ملف الطالب أولًا.',
        'أنشئ خطة أسبوعية أو شهرية؛ المقادير تُملأ من ملف الطالب.',
        'لجميع الطلاب استخدم زر الإنشاء الجماعي في رأس شاشة الخطط.',
        'لا تُنشأ خطة تالية حتى يكتمل اختبار التجاوز للخطة السابقة.',
      ],
    ),
    _GuideSection(
      title: 'التقارير والطباعة',
      icon: Icons.print_outlined,
      steps: [
        'اختر فترة ميلادية مخصصة أو شهرًا هجريًا مثل محرم.',
        'يمكن طباعة تقرير طالب، ملف واحد لجميع الطلاب، أو ملخص إدارة من صفحة واحدة.',
        'اطبع بطاقات QR من شاشة التقارير، ثم احفظها ووزعها بعناية.',
        'قالب واتساب يوضح نطاق الحفظ والمراجعة ويطلب ملاحظات ولي الأمر.',
      ],
    ),
    _GuideSection(
      title: 'المزامنة وحماية البيانات',
      icon: Icons.cloud_sync_outlined,
      steps: [
        'الرفع يرسل بيانات هذا الجهاز إلى السحابة، والتنزيل يجلب نسخة السحابة.',
        'استخدم الرفع ثم التنزيل عند العمل الطبيعي بعد أخذ نسخة احتياطية.',
        'لا تشارك عبارة حماية النسخة الاحتياطية أو بطاقات QR في مكان عام.',
        'نفّذ SQL المطلوب في Supabase قبل اختبار ميزة سحابية جديدة.',
      ],
    ),
    _GuideSection(
      title: 'النقاط والصندوق',
      icon: Icons.account_balance_wallet_outlined,
      steps: [
        'الغياب بلا عذر هو العقوبة الأعلى، ثم عدم التسميع والمظهر والتأخر.',
        'نقاط الحفظ متدرجة حسب نسبة إنجاز مقرر اليوم، وحدها الأعلى 10 نقاط.',
        'عند تسجيل غرامة مالية يمكن ربطها بسجل المخالفة السلبية الذي سببها.',
      ],
    ),
    _GuideSection(
      title: 'التشخيص والدعم',
      icon: Icons.health_and_safety_outlined,
      steps: [
        'افتح الإعدادات ثم التشخيص لمراجعة SQLite والنسخ والمزامنة واتصال Supabase.',
        'عند ظهور مشكلة اضغط مشاركة تقرير الدعم وأرسله دون إضافة أسماء أو صور طلاب.',
        'رمز الحادثة بصمة تقنية مختصرة؛ لا يحتوي نص الخطأ أو مسار الجهاز.',
        'لا تمسح بيانات التطبيق أو تعِد تثبيته قبل إنشاء نسخة احتياطية قابلة للاستعادة.',
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = _sections.where((section) {
      if (query.isEmpty) return true;
      return section.title.toLowerCase().contains(query) ||
          section.steps.any((step) => step.toLowerCase().contains(query));
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('دليل استخدام حلقتي')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          const AppPageIntro(
            title: 'كيف أستخدم التطبيق؟',
            subtitle: 'مسارات قصيرة للمهام اليومية والإدارية الأكثر استخدامًا.',
            icon: Icons.help_outline,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            decoration: const InputDecoration(
              labelText: 'ابحث في الدليل',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (visible.isEmpty)
            const AppEmptyState(
              icon: Icons.search_off_outlined,
              title: 'لا توجد نتيجة',
              message: 'جرّب كلمة مثل: المراجعة، التقرير، المزامنة أو الخطة.',
            )
          else
            ...visible.map(
              (section) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: Icon(section.icon),
                  title: Text(
                    section.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  children: section.steps
                      .asMap()
                      .entries
                      .map(
                        (entry) => ListTile(
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text('${entry.key + 1}'),
                          ),
                          title: Text(entry.value),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GuideSection {
  final String title;
  final IconData icon;
  final List<String> steps;

  const _GuideSection({
    required this.title,
    required this.icon,
    required this.steps,
  });
}
