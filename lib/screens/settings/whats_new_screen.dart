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
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      const ReleaseVersion(
        version: 'v4.2.0-alpha.5 · P1.9',
        title: 'النسخ الخلفي والواجهات المرنة',
        color: Color(0xFF1F6B5D),
        features: [
          FeatureItem(
            icon: Icons.backup_outlined,
            title: 'نسخ احتياطي والجوال مغلق',
            description:
                'جدولة نسخة محلية مشفرة بعد الساعة المحددة عبر نظام Android، مع حالة تشغيل واضحة ومسار احتياطي عند فتح التطبيق.',
          ),
          FeatureItem(
            icon: Icons.text_increase_outlined,
            title: 'دعم تكبير خط النظام',
            description:
                'تحويل صفوف المعلومات والأزرار تلقائياً إلى تخطيط عمودي مريح عند ضيق الشاشة أو تكبير الخط.',
          ),
          FeatureItem(
            icon: Icons.view_agenda_outlined,
            title: 'تسميع ومراجعة أكثر ثباتاً',
            description:
                'مرونة شريط التقدم وأزرار السابق والتالي والتوقف وملخص نطاق المراجعة دون إخفاء عناصر التحكم.',
          ),
          FeatureItem(
            icon: Icons.rule_folder_outlined,
            title: 'إجراءات ثانوية مرتبة',
            description:
                'نقل تصحيح وحذف المخالفات وقواعد النقاط إلى قوائم مدمجة لتبقى البيانات الأساسية واضحة.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.2.0-alpha.6 · P1.10',
        title: 'تثبيت الويب والنسخة المرشحة',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.check_circle_outline,
            title: 'جودة بلا تحذيرات',
            description:
                'إغلاق ملاحظات React ورفع بوابة ESLint إلى صفر تحذيرات حتى لا تتراكم مشكلات جديدة بصمت.',
          ),
          FeatureItem(
            icon: Icons.sync_lock_outlined,
            title: 'تأثيرات أكثر ثباتاً',
            description:
                'منع تكرار التحميل أو تحديث الشاشة بعد مغادرتها في الحضور والحفظ والقرعة والعائلات وخريطة المصحف.',
          ),
          FeatureItem(
            icon: Icons.web_asset_outlined,
            title: 'تصيير ويب آمن',
            description:
                'تهيئة لوحة التحكم بطريقة متوافقة مع الخادم والمتصفح دون إعادة رسم متسلسلة عند بداية التشغيل.',
          ),
          FeatureItem(
            icon: Icons.shield_outlined,
            title: 'بوابات مغلقة مباشرة',
            description:
                'تأكيد أن جداول اعتماد وجلسات الطالب والعائلة لا تُفتح بسياسات عامة، ويصل إليها النظام عبر الدوال الآمنة فقط.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.2.0-alpha.7 · P1.11',
        title: 'سلامة البيانات وقبول النسخة',
        color: Color(0xFF256D5A),
        features: [
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'فحص محلي للقراءة فقط',
            description:
                'يفحص العلاقات والتكرار وأكواد الطلاب والمقررات والإجازات والنطاقات القرآنية دون تغيير أي سجل.',
          ),
          FeatureItem(
            icon: Icons.privacy_tip_outlined,
            title: 'نتيجة آمنة للدعم',
            description:
                'يعرض نوع المشكلة وعدد الحالات فقط، دون أسماء الطلاب أو هواتفهم أو معرفاتهم أو ملاحظاتهم.',
          ),
          FeatureItem(
            icon: Icons.android_outlined,
            title: 'قبول APK أوضح',
            description:
                'يدعم فحص نسخة debug أو release، ويتحقق من التوقيع عند توفر apksigner ويحفظ بصمة SHA-256.',
          ),
          FeatureItem(
            icon: Icons.cloud_done_outlined,
            title: 'ربط نتيجة Supabase',
            description:
                'يمكن إرفاق CSV الناتج من استعلام الجاهزية الآمن لإيقاف القبول تلقائياً عند وجود فحص غير ناجح.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.2.0-alpha.8 · P1.12',
        title: 'جاهزية التشغيل والقبول الفعلي',
        color: Color(0xFF315F57),
        features: [
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'قرار جاهزية واضح',
            description:
                'تجمع لوحة واحدة قاعدة البيانات وسلامة السجلات والنسخ والسحابة والحوادث وتبين الناجح والعائق والملاحظة.',
          ),
          FeatureItem(
            icon: Icons.devices_outlined,
            title: 'قبول مرتبط بالإصدار',
            description:
                'توثيق اختبارات الجهازين والاستعادة والعزل والطباعة وQR، مع إعادة القائمة تلقائياً عند إصدار نسخة جديدة.',
          ),
          FeatureItem(
            icon: Icons.security_outlined,
            title: 'فحص بوابات غير مضلل',
            description:
                'صفر سياسات لجداول الاعتماد والجلسات يظهر نجاحاً فقط عند تفعيل RLS وسحب وصول العميل المباشر.',
          ),
          FeatureItem(
            icon: Icons.share_outlined,
            title: 'تقرير جاهزية منقح',
            description:
                'يمكن نسخه أو مشاركته دون أسماء الطلاب أو الهواتف أو المعرفات أو الملاحظات أو رموز الجلسات.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.1 · P1.13',
        title: 'إغلاق اليوم والتشغيل الآمن',
        color: Color(0xFF1F6B5D),
        features: [
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'مراجعة يومية قبل الاعتماد',
            description:
                'يعرض من لم يسجل حضوره، والغائب، ومن حضر ولم يسمّع، والاستثناءات قبل أي احتساب تلقائي.',
          ),
          FeatureItem(
            icon: Icons.lock_clock_outlined,
            title: 'إغلاق ذري لا يتكرر',
            description:
                'ينفذ بعد الدوام فقط، ويكتب الحضور والنقاط وعلامة الإغلاق في معاملة واحدة دون نتائج جزئية.',
          ),
          FeatureItem(
            icon: Icons.web_outlined,
            title: 'تدقيق مقابل في الويب',
            description:
                'لوحة مرتبة أبجديًا تكشف النواقص وتنتقل مباشرة لاستكمال الحضور أو التسميع.',
          ),
          FeatureItem(
            icon: Icons.security_outlined,
            title: 'دخول وتواصل أكثر أمانًا',
            description:
                'إرسال متابعة ولي الأمر عبر واتساب فعليًا، ومنع الدخول الوهمي عند نقص إعداد Supabase.',
          ),
          FeatureItem(
            icon: Icons.phone_android_outlined,
            title: 'رئيسية مرنة',
            description:
                'تتكيف بطاقات الإحصاءات والمهام مع الشاشة الصغيرة وتكبير الخط لتقليل أخطاء overflow.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.2 · P1.14',
        title: 'الإغلاق السحابي ودوام الحلقة',
        color: Color(0xFF176B5B),
        features: [
          FeatureItem(
            icon: Icons.cloud_done_outlined,
            title: 'إغلاق ذري في الويب',
            description:
                'يعتمد الحضور والتسميع والإجازات والنقاط داخل معاملة Supabase واحدة ويعيد الإيصال نفسه عند تكرار الطلب.',
          ),
          FeatureItem(
            icon: Icons.event_busy_outlined,
            title: 'تعليق دراسة سحابي بسبب موثق',
            description:
                'يتزامن يوم التعليق وسببه بين الأجهزة ويظهر في الحضور والتقارير ويمنع الغياب والعقوبات.',
          ),
          FeatureItem(
            icon: Icons.schedule_outlined,
            title: 'دوام وإجازة أسبوعية',
            description:
                'يمكن تحديد وقت نهاية الحلقة والمنطقة الزمنية وأيام الإجازة، والجمعة مفعلة افتراضيًا.',
          ),
          FeatureItem(
            icon: Icons.balance_outlined,
            title: 'عقوبات متوازنة',
            description:
                'تبقى عقوبة الغياب أشد من اجتماع التأخر وعدم إتمام المقرر وعدم لبس الثوب.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'مصدر تسميع موحد',
            description:
                'تعترف مراجعة اليوم بسجل التقييم الحديث والقديم وتستثني الموقوف عن التسميع دون إعفائه من الحضور.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.3 · P1.15',
        title: 'الخطط الذكية والتقرير الإداري',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.track_changes_outlined,
            title: 'إنجاز الخطة محسوب من الواقع',
            description:
                'تعرض الخطة نسبة الإنجاز من الحفظ والمراجعة الفعليين بعد استبعاد أيام التعليق والعطلة والإجازة والتوقيف.',
          ),
          FeatureItem(
            icon: Icons.chrome_reader_mode_outlined,
            title: 'مقرر ثالث للسرد والتلاوة',
            description:
                'أضيف مقرر سرد مستقل إلى الخطة الأسبوعية والشهرية وطباعة A4 والكاشير والطباعة الجماعية.',
          ),
          FeatureItem(
            icon: Icons.assessment_outlined,
            title: 'تقرير إداري مفصل',
            description:
                'يفصل الغياب والاستئذان والتأخر والمخالفات، ويعرض وقت التأخر والتقييم اليومي وترتيب الثلاثة الأوائل.',
          ),
          FeatureItem(
            icon: Icons.qr_code_scanner_outlined,
            title: 'مركز إجراءات QR',
            description:
                'يفتح رمز الطالب إجراءات التحضير والغياب والاستئذان والحفظ والمراجعة والإجازة من مكان واحد.',
          ),
          FeatureItem(
            icon: Icons.balance_outlined,
            title: 'نقاط متدرجة وتسوية موثقة',
            description:
                'تختلف نقاط الإنجاز باختلاف حجم المقرر والزيادة، ويمكن لسداد الصندوق تسوية رصيد سلبي دون حذف المخالفة الأصلية.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.7 · P1.17',
        title: 'مسار الخاتمين ومساحة مراجعة أسرع',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.workspace_premium_outlined,
            title: 'الخاتم في مسار مستقل',
            description:
                'لا يظهر الخاتم في الحفظ الجديد ولا يُطبع له مقرر حفظ؛ تبقى المراجعة والسرد فقط في الشاشة والخطة ونسبة الإنجاز.',
          ),
          FeatureItem(
            icon: Icons.view_compact_alt_outlined,
            title: 'رئيسية مضغوطة وعملية',
            description:
                'جُمعت أرقام الطلاب والحضور والغياب في شريط صغير حتى تظهر المهام اليومية مباشرة دون تمرير طويل.',
          ),
          FeatureItem(
            icon: Icons.menu_book_outlined,
            title: 'مساحة مراجعة واسعة',
            description:
                'أصبحت السور والآيات محور الشاشة مع بحث سريع، وإعداد المقرر في لوحة مستقلة، وزر تسجيل ثابت فوق أزرار النظام.',
          ),
          FeatureItem(
            icon: Icons.lock_clock_outlined,
            title: 'إغلاق يوم تلقائي وآمن',
            description:
                'إذا تُرك اليوم دون اعتماد يُغلق عند منتصف الليل أو أول فتح تالٍ، مع استثناء العطلات والإجازات ومنع التكرار وتوثيق نوع الإغلاق.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.6 · P1.16.2',
        title: 'خطط دقيقة وإعداد ويب من خطوة واحدة',
        color: Color(0xFF2563EB),
        features: [
          FeatureItem(
            icon: Icons.record_voice_over_outlined,
            title: 'جلسة سرد مستقلة',
            description:
                'يسجل المعلم التلاوة المرتبطة بالخطة دون أن تزيد محفوظ الطالب أو تختلط بسجل الحفظ.',
          ),
          FeatureItem(
            icon: Icons.route_outlined,
            title: 'سورة وآية لكل يوم',
            description:
                'تطبع الخطة الحفظ والمراجعة والتلاوة بنطاق قرآني صريح، ولا تقبل مقدار صفحات عامًا بلا موضع.',
          ),
          FeatureItem(
            icon: Icons.calendar_month_outlined,
            title: 'أشهر هجرية مستقرة',
            description:
                'أزيل تكرار قيم الأشهر الهجرية الذي كان يعطل حوار تصدير تقارير جميع الطلاب.',
          ),
          FeatureItem(
            icon: Icons.health_and_safety_outlined,
            title: 'الخطأ يبقى في موضعه',
            description:
                'تعطل خدمة مساندة أو جزء من الواجهة يسجل في التشخيص دون إغلاق التطبيق أو حجب بقية البيانات.',
          ),
          FeatureItem(
            icon: Icons.computer_outlined,
            title: 'إصلاح React وJSX بنقرة',
            description:
                'ملف Windows مباشر يثبت حزم الويب ويفحص React وNext وTypeScript سواء فُتح المشروع كاملًا أو مجلد website وحده.',
          ),
          FeatureItem(
            icon: Icons.donut_large_outlined,
            title: 'إنجاز بثلاثة محاور',
            description:
                'تجمع نسبة الخطة الحفظ والمراجعة والسرد، ولا تعتمد الإنجاز قبل استيفائها كلها.',
          ),
          FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'مزامنة وحماية سحابية',
            description:
                'يرتفع سجل السرد وينزل بين الأجهزة مع منع خلط الطالب والخطة والحلقة والتاريخ.',
          ),
          FeatureItem(
            icon: Icons.code_outlined,
            title: 'إعداد ويب موحد على Windows',
            description:
                'أمر واحد يعيد حزم React وNext المقفلة ويفحص TypeScript والبناء بعد فك المصدر.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.8 · P1.17.1',
        title: 'حفظ مباشر أو جلسة بعد مسح QR',
        color: Color(0xFF059669),
        features: [
          FeatureItem(
            icon: Icons.qr_code_scanner_outlined,
            title: 'مساران واضحان للحفظ',
            description:
                'بعد مسح رمز الطالب اختر جلسة تسميع آيةً آية، أو افتح تسجيل الحفظ مباشرة دون مؤقت أو جلسة.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'موضع الطالب جاهز للمراجعة',
            description:
                'يبدأ الحفظ المباشر من الموضع التالي والمقرر الشخصي، مع إمكان تعديل السورة والآيات والتقييم قبل الاعتماد.',
          ),
          FeatureItem(
            icon: Icons.web_outlined,
            title: 'التجربة نفسها على الويب',
            description:
                'نتيجة مسح الويب تتيح الحفظ المباشر أو الجلسة أو الاكتفاء بالحضور ومسح طالب آخر.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.9 · P1.17.2',
        title: 'إعدادات منظمة بلا تشتيت',
        color: Color(0xFF2563EB),
        features: [
          FeatureItem(
            icon: Icons.search_outlined,
            title: 'بحث وتقسيم حسب المهمة',
            description:
                'إعدادات الحلقة اليومية منفصلة عن الإدارة والحماية، ويمكن البحث عن النسخ أو الأوقات أو التشخيص مباشرة.',
          ),
          FeatureItem(
            icon: Icons.shield_outlined,
            title: 'ثلاث مساحات للبيانات',
            description:
                'النسخ والحماية، والمزامنة والاتصال، والخصوصية والسجل؛ لا تظهر العمليات الحساسة كلها دفعة واحدة.',
          ),
          FeatureItem(
            icon: Icons.admin_panel_settings_outlined,
            title: 'إدارة النظام للمدير',
            description:
                'بوابات واضحة لجاهزية التشغيل والتشخيص الفني وسجل التدقيق، بعيدًا عن إعدادات المعلم اليومية.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.12 · P1.19.1',
        title: 'إصلاح تشغيل نسخة الواجهة الجديدة',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.build_circle_outlined,
            title: 'استعادة بناء Flutter',
            description:
                'إصلاح غلاف محاذاة الشاشات وتمرير سياق الثيم في نتيجة الامتحان، حتى تعمل نسخة الواجهة الجديدة على الهاتف.',
          ),
          FeatureItem(
            icon: Icons.verified_outlined,
            title: 'حماية من تكرار الخطأ',
            description:
                'أضيف فحص إصدار يمنع رجوع خطأي الترجمة، دون تغيير بيانات الحلقة أو قاعدة البيانات.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.11 · P1.19',
        title: 'هوية موحدة ومساحة عمل أسرع',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.space_dashboard_outlined,
            title: 'الرئيسية تبدأ بالعمل',
            description:
                'تظهر متابعة اليوم والحضور والتسميع والإغلاق قبل الإحصاءات والأدوات الثانوية، بمساحات مناسبة للهاتف.',
          ),
          FeatureItem(
            icon: Icons.auto_stories_outlined,
            title: 'تسجيل حفظ أوضح',
            description:
                'يمر الحفظ المباشر بالطالب والنطاق والتقييم والاعتماد في تسلسل بصري واحد مع زر رئيس واضح.',
          ),
          FeatureItem(
            icon: Icons.dark_mode_outlined,
            title: 'وضع داكن مقروء',
            description:
                'تتبع النصوص الثانوية والحدود والمدخلات ألوان الثيم، وأزيلت الرماديات الثابتة منخفضة التباين.',
          ),
          FeatureItem(
            icon: Icons.speed_outlined,
            title: 'استجابة أخف',
            description:
                'تُحمّل البيانات المستقلة بالتوازي، وتستمع واجهات الويب إلى أجزاء الحالة التي تحتاجها فقط.',
          ),
          FeatureItem(
            icon: Icons.devices_outlined,
            title: 'هوية واحدة للهاتف والويب',
            description:
                'الألوان والمسافات والزوايا والظلال والتنقل أصبحت متسقة في جميع المسارات دون تغيير بيانات الحلقة.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.13 · P1.20',
        title: 'تشغيل متكامل دون إنترنت ومتابعة أوسع',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.grid_view_rounded,
            title: 'مهام يومية في شبكة عملية',
            description:
                'تظهر إجراءات الحضور والتسميع والإغلاق والطلاب والتقارير والخطط في شبكة مضغوطة تستغل عرض الهاتف.',
          ),
          FeatureItem(
            icon: Icons.analytics_outlined,
            title: 'تقارير تعمل من أول ضغطة',
            description:
                'لوحة أداء للحلقة، وفترات يومية وأسبوعية وشهرية، وتقرير شامل وسند استلام في شاشات مستقلة بلا شاشة سوداء.',
          ),
          FeatureItem(
            icon: Icons.wifi_tethering_outlined,
            title: 'تبادل مشفر دون إنترنت',
            description:
                'إرسال حزمة محلية عبر المشاركة القريبة أو Wi‑Fi Direct أو البلوتوث ودمجها في هاتف المركز بكود ربط.',
          ),
          FeatureItem(
            icon: Icons.emoji_events_outlined,
            title: 'المسابقات والتحكيم',
            description:
                'إنشاء مسابقة، توليد أسئلة للطالب، تسجيل أخطاء التحكيم، حساب الدرجة، ثم عرض النتائج والترتيب.',
          ),
          FeatureItem(
            icon: Icons.replay_circle_filled_outlined,
            title: 'أنظمة مراجعة متعددة',
            description:
                'مراجعة متباعدة تكيفية، وتثبيت خمسة أيام، وسبق/سبقي/منزل، ونظام يحدده المعلم لكل طالب.',
          ),
          FeatureItem(
            icon: Icons.family_restroom_outlined,
            title: 'بوابة أسرة وتوجيه إشرافي',
            description:
                'متابعة تتجدد آليًا للحضور والحفظ والسلوك، مع جدولة وتوثيق زيارات الموجه للمراكز.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.14 · P1.21',
        title: 'تقارير ولي الأمر الدورية وتبادل محلي أقوى',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.schedule_send_outlined,
            title: 'تقارير أسبوعية أو شهرية',
            description:
                'تُنشئ الحلقة تقارير تاريخية بموافقة ولي الأمر، وتنشرها تلقائيًا داخل بوابة العائلة دون أن تتأثر بانقطاع مزود الإرسال.',
          ),
          FeatureItem(
            icon: Icons.family_restroom_outlined,
            title: 'سجل تقارير داخل البوابة',
            description:
                'يعرض ولي الأمر التقارير المنشورة لكل أبنائه إلى جانب المتابعة الآنية للحضور والحفظ والسلوك.',
          ),
          FeatureItem(
            icon: Icons.mail_outline,
            title: 'تكامل خارجي آمن',
            description:
                'صف إرسال قابل لإعادة المحاولة وتوقيع HMAC لمزود بريد أو رسائل يختاره المشغل، من دون وضع مفاتيح سرية في المتصفح.',
          ),
          FeatureItem(
            icon: Icons.phonelink_lock_outlined,
            title: 'حزمة تبادل مؤقتة',
            description:
                'كود ربط عشوائي من 12 رمزًا وصلاحية 30 دقيقة، مع فصل الكود عن الملف واستبعاد إعدادات الهاتف وسجل التدقيق.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.15 · P1.22',
        title: 'تشغيل يومي مرن ونشاط وتلقين وتسميع ممتد',
        color: Color(0xFF0D9488),
        features: [
          FeatureItem(
            icon: Icons.event_available_outlined,
            title: 'النشاط حضور مع إعفاء واضح',
            description:
                'يمكن تحضير الطالب في محاضرة أو نشاط أو دوري أو عشاء أو رياضة أو مسابقة ثقافية دون أن يظهر ضمن «لم يسمّع» لذلك اليوم.',
          ),
          FeatureItem(
            icon: Icons.record_voice_over_outlined,
            title: 'التلقين ومسارات السور المتصلة',
            description:
                'أضيف مسار تلقين مستقل، وأصبح الحفظ والتسميع يدعمان نطاقًا يبدأ في سورة وينتهي في سورة أخرى للسور المتتابعة.',
          ),
          FeatureItem(
            icon: Icons.pause_circle_outline,
            title: 'توقف مؤقت للدراسة أو العمل',
            description:
                'يمكن إيقاف التسميع فقط أو إيقاف حضور الطالب وتسميعه مؤقتًا، مع استبعاد التوقف الكامل من الغياب والعقوبات اليومية.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'مراجعة يومية أدق',
            description:
                'تظهر سور المحفوظ بعد تهيئة بيانات القرآن، وتُقسم مقترحات المراجعة في التثبيت الخماسي حسب الصفحات على أيام متوازنة.',
          ),
          FeatureItem(
            icon: Icons.group_work_outlined,
            title: 'انضباط وإدارة جماعية',
            description:
                'إسناد النقاط لعدة طلاب، وموازنة العقوبات من الإعدادات، وسجل إداري للإنذارات والتنبيهات والتعهدات والتواصل مع ولي الأمر.',
          ),
          FeatureItem(
            icon: Icons.login_outlined,
            title: 'المتابعة باستخدام Google',
            description:
                'أضيف Google OAuth للهاتف والويب؛ يحتاج التفعيل الفعلي إلى ضبط موفر Google وروابط الرجوع في Supabase قبل الاستخدام.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.16 · P1.23',
        title: 'PDF عربي سليم وواجهات أخف وأكثر اتساقًا',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.picture_as_pdf_outlined,
            title: 'خط عربي ثابت في PDF',
            description:
                'تستخدم جميع التقارير والخطط والاختبارات خط Tajawal المضمن بالعادي والعريض بدل الرجوع إلى خط لا يدعم العربية.',
          ),
          FeatureItem(
            icon: Icons.space_dashboard_outlined,
            title: 'واجهة مسطحة ومضغوطة',
            description:
                'بطاقات أخف وخطوط أصغر وأيقونات خطية ومسافات مدروسة مع شريط علوي كحلي ولون إجراء أخضر موحد.',
          ),
          FeatureItem(
            icon: Icons.auto_fix_high_outlined,
            title: 'تنظيف Flutter الحديث',
            description:
                'تحديث الأنماط المتقادمة التي ظهرت في flutter analyze وتنظيف الاستيرادات والعناصر غير المستخدمة الواردة في السجل.',
          ),
          FeatureItem(
            icon: Icons.speed_outlined,
            title: 'بداية تشغيل أنعم',
            description:
                'يظهر الإطار الأول قبل تحميل بيانات الرئيسية الأثقل لتقليل التقطيع الملحوظ عند بدء التطبيق.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.17 · P1.24',
        title: 'تعلم مرن وتقارير RTL ودورات قرآنية',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.palette_outlined,
            title: 'عودة ألوان حلقتي الأصلية',
            description:
                'عادت الهوية الخضراء والذهبية الدافئة مع الإبقاء على توزيع ومساحات وتنقل P1.23 الخفيف.',
          ),
          FeatureItem(
            icon: Icons.picture_as_pdf_outlined,
            title: 'بداية توحيد PDF وRTL',
            description:
                'وحّدت P1.24 اتجاه التقارير والجداول، ثم كشف اختبار الجهاز أن Readex Pro المتغير غير موثوق داخل محرك PDF؛ استُبدل تقنيًا في P1.25 بخط عربي ثابت للتصدير فقط.',
          ),
          FeatureItem(
            icon: Icons.rule_folder_outlined,
            title: 'سلوك متعدد الأسباب',
            description:
                'اختيار أكثر من مخالفة أو مكافأة وإسناد كل سبب بنقاطه إلى طالب أو عدة طلاب داخل عملية ذرية واحدة.',
          ),
          FeatureItem(
            icon: Icons.tune_outlined,
            title: 'وحدات مستقلة للحفظ والمراجعة',
            description:
                'يمكن أن يكون حفظ الطالب بالأسطر أو الآيات، بينما تكون مراجعته بالأوجه أو بوحدة أخرى مستقلة، مع مرحلة تلقين صريحة.',
          ),
          FeatureItem(
            icon: Icons.quiz_outlined,
            title: 'إدارة الاختبارات والتقارير',
            description:
                'حذف وطباعة الامتحان الشفهي والتحريري، وإظهار اختبارات الفترة أو الشهر في تقرير الطالب وWhatsApp وPDF.',
          ),
          FeatureItem(
            icon: Icons.event_repeat_outlined,
            title: 'دورات الحفظ والمراجعة',
            description:
                'دورات محددة المدة والأيام، بمسار حفظ أو مراجعة أو كليهما، ومقررات يومية مستقلة ومجموعة طلاب محددة.',
          ),
          FeatureItem(
            icon: Icons.verified_outlined,
            title: 'نقاط تلقائية أدق',
            description:
                'لا نقاط إيجابية للمقرر الناقص، والإتمام له مكافأة واحدة، والزيادة الحقيقية فقط لها مكافأة إضافية.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.18 · P1.25',
        title: 'توافق سحابي آمن وPDF عربي ثابت وأداء أخف',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'فحص Supabase قبل أي إصلاح',
            description:
                'أصبح تحديث السحابة يبدأ بفحص قراءة فقط يحدد الجداول وأنواع المفاتيح؛ يتوقف عند أي مخطط غير متوافق بدل افتراض وجود students أو تغيير البيانات بالتخمين.',
          ),
          FeatureItem(
            icon: Icons.picture_as_pdf_outlined,
            title: 'خط عربي ثابت لمحرك PDF',
            description:
                'تبقى واجهة التطبيق على Readex Pro، بينما تستخدم التقارير Tajawal الثابت بالعادي والعريض مع RTL صريح وعكس صحيح لأعمدة الجداول لتجنب الرموز واختلاط الحروف.',
          ),
          FeatureItem(
            icon: Icons.health_and_safety_outlined,
            title: 'اختبار PDF عربي سريع',
            description:
                'أضيف زر داخل التشخيص لإنشاء صفحة عربية قصيرة واختبار الخط والتشكيل قبل تصدير تقرير طالب أو نموذج اختبار كامل.',
          ),
          FeatureItem(
            icon: Icons.calculate_outlined,
            title: 'نقاط تلقائية قابلة للتدقيق',
            description:
                'حساب الوجه والحزب يعتمد كمية الأسطر الفعلية، وتُجمد قاعدة المكافأة المستخدمة تاريخيًا حتى لا يغيّر تعديل الإعدادات نقاط يوم سابق.',
          ),
          FeatureItem(
            icon: Icons.speed_outlined,
            title: 'تقليل N+1 في التقارير والمزامنة',
            description:
                'أضيفت فهارس SQLite وعمليات batch للحضور والعائلات والسلوك والإجازات والاختبارات والتلقين والإداريات والصندوق والإشعارات والدورات لتقليل القراءة والكتابة صفًا بصف.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: 'تدقيق ما تبقى قبل الإطلاق',
            description:
                'فُصلت الميزات الموجودة في المصدر عن اختبارات القبول الخارجية؛ المتبقي الحقيقي هو اختبار Flutter والجهازين والطباعة وRLS والنسخ والاستعادة على البيئة الفعلية.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.19 · P1.26',
        title: 'خط أوضح وصيانة المسابقات وفحص سحابي أعمق',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.text_fields_outlined,
            title: 'Tajawal موحّد للواجهة والتقارير',
            description:
                'أصبح خط الواجهة والتقارير PDF هو Tajawal الثابت نفسه، مع تحسين تباين النصوص في الوضعين الفاتح والداكن وإزالة الاعتماد على خطوط غير معلنة داخل بعض الشاشات.',
          ),
          FeatureItem(
            icon: Icons.emoji_events_outlined,
            title: 'تعديل وحذف المسابقات',
            description:
                'يمكن تعديل اسم المسابقة وفئتها أو حذفها بعد تأكيد واضح، مع حذف النتائج التابعة ذريًا وعدم تنفيذ استعلام منفصل لكل مسابقة عند عرض العدد.',
          ),
          FeatureItem(
            icon: Icons.contrast_outlined,
            title: 'تباين أفضل في الوضعين',
            description:
                'عولجت الأسطح والنصوص الرمادية الثابتة في الشاشات الأعلى استخدامًا لتأخذ ألوان ColorScheme المناسبة تلقائيًا في الوضع الفاتح والداكن.',
          ),
          FeatureItem(
            icon: Icons.storage_outlined,
            title: 'تدقيق Supabase عميق قبل الإصلاح',
            description:
                'عند ظهور STOP_BASE_SCOPE_MISSING لا يُشغّل migration الإصلاحي؛ يحدد فحص P1.26 أولًا هل المشروع فارغ فعلًا أم يحتوي مخططًا جزئيًا يحتاج جسر توافق خاصًا.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.20 · P1.26 Build 74',
        title: 'تقوية الأمان والاستقرار وإصلاح بوابة الإشراف',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.supervisor_account_outlined,
            title: 'إصلاح جاهزية الجهات الإشرافية',
            description:
                'أضيف فحص جاهزية واضح وترحيل إصلاحي يعيد مصالحة عضوية المالك وصلاحيات RLS وRPC دون إعادة إنشاء الجهة أو فقد بياناتها.',
          ),
          FeatureItem(
            icon: Icons.today_outlined,
            title: 'تاريخ يوم محلي موحّد',
            description:
                'تستخدم صفحات الويب تاريخ الجهاز المحلي للأعمال اليومية بدل UTC حتى لا ينتقل الحضور والتسميع والنقاط إلى اليوم السابق قرب منتصف الليل.',
          ),
          FeatureItem(
            icon: Icons.security_outlined,
            title: 'فصل بيئات Supabase وQR القديم',
            description:
                'أصبحت builds الإنتاجية تتطلب إعداد Supabase صريحًا، كما أوقف مفتاح QR القديم المضمّن وأصبح مسار التوافق اختياريًا ومحدود الصلاحية.',
          ),
          FeatureItem(
            icon: Icons.account_tree_outlined,
            title: 'عمليات أسر ذرّية وبنية أسهل للصيانة',
            description:
                'نُقلت دورة مخطط SQLite إلى وحدة مستقلة، وأصبحت عمليات الأسرة متعددة الخطوات RPC ذرّية لتجنب الحالات الجزئية عند فشل الشبكة.',
          ),
          FeatureItem(
            icon: Icons.fact_check_outlined,
            title: '56 بوابة تحقق للإصدار',
            description:
                'أضيف فحص Build 74 للتاريخ المحلي، السجلات الآمنة، Supabase، QR، عقود SQL، selectors في Zustand، ومتطلبات المصدر قبل الإصدار.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.21 · P1.27 Build 75',
        title: 'مزامنة بلا فقد ومتابعة إشرافية وخطط أذكى',
        color: Color(0xFF176B57),
        features: [
          FeatureItem(
            icon: Icons.account_balance_outlined,
            title: 'الجهة الإشرافية تنشئ المركز وتتابعه',
            description:
                'يمكن لمالك الجهة أو إداريها إنشاء مركز تابع مباشرة من بوابة الإشراف، مع استمرار لوحة المتابعة والزيارات والفريق ورسائل صلاحية دقيقة بدل رسالة P7.3 العامة.',
          ),
          FeatureItem(
            icon: Icons.percent_outlined,
            title: 'نقاط التسميع بحسب نسبة إنجاز المقرر',
            description:
                'يأخذ الطالب جزءًا من مكافأة المقرر عند التسميع الجزئي، وتصل المكافأة الكاملة عند 100% فقط، ثم تبدأ مكافأة الزيادة بعد تجاوز المقرر.',
          ),
          FeatureItem(
            icon: Icons.auto_stories_outlined,
            title: 'المحفوظ يُستنتج من اتجاه الطالب',
            description:
                'يكفي تحديد اتجاه الحفظ ثم تسجيل أول محفوظ فعلي؛ يستنتج النظام الرصيد المتصل خلف موضع الطالب ويستخدمه في المراجعة والتقارير بدل اشتراط إدخال محفوظ سابق يدويًا.',
          ),
          FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'مزامنة تلقائية وحذف لا يعود من جهاز آخر',
            description:
                'تعمل المزامنة عند بدء التطبيق وعودة الاتصال واستئناف التطبيق، وتسبق الرفعَ سجلاتُ حذف سحابية دائمة حتى لا يعيد جهاز كان دون إنترنت سجلًا حُذف من السحابة.',
          ),
          FeatureItem(
            icon: Icons.event_busy_outlined,
            title: 'الإجازة العارضة تنظف الإغلاق التلقائي',
            description:
                'إذا حُوّل يوم سابق إلى إجازة تُزال فقط الغيابات والعقوبات والإغلاقات التي يثبت النظام أنها أُنشئت تلقائيًا، وتبقى السجلات اليدوية محفوظة.',
          ),
          FeatureItem(
            icon: Icons.history_toggle_off_outlined,
            title: 'تسجيل متأخر حتى ثلاثة أيام',
            description:
                'يمكن إضافة الحفظ أو التسميع أو المراجعة لليوم أو للأيام الثلاثة السابقة، مع استخدام تاريخ السجل الحقيقي في الحضور والنقاط والخطة.',
          ),
          FeatureItem(
            icon: Icons.assignment_turned_in_outlined,
            title: 'اختبار الخطة الشهرية من 100',
            description:
                'ثلاثة أسئلة حفظ بـ30 وثلاثة مراجعة بـ30، و20 لإكمال خطة الحفظ و20 لإكمال خطة المراجعة، مع احتساب جزء الخطة تلقائيًا.',
          ),
          FeatureItem(
            icon: Icons.groups_2_outlined,
            title: 'مجموعات تنافس للمستويات المتقاربة',
            description:
                'يحدد المعلم عدد المجموعات ويجمع النظام الطلاب تلقائيًا حسب مقدار محفوظهم المستنتج ليكون التنافس بين أقران متقاربين.',
          ),
          FeatureItem(
            icon: Icons.calendar_month_outlined,
            title: 'اليوم والهجري والميلادي في الخطة',
            description:
                'تعرض خطط الطلاب اسم اليوم مع التاريخ الهجري والميلادي في الشاشة وPDF بدل الاكتفاء بتاريخ رقمي مجرد.',
          ),
          FeatureItem(
            icon: Icons.contrast_outlined,
            title: 'تباين أوضح وتشخيص أعطال أدق',
            description:
                'أصلحت تسميات الحفظ والمراجعة والتقييمات في الوضعين، وعولج انهيار محتمل عند غياب تقييمات الآيات، وأصبحت رسالة الجزء المتعطل تحمل رمز حادثة يمكن تتبعه.',
          ),
          FeatureItem(
            icon: Icons.share_outlined,
            title: 'ملفات المشاركة باسم حلقتي',
            description:
                'الصور والتقارير التي يولدها التطبيق للمشاركة تحمل اسم حلقتي، ووُحد اسم المنتج في Android وiOS والويب.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.22 · P1.27 Build 76',
        title: 'إكمال المزامنة والإشراف والمنافسة وجودة العرض',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.sync_lock_outlined,
            title: 'حذف ثنائي الطرف لا يعيد السجل المحذوف',
            description:
                'أضيف Outbox محلي على مستوى SQLite لمسارات السجلات القابلة للحذف، وتُطبّق Tombstones السحابية قبل الرفع، مع إعادة المحاولة سريعًا عند عودة الاتصال.',
          ),
          FeatureItem(
            icon: Icons.account_tree_outlined,
            title: 'تفاصيل إشرافية من المركز إلى الطالب',
            description:
                'أصبحت بوابة الجهة تعرض الحلقات ومؤشرات الحضور والحفظ والمراجعة ثم أداء الطلاب داخل المركز مع بقاء المحلل في وضع القراءة فقط.',
          ),
          FeatureItem(
            icon: Icons.emoji_events_outlined,
            title: 'ترتيب أسبوعي داخل مجموعات الأقران',
            description:
                'تحافظ المجموعات على تقارب المستوى وتعرض ترتيبًا أسبوعيًا بالحفظ الجديد والمراجعة والنقاط السلوكية مع تقدم كل طالب نحو متصدر مجموعته.',
          ),
          FeatureItem(
            icon: Icons.quiz_outlined,
            title: 'الاختبار الشهري مرتبط بالنموذج والأسئلة',
            description:
                'تُحفظ أسئلة 30+30 داخل exam_templates وexam_questions ويرتبط سجل الاختبار بالقالب، وتتزامن القوالب والأسئلة بين الأجهزة.',
          ),
          FeatureItem(
            icon: Icons.contrast_outlined,
            title: 'تباين Light/Dark محمي باختبارات',
            description:
                'أزيل تعارض لون تبويبات AppBar مع الخلفية، واستُخدمت أزواج ألوان دلالية للحفظ والمراجعة والأزرار، مع اختبار تباين للثيم الفاتح والداكن.',
          ),
          FeatureItem(
            icon: Icons.bug_report_outlined,
            title: 'الحادثة تسجل موضع العرض والعملية',
            description:
                'يحفظ ErrorWidget بصمة الحادثة وسياق الـWidget والعملية، وتظهر المعلومات المنقحة في شاشة التشخيص لتحديد مصدر العطل المتكرر.',
          ),
          FeatureItem(
            icon: Icons.tune_outlined,
            title: 'سياسة تقريب نقاط الإنجاز',
            description:
                'يمكن اختيار التقريب للأقرب أو لأسفل أو لأعلى عند تحويل نسبة إنجاز المقرر إلى نقاط صحيحة، مع بقاء الحد الأعلى هو مكافأة الإتمام.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.23 · P1.27 Build 77',
        title: 'تقارير أوضح وتجربة تشغيل أكثر ثباتًا',
        color: Color(0xFF6D28D9),
        features: [
          FeatureItem(
            icon: Icons.groups_2_outlined,
            title: 'مدخل مستقل لمجموعات المستوى المتقارب',
            description:
                'أصبحت المجموعات متاحة مباشرة من الرئيسية والقائمة الجانبية، وتعرض اسم نطاق السور والأجزاء حتى يعرف المعلم مستوى كل مجموعة بسرعة.',
          ),
          FeatureItem(
            icon: Icons.picture_as_pdf_outlined,
            title: 'تقرير تجميعي PDF من صفحة واحدة',
            description:
                'أعيد توزيع عناصر تقرير الحلقة على A4 أفقي واحد مع جدول جميع الطلاب وأسماء داكنة واضحة، وإعادة تصميم واجهة التقارير وبطاقات أنواع التقارير.',
          ),
          FeatureItem(
            icon: Icons.person_remove_alt_1_outlined,
            title: 'استثناء الطالب من ترتيب الأوائل فقط',
            description:
                'يمكن استبعاد طالب — ومنها المستجدون خلال فترة التقرير — من حساب الأوائل دون حذف بياناته أو إخراجه من إجماليات وتفاصيل التقرير.',
          ),
          FeatureItem(
            icon: Icons.auto_fix_high_outlined,
            title: 'مقترح المراجعة في مقدمة الفهرس',
            description:
                'يرتفع موضع المراجعة المقترح إلى مقدمة قائمة السور ويظهر باسم السورة في شريحة واضحة بجوار البحث بدل أن يضيع في آخر القائمة.',
          ),
          FeatureItem(
            icon: Icons.edit_note_outlined,
            title: 'تعديل معاملات صندوق الحلقة',
            description:
                'يمكن تعديل مبلغ المعاملة وبيانها وتاريخها بعد الإدخال مع الحفاظ على نوع المعاملة وارتباطاتها المحاسبية.',
          ),
          FeatureItem(
            icon: Icons.fit_screen_outlined,
            title: 'إغلاق حالات Overflow المرصودة',
            description:
                'أصبحت إجراءات QR والقرعة العشوائية ونافذة قاعدة النقاط وإضافة متميز اليوم قابلة للتمرير أو الالتفاف على الشاشات القصيرة.',
          ),
          FeatureItem(
            icon: Icons.health_and_safety_outlined,
            title: 'بدء تشغيل متسامح مع الأعطال المؤقتة',
            description:
                'لا يمنع فشل قراءة الثيم أو المهام السحابية التطبيق من البدء، وتضيف شاشة فشل البدء إعادة محاولة مباشرة مع الحفاظ على رمز الحادثة.',
          ),
          FeatureItem(
            icon: Icons.cloud_sync_outlined,
            title: 'أيقونة مزامنة متباينة دائمًا',
            description:
                'تستخدم أيقونة المزامنة لون AppBar الأمامي المعتمد حتى لا تختفي في الثيم الفاتح أو الداكن.',
          ),
        ],
      ),
      const ReleaseVersion(
        version: 'v4.3.0-alpha.24 · P1.27 Build 78',
        title: 'مجموعات عملية وتقارير شفافة وخطط أكثر مرونة',
        color: Color(0xFF0F766E),
        features: [
          FeatureItem(
            icon: Icons.groups_3_outlined,
            title: 'المجموعات أصبحت مساحة نشاط ومنافسة',
            description:
                'يمكن طباعة أسماء كل مجموعة، حفظ فعاليات خاصة بها، وبدء مسابقة مقيدة بأفراد المجموعة مع بقاء التسمية القرآنية حسب نطاق السور والأجزاء.',
          ),
          FeatureItem(
            icon: Icons.filter_alt_outlined,
            title: 'استثناءات قبل تصدير جميع تقارير الطلاب',
            description:
                'قبل إنشاء ملف PDF جماعي يمكن استثناء طلاب محددين أو المستجدين في الفترة؛ ولا تُنشأ صفحاتهم داخل ملف الدفعة أصلًا.',
          ),
          FeatureItem(
            icon: Icons.payments_outlined,
            title: 'المدفوعات داخل تقارير الطالب والحلقة',
            description:
                'تُقرأ مدفوعات الطالب تلقائيًا من صندوق الحلقة داخل نفس الفترة وتظهر في واجهة التقرير وPDF، مع تفصيل صفحات الحفظ والمراجعة والسرد.',
          ),
          FeatureItem(
            icon: Icons.event_available_outlined,
            title: 'تنبيه الغائب والمستأذن قبل التسميع',
            description:
                'لا يعتمد النظام تسميعًا لطالب حالته غائب أو مستأذن إلا بعد تأكيد تحويله إلى حاضر، لمنع تضارب الحضور مع الإنجاز.',
          ),
          FeatureItem(
            icon: Icons.brightness_2_outlined,
            title: 'اختيار الفترة بالتقويم الهجري أو الميلادي',
            description:
                'أضيف منتقي هجري مرئي بجانب المنتقي الميلادي للتقارير والخطط، مع تصميم قابل للتمرير على الشاشات القصيرة.',
          ),
          FeatureItem(
            icon: Icons.auto_fix_high_outlined,
            title: 'مصالحة محفوظ الطلاب القدامى',
            description:
                'تُستنتج خريطة المحفوظ المتصلة مرة واحدة من سجلات الحفظ القديمة واتجاه الطالب، دون الكتابة فوق التقييمات الموجودة.',
          ),
          FeatureItem(
            icon: Icons.calendar_view_week_outlined,
            title: 'الجمعة: تدارك وسرد أو خطة كاملة أو إجازة',
            description:
                'يمكن اختيار سياسة الجمعة لكل خطة: تدارك الفائت مع سرد فقط افتراضيًا، أو يوم خطة كامل، أو إجازة.',
          ),
          FeatureItem(
            icon: Icons.emoji_events_outlined,
            title: 'مسابقات الجهة الإشرافية',
            description:
                'تنشئ الجهة المسابقة وفئاتها، ترشح المراكز طلابها، وتسجل الجهة التحكيم والأخطاء والنتائج من بوابتها ضمن صلاحيات RLS وRPC محمية.',
          ),
          FeatureItem(
            icon: Icons.rule_outlined,
            title: 'مقترحات المراجعة قابلة للتعديل',
            description:
                'لم تعد سور الخطة المقترحة محددة إلزاميًا؛ يستطيع المعلم إلغاء أي اختيار واعتماد ما سمعه الطالب فعليًا.',
          ),
          FeatureItem(
            icon: Icons.calculate_outlined,
            title: 'نقاط نسبية عشرية حقيقية',
            description:
                'أصبح الوضع الافتراضي يحفظ النسبة الفعلية مثل 2.5 نقطة بدل إجبارها إلى عدد صحيح، مع بقاء أوضاع التقريب اختيارية.',
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
                color: release.color.withValues(alpha: isDark ? 0.15 : 0.08),
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
                            color: release.color.withValues(alpha: isDark ? 0.12 : 0.05),
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
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
