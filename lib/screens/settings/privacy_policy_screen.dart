import 'package:flutter/material.dart';

import '../../models/settings.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  final HalaqahSettings settings;

  const PrivacyPolicyScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('سياسة الخصوصية وإدارة البيانات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: theme.colorScheme.primaryContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'هذه السياسة توضّح طريقة تعامل تطبيق حلقتي مع بيانات الطلاب. '
                'مدير المركز هو المسؤول عن إبلاغ أولياء الأمور واعتماد المدة '
                'المناسبة للاحتفاظ وفق الأنظمة المعمول بها في بلده.',
                style: TextStyle(fontWeight: FontWeight.w600, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            context,
            icon: Icons.inventory_2_outlined,
            title: 'البيانات التي يعالجها التطبيق',
            body:
                'بيانات تعريف الطالب ووسائل تواصل ولي الأمر، الحضور والإجازات، '
                'الحفظ والمراجعة والاختبارات والخطط، النقاط والملاحظات، وبيانات '
                'التشغيل اللازمة للمزامنة والنسخ الاحتياطي.',
          ),
          _section(
            context,
            icon: Icons.task_alt_outlined,
            title: 'الغرض من المعالجة',
            body:
                'إدارة الحلقة ومتابعة تقدم الطالب وإصدار التقارير والتواصل مع '
                'ولي الأمر وحماية السجلات من الفقد. لا تُستخدم البيانات للإعلان '
                'أو البيع أو بناء ملفات تسويقية.',
          ),
          _section(
            context,
            icon: Icons.lock_outline,
            title: 'الحماية والنسخ الاحتياطي',
            body:
                'النسخ الجديدة مشفرة بعبارة حماية لا تظهر في سجل التدقيق. '
                'التخزين السحابي خاص بالحساب، والوصول إلى بيانات الحلقة يخضع '
                'لصلاحيات Supabase. يجب حفظ عبارة الحماية خارج الجهاز في مكان آمن.',
          ),
          _section(
            context,
            icon: Icons.schedule_outlined,
            title: 'الاحتفاظ',
            body:
                'يُحتفظ بسجل التدقيق محليًا لمدة ${settings.auditLogRetentionDays} يومًا. '
                'يحتفظ الجهاز بآخر ${settings.automaticBackupRetentionCount} نسخة تلقائية، '
                'وعند تفعيل السحابة يُحتفظ بآخر ${settings.cloudBackupRetentionCount} نسخة. '
                'بيانات الطالب لا تُحذف تلقائيًا؛ تُؤرشف أولًا لحماية السجل ثم '
                'يقرر مدير المركز حذفها بعد التصدير والتحقق من الحاجة النظامية.',
          ),
          _section(
            context,
            icon: Icons.share_outlined,
            title: 'المشاركة والإفصاح',
            body:
                'تُشارك التقارير فقط بقرار المعلم أو مدير المركز مع ولي الأمر '
                'أو الجهة المخولة. ينبغي تجنب إرسال ملفات النسخ الاحتياطية عبر '
                'قنوات عامة حتى مع وجود التشفير.',
          ),
          _section(
            context,
            icon: Icons.manage_accounts_outlined,
            title: 'التصحيح والتصدير والحذف',
            body:
                'يمكن تصحيح بيانات الطالب وسجلاته، وتصدير تقاريره ونسخة من '
                'البيانات، ثم أرشفته أو حذفه بحسب الصلاحيات. التعديلات الحساسة '
                'تُسجّل للمراجعة ولا تتضمن عبارة الحماية أو محتوى النسخة.',
          ),
          _section(
            context,
            icon: Icons.warning_amber_outlined,
            title: 'عند الاشتباه بفقد أو كشف البيانات',
            body:
                'يُوقف الحساب أو الجهاز المتأثر، وتُغيّر بيانات الدخول، وتُراجع '
                'صلاحيات المعلمين وسجل التدقيق، ثم تُستعاد آخر نسخة سليمة على '
                'بيئة تجريبية قبل استبدال البيانات الأصلية.',
          ),
          const SizedBox(height: 8),
          Text(
            'آخر تحديث: 13 يوليو 2026',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(height: 1.6)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
