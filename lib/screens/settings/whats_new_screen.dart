import 'package:flutter/material.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الميزات الجديدة في التحديث'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Column(
              children: [
                Icon(Icons.stars, size: 64, color: Colors.amber),
                SizedBox(height: 12),
                Text(
                  'تحديث الميزات الكبرى v1.1.0',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  'تمت إضافة 5 ميزات متقدمة لتسهيل إدارة الحلقة ومتابعة الطلاب',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            context,
            icon: Icons.grade,
            color: Colors.green,
            title: '1. نظام التقييم المتطور بـ 5 مستويات',
            description:
                'واجهة تقييم تفصيلية عند إنهاء تسميع الطالب تتيح تسجيل التقييم بدقة (ممتاز، جيد جداً، جيد، مقبول، ضعيف) بالإضافة لعداد الأخطاء المباشر وحفظ الملاحظات الكتابية وتحديد نوع التسميع (حفظ جديد أو مراجعة).',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.map,
            color: Colors.blue,
            title: '2. خريطة المصحف التفاعلية',
            description:
                'عرض مرئي لتقدم الطالب مقسم على 60 حزب × 8 أثمان (480 ثُمن) مع تتبع فترات تراجع الحفظ (الخلايا الخضراء تشير لحفظ حديث، والأصفر لحفظ مضى عليه 14 يوماً، والأحمر لأكثر من شهر يحتاج مراجعة)، مع إمكانية تعيين الأثمان كمحفوظة مسبقاً يدوياً.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.description,
            color: Colors.teal,
            title: '3. تصدير تقارير إكسل (CSV)',
            description:
                'تصدير تقرير شامل لسجل الطالب (الحضور، التقييمات، السلوك، الامتحانات) أو تقرير كلي لجميع طلاب الحلقة بصيغة CSV تدعم اللغة العربية والترتيب من اليمين (RTL) ومشاركتها فوراً عبر واتساب والبريد.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.message,
            color: Colors.purple,
            title: '4. تخصيص ومشاركة قوالب الرسائل',
            description:
                'لوحة مخصصة في الإعدادات لكتابة وتخصيص قوالب الرسائل لولي الأمر مع دعم المتغيرات التلقائية مثل اسم الطالب وسورة الواجب والتقييم، مع خيار مشاركة الرسالة بضغطة زر فور حفظ التسميع.',
          ),
          _buildFeatureCard(
            context,
            icon: Icons.backup,
            color: Colors.orange,
            title: '5. النسخ الاحتياطي فائق السرعة',
            description:
                'إعادة تصميم كاملة لنظام النسخ الاحتياطي ليعمل في جزء من الثانية لجميع بيانات الحلقة (الطلاب، الحضور، التقييمات، المعاملات المالية، والخطط)، مع دعم مشاركة ملف النسخة الاحتياطية مباشرة.',
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('حسناً، فهمت'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
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
