import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/backup_service.dart';
import '../../services/offline_exchange_policy.dart';
import '../../widgets/app_design_widgets.dart';

class OfflineExchangeScreen extends StatefulWidget {
  const OfflineExchangeScreen({super.key});

  @override
  State<OfflineExchangeScreen> createState() => _OfflineExchangeScreenState();
}

class _OfflineExchangeScreenState extends State<OfflineExchangeScreen> {
  static const MethodChannel _channel =
      MethodChannel('halaqah/offline_exchange');
  final BackupService _backup = BackupService();

  bool _busy = false;
  String? _lastCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التبادل دون إنترنت')),
      body: AppScreenBody(
        scrollable: true,
        maxWidth: 720,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppPageIntro(
              title: 'نقل مشفر بين الأجهزة',
              subtitle:
                  'تبادل البيانات عبر المشاركة القريبة أو Wi‑Fi Direct أو البلوتوث، دون خادم أو إنترنت.',
              icon: Icons.wifi_tethering_outlined,
            ),
            const SizedBox(height: 18),
            const AppFocusPanel(
              eyebrow: 'آمن ومحلي',
              title: 'ملف مشفر + كود ربط مؤقت',
              description:
                  'يختار المرسل وسيلة النقل من قائمة أندرويد. يدمج الجهاز المستقبل السجلات الأحدث ولا يستبدل إعداداته.',
              icon: Icons.phonelink_lock_outlined,
            ),
            const SizedBox(height: 14),
            _stepCard(
              number: '1',
              title: 'إرسال من هاتف الحلقة',
              description:
                  'ينشئ التطبيق حزمة تشغيلية مشفرة صالحة 30 دقيقة ويعرض كود ربط مستقلًا.',
              icon: Icons.upload_file_outlined,
              action: FilledButton.icon(
                onPressed: _busy ? null : _send,
                icon: const Icon(Icons.share_outlined),
                label: const Text('إنشاء ومشاركة'),
              ),
            ),
            const SizedBox(height: 10),
            _stepCard(
              number: '2',
              title: 'استلام في هاتف المركز أو الإشراف',
              description:
                  'اختر الملف المستلم ثم أدخل كود الربط الظاهر في هاتف المرسل.',
              icon: Icons.download_for_offline_outlined,
              action: OutlinedButton.icon(
                onPressed: _busy ? null : _receive,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('اختيار ودمج ملف'),
              ),
            ),
            if (_lastCode != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('كود الربط لهذه الحزمة'),
                    const SizedBox(height: 6),
                    SelectableText(
                      OfflineExchangePolicy.formatCode(_lastCode!),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                letterSpacing: 3,
                              ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'أرسله شفهيًا أو اعرضه على الجهاز المستقبل فقط.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'مهم: هذه الطريقة تدمج البيانات التشغيلية بين نسخ التطبيق. '
              'لا تنقل حسابات Supabase ولا كلمات المرور ولا إعدادات الجهاز. '
              'عند توفر الإنترنت تبقى المزامنة السحابية هي الأنسب للعمل المتزامن المستمر.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepCard({
    required String number,
    required String title,
    required String description,
    required IconData icon,
    required Widget action,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(radius: 17, child: Text(number)),
                const SizedBox(width: 10),
                Icon(icon),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            action,
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      final code = OfflineExchangePolicy.generateCode();
      final filePath = await _backup.exportDeviceExchange(
        passphrase: OfflineExchangePolicy.passphrase(code),
      );
      if (!mounted) return;
      setState(() => _lastCode = code);
      await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'حزمة تبادل حلقتي',
        text: 'حزمة تبادل مشفرة من تطبيق حلقتي.\n'
            'اختر «استلام» في الجهاز الآخر وأدخل كود الربط الظاهر '
            'على هاتف المرسل. لا ترسل الكود مع الملف نفسه.',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إنشاء حزمة التبادل: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive() async {
    String? path;
    try {
      path = await _channel.invokeMethod<String>('pickHalaqahFile');
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'اختيار ملف التبادل متاح في نسخة أندرويد بعد إعادة بناء التطبيق.',
          ),
        ),
      );
      return;
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر اختيار الملف: ${error.message}')),
      );
      return;
    }
    if (path == null || !mounted) return;
    final code = await _requestCode();
    if (code == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دمج بيانات الجهاز؟'),
        content: const Text(
          'ستضاف السجلات الجديدة وتُحدّث السجلات الأقدم المطابقة. '
          'لن تُستبدل إعدادات هذا الهاتف أو حسابه السحابي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تحقق وادمج'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final result = await _backup.mergeBackup(
        path,
        passphrase: OfflineExchangePolicy.passphrase(code),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('اكتمل الدمج'),
          content: Text(
            'أضيف ${result['inserted'] ?? 0} سجل، '
            'وحُدّث ${result['updated'] ?? 0} سجل، '
            'وتُرك ${result['skipped'] ?? 0} سجل لأنه مطابق أو أقدم.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('حسنًا'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'فشل فتح الحزمة. تحقق من كود الربط ومن أن الملف صادر من حلقتي: $error',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _requestCode() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('كود الربط'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            maxLength: 14,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, letterSpacing: 3),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
              _UpperCaseTextFormatter(),
            ],
            decoration: const InputDecoration(
              hintText: 'ABCD-EFGH-JK23',
              counterText: '',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final code =
                    OfflineExchangePolicy.normalizeCode(controller.text);
                if (!OfflineExchangePolicy.isValidCode(code)) return;
                Navigator.pop(dialogContext, code);
              },
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}
