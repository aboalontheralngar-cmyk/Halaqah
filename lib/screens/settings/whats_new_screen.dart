import 'package:flutter/material.dart';

class WhatsNewScreen extends StatelessWidget {
  const WhatsNewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'سجل التحديثات والميزات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(
                    children: [
                      const Icon(Icons.stars, size: 64, color: Colors.amber),
                      const SizedBox(height: 12),
                      Text(
                        'دليل ميزات تطبيق حلقتي',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'عرض جميع الميزات المضافة للتطبيق من البداية وحتى اليوم مرتبة زمنياً',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildReleaseSections(context, isDark),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'حسناً، فهمت',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildReleaseSections(BuildContext context, bool isDark) {
    // Defining the releases from oldest to newest
    final List<ReleaseVersion> releases = [
      const ReleaseVersion(
        version: 'v0.1.0-alpha',
        title: 'الهيكل والنواة الأساسية',
        color: Colors.red,
        features: [
          FeatureItem(
            icon: Icons.storage_outlined,
            title: 'إدارة الطلاب المحلية (SQLite)',
            description: 'إضافة وتعديل وحذف الطلاب محلياً بالكامل وحفظ البيانات الشخصية وخطة الحفظ.',
          ),
          FeatureItem(
            icon: Icons.menu_book_outlined,
            title: 'خطة الحفظ والمقرر اليومي',
            description: 'دعم المقررات اليومية المتعددة: بالآيات، بالأسطر، أو بالصفحات.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'نظام التحضير البسيط',
            description: 'تسجيل الحضور والغياب اليومي للطلاب يدوياً وحفظ السجلات محلياً.',
          ),
          FeatureItem(
            icon: Icons.star_outline,
            title: 'تسجيل التسميع الأساسي',
            description: 'تسميع الطالب مع تحديد جودة حفظه (ممتاز، جيد جداً، مقبول، إلخ).',
          ),
          FeatureItem(
            icon: Icons.phone_android_outlined,
            title: 'تصميم مخصص للهواتف',
            description: 'واجهة مريحة وسريعة تعتمد اللون الزيتي الهادئ والملائم لبيئة الحلقات.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v0.5.0-beta',
        title: 'المزامنة السحابية والصندوق المالي',
        color: Colors.amber,
        features: [
          FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'المزامنة السحابية ثنائية الاتجاه',
            description: 'نظام مزامنة ذكي مع Supabase لمعرّفات UUID المعتمدة على الهاش لتجنب تكرار البيانات ودعم العمل دون إنترنت.',
          ),
          FeatureItem(
            icon: Icons.account_balance_wallet_outlined,
            title: 'نظام صندوق الحلقة المالي',
            description: 'إدارة المقبوضات والمدفوعات للصندوق مع تخصيص رمز العملة المحلي.',
          ),
          FeatureItem(
            icon: Icons.share_outlined,
            title: 'بطاقة التقرير اليومي الفاخرة',
            description: 'توليد ومشاركة بطاقة تقييم مميزة للطالب عبر الواتساب بتصميم إسلامي وجذاب.',
          ),
          FeatureItem(
            icon: Icons.visibility_off_outlined,
            title: 'واجهة التسميع المباشر التفاعلية',
            description: 'شاشة تسميع آية بآية مع إمكانية إخفاء وعرض النص القرآني للمعلم للمساعدة في التقييم وحفظ الأخطاء.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v0.9.0-beta',
        title: 'تجربة الاستخدام الفائقة والضبط المطور',
        color: Colors.orange,
        features: [
          FeatureItem(
            icon: Icons.bolt_outlined,
            title: 'التحضير التلقائي الفوري',
            description: 'تحضير الطالب تلقائياً بمجرد تسجيل تسميعه لحفظ وقت المعلم وضمان سرعة العمل.',
          ),
          FeatureItem(
            icon: Icons.timer_outlined,
            title: 'مؤقت التسميع والوقت المرجعي',
            description: 'مؤقت Stopwatch مدمج مع حساب الوقت المقترح تلقائياً بناءً على عدد الصفحات.',
          ),
          FeatureItem(
            icon: Icons.sort_by_alpha_outlined,
            title: 'فرز وتصفية الطلاب المرنة',
            description: 'إمكانية فرز الطلاب أبجدياً أو حسب إجمالي حفظهم الكلي لتسريع الوصول.',
          ),
          FeatureItem(
            icon: Icons.map_outlined,
            title: 'تحديد نطاق السور الحقيقي بدقة',
            description: 'اختيار دقيق لنطاق السور من سورة كذا إلى سورة كذا وبناء خريطة تقدم المصحف الحقيقي.',
          ),
          FeatureItem(
            icon: Icons.family_restroom_outlined,
            title: 'الربط العائلي الذكي والإخوة',
            description: 'اقتراح ذكي لبيانات وهاتف ولي الأمر بمجرد كتابة لقب الطالب لربط الإخوة.',
          ),
          FeatureItem(
            icon: Icons.filter_alt_outlined,
            title: 'الفلترة التفاعلية للتحضير وثبات التمرير',
            description: 'تصفية سريعة لحالات الحضور بنقرة واحدة، وحفظ موضع قائمة الطلاب عند التحديث.',
          ),
          FeatureItem(
            icon: Icons.security_outlined,
            title: 'دعم حماية الأبعاد وشاشات النوتش',
            description: 'تغليف كامل الواجهات بـ SafeArea لضمان ظهور عناصر التحكم بشكل سليم.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v1.0.0-rc1',
        title: 'إصدار ما قبل الإطلاق والاستقرار',
        color: Colors.teal,
        features: [
          FeatureItem(
            icon: Icons.check_circle_outline,
            title: 'تحديد المحفوظ المسبق بالآيات',
            description: 'تحديد آية البداية والنهاية للمحفوظ المسبق بدقة متناهية لبناء النسبة الفعلية للمصحف.',
          ),
          FeatureItem(
            icon: Icons.beach_access_outlined,
            title: 'الربط التلقائي للإجازات والتحضير',
            description: 'تحضير الطالب تلقائياً كـ "مستأذن" عند وجود إجازة فعالة وإظهار شارة برتقالية مميزة.',
          ),
          FeatureItem(
            icon: Icons.bug_report_outlined,
            title: 'إصلاح تداخل العناصر (Overflow)',
            description: 'معالجة مشاكل تداخل نصوص القوائم المنسدلة في الشاشات الصغيرة وتطبيق تحسينات شاملة.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v1.2.0',
        title: 'التخصيص والذكاء اللغوي وترقية المحفوظ المسبق',
        color: Colors.blue,
        features: [
          FeatureItem(
            icon: Icons.edit_note_outlined,
            title: 'تعديل المحفوظ المسبق للطلاب',
            description: 'إمكانية تعديل نطاق الحفظ المسبق للطلاب المسجلين وإعادة احتساب تقدم المصحف تلقائياً.',
          ),
          FeatureItem(
            icon: Icons.explore_outlined,
            title: 'معالج التهيئة الأولية والترحيب',
            description: 'شاشة إعداد ترحيبية لضبط إعدادات الحلقة الأساسية وتفاصيل المعلم عند فتح التطبيق لأول مرة.',
          ),
          FeatureItem(
            icon: Icons.g_translate_outlined,
            title: 'التكيف اللغوي التلقائي مع جنس الحلقة',
            description: 'تحوير لغوي ذكي لكامل نصوص التطبيق للتخاطب مع البنين أو البنات بشكل منفصل.',
          ),
          FeatureItem(
            icon: Icons.more_time_outlined,
            title: 'دعم تعدد تنسيقات الوقت',
            description: 'إتاحة خيارات عرض الوقت بتنسيق 12 ساعة أو 24 ساعة أو حسب إعدادات نظام الهاتف.',
          ),
          FeatureItem(
            icon: Icons.import_contacts_outlined,
            title: 'استيراد الأرقام من جهات الاتصال',
            description: 'استيراد رقم الطالب أو ولي الأمر مباشرة من جهات اتصال الهاتف بضغطة زر.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v1.3.0',
        title: 'التوقيت الديناميكي المرن وإدارة الإجازات المتقدمة',
        color: Colors.purple,
        features: [
          FeatureItem(
            icon: Icons.access_time_filled_outlined,
            title: 'جدولة الحلقة المتكيفة مع الصلوات وفصول السنة',
            description: 'ربط وقت بدء الحلقة بالصلوات اليومية محلياً بالكامل (مثل: بعد العصر بـ 15 دقيقة) ليتكيف ديناميكياً مع فصول السنة دون تدخل.',
          ),
          FeatureItem(
            icon: Icons.location_city_outlined,
            title: 'قاعدة بيانات جغرافية للبلاد وتقويم أم القرى',
            description: 'قاعدة بيانات مدمجة للمدن اليمنية والعربية مع إحداثياتها، واعتماد تقويم أم القرى كمعيار فلكي.',
          ),
          FeatureItem(
            icon: Icons.nightlight_round_outlined,
            title: 'توقيت رمضان الذكي والصلوات المخصصة',
            description: 'تحديد تلقائي لشهر رمضان هجرياً أو التفعيل يدوياً، مع ضبط إعدادات مستقلة لتوقيت حلقة رمضان.',
          ),
          FeatureItem(
            icon: Icons.edit_calendar_outlined,
            title: 'تعديل وتحديث إجازات الطلاب',
            description: 'إتاحة تعديل تفاصيل وتواريخ وأسباب الإجازات المبررة المسجلة مسبقاً للطلاب بكل مرونة.',
          ),
          FeatureItem(
            icon: Icons.casino_outlined,
            title: 'قرعة الطلاب العشوائية التفاعلية',
            description: 'نظام قرعة وتصفيات عشوائية تفاعلي مدعوم بالاهتزازات الحسية (Haptic Ticks) لتسهيل اختيار الطلاب وتسميعهم بعدالة دون تكرار.',
          ),
          FeatureItem(
            icon: Icons.exit_to_app_outlined,
            title: 'رسالة تأكيد خروج آمنة',
            description: 'حماية المستخدم من الخروج غير المقصود عبر اعتراض زر الرجوع وعرض نافذة تأكيد متوافقة مع الثيم والاتجاه العربي.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v1.4.0',
        title: 'ختم المصحف والمراجعة الدقيقة والنقاط التلقائية',
        color: Colors.green,
        features: [
          FeatureItem(
            icon: Icons.workspace_premium_outlined,
            title: 'خيار ختم المصحف الشريف كاملاً',
            description: 'زر سريع "ختم المصحف" عند تسجيل الطالب يقوم بتعبئة كامل نطاق المصحف (من الفاتحة للناس) تلقائياً لتسهيل إدارة طلاب الإجازة والحفظ الكامل.',
          ),
          FeatureItem(
            icon: Icons.zoom_in_outlined,
            title: 'المراجعة التفصيلية بالآيات',
            description: 'إتاحة تحديد نطاقات دقيقة للآيات المراد مراجعتها (من آية كذا إلى آية كذا) داخل كل سورة من السور المحفوظة، وحساب عدد الآيات المراجعة بدقة.',
          ),
          FeatureItem(
            icon: Icons.auto_awesome_outlined,
            title: 'منح نقاط تفوق تلقائية للزيادة عن المقرر',
            description: 'منح نقاط سلوك إيجابية تلقائياً للطلاب الذين يتجاوز تسميعهم أو حفظهم المقدار اليومي المقرر لهم من واقع إعدادات النقاط والسلوك.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v3.7.0-alpha',
        title: 'الهوية الموحدة وخفة الواجهات',
        color: Color(0xFF1F6B5D),
        features: [
          FeatureItem(
            icon: Icons.sync_alt_outlined,
            title: 'رفع وتنزيل سحابيان واضحان',
            description: 'اختيار صريح بين الرفع فقط والتنزيل فقط والمزامنة الثنائية، مع وقت مستقل لكل اتجاه ونسخة حماية قبل التنزيل.',
          ),
          FeatureItem(
            icon: Icons.font_download_outlined,
            title: 'خط Tajawal موحد ومحلي',
            description: 'توحيد نصوص وأرقام الواجهة بأربعة أوزان مضمنة تعمل دون تنزيل الخط من الإنترنت.',
          ),
          FeatureItem(
            icon: Icons.palette_outlined,
            title: 'هوية قرآنية هادئة',
            description: 'أخضر عميق وعاجي دافئ وذهبي خافت، مع بطاقات وحدود ومسافات أخف ووضع داكن متوازن.',
          ),
          FeatureItem(
            icon: Icons.security_outlined,
            title: 'Safe Area مركزية',
            description: 'حماية جميع الشاشات والحوارات والنوافذ السفلية من أزرار Android ومنطقة التنقل بالإيماءات.',
          ),
          FeatureItem(
            icon: Icons.view_compact_alt_outlined,
            title: 'تنقل أبسط وأوضح',
            description: 'توحيد القوائم وأشرطة التنقل والحقول والأزرار وإزالة المؤثرات الثقيلة أو المضللة.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.1.0-alpha.2 · RC2',
        title: 'التشخيص الآمن والجاهزية التشغيلية',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.health_and_safety_outlined,
            title: 'مركز التشخيص والدعم',
            description: 'ملخص لصحة SQLite والنسخ والمزامنة واتصال Supabase وأعداد السجلات دون عرض بيانات الطلاب.',
          ),
          FeatureItem(
            icon: Icons.bug_report_outlined,
            title: 'بصمات أعطال منقحة',
            description: 'التقاط أخطاء Flutter والمنصة برمز قصير دون تخزين نص الخطأ أو مسارات الجهاز أو بيانات الحلقة.',
          ),
          FeatureItem(
            icon: Icons.share_outlined,
            title: 'تقرير دعم قابل للمشاركة',
            description: 'نسخ أو مشاركة تقرير تقني يؤكد صراحة خلوه من الأسماء والهواتف والملاحظات وكلمات المرور والجلسات.',
          ),
          FeatureItem(
            icon: Icons.restart_alt_outlined,
            title: 'شاشة تعافٍ عند فشل البدء',
            description: 'رسالة آمنة تمنع المستخدم من حذف البيانات وتعرض رمز حادثة يمكن الرجوع إليه عند تعذر تشغيل التطبيق.',
          ),
        ],
      ),
    ];

    return releases.map((release) {
      return Card(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Version header banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: release.color.withOpacity(isDark ? 0.15 : 0.08),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: release.color,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      release.version,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      release.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Features list in version
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                children: release.features.map((feature) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: release.color.withOpacity(isDark ? 0.12 : 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(feature.icon, color: release.color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                feature.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                feature.description,
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 12,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class ReleaseVersion {
  final String version;
  final String title;
  final Color color;
  final List<FeatureItem> features;

  const ReleaseVersion({
    required this.version,
    required this.title,
    required this.color,
    required this.features,
  });
}

class FeatureItem {
  final IconData icon;
  final String title;
  final String description;

  const FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
  });
}
