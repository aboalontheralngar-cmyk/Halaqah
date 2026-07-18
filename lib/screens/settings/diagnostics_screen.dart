import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/build_info.dart';
import '../../services/diagnostic_center_service.dart';

class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  final DiagnosticCenterService _service = DiagnosticCenterService();
  late Future<DiagnosticSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _service.collect();
  }

  Future<void> _reload() async {
    final next = _service.collect();
    setState(() => _snapshot = next);
    await next;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز التشخيص والدعم'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة الفحص',
          ),
        ],
      ),
      body: FutureBuilder<DiagnosticSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _failureState();
          }
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _privacyNotice(),
                const SizedBox(height: 12),
                _actions(data),
                const SizedBox(height: 12),
                _systemCard(data),
                const SizedBox(height: 12),
                _cloudCard(data),
                const SizedBox(height: 12),
                _backupCard(data),
                const SizedBox(height: 12),
                _recordsCard(data),
                const SizedBox(height: 12),
                _incidentsCard(data),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _failureState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 52,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 12),
              const Text(
                'تعذر جمع معلومات التشخيص',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
              const SizedBox(height: 8),
              const Text(
                'لم تُغيّر أي بيانات. أعد المحاولة أو أعد فتح التطبيق.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );

  Widget _privacyNotice() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.privacy_tip_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'تقرير الدعم منقح: لا يتضمن أسماء الطلاب أو الهواتف أو الملاحظات أو كلمات المرور أو رموز الجلسات.',
              ),
            ),
          ],
        ),
      );

  Widget _actions(DiagnosticSnapshot data) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () {
              Share.share(
                data.toSupportReport(),
                subject: 'تقرير تشخيص حلقتي ${AppBuildInfo.displayVersion}',
              );
            },
            icon: const Icon(Icons.share_outlined),
            label: const Text('مشاركة تقرير الدعم'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: data.toSupportReport()),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ التقرير المنقح')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('نسخ'),
          ),
        ],
      );

  Widget _systemCard(DiagnosticSnapshot data) => _sectionCard(
        title: 'التطبيق والجهاز',
        icon: Icons.phone_android_outlined,
        children: [
          _detailRow('الإصدار', AppBuildInfo.displayVersion),
          _detailRow('النظام', data.operatingSystem),
          _detailRow('إصدار النظام', data.operatingSystemVersion),
          _detailRow('SQLite', '${data.databaseVersion}'),
        ],
      );

  Widget _cloudCard(DiagnosticSnapshot data) {
    final healthy = data.cloudConnection.isHealthy;
    return _sectionCard(
      title: 'السحابة والمزامنة',
      icon: healthy ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
      iconColor: healthy ? Colors.green : Theme.of(context).colorScheme.error,
      children: [
        _detailRow('الحالة', data.cloudConnection.title),
        _detailRow('النطاق', data.cloudConnection.host),
        _detailRow(
          'الاستجابة',
          data.cloudConnection.httpStatus?.toString() ?? 'غير متوفرة',
        ),
        _detailRow(
          'زمن الفحص',
          '${data.cloudConnection.elapsed.inMilliseconds} ms',
        ),
        _detailRow(
          'تسجيل الدخول',
          data.cloudAuthenticated ? 'متصل' : 'غير متصل',
        ),
        _detailRow('آخر اتجاه', data.lastSyncDirection),
        _detailRow('آخر رفع', _date(data.lastCloudUploadAt)),
        _detailRow('آخر تنزيل', _date(data.lastCloudDownloadAt)),
      ],
    );
  }

  Widget _backupCard(DiagnosticSnapshot data) => _sectionCard(
        title: 'سلامة النسخ',
        icon: Icons.shield_outlined,
        iconColor: data.hasAutomaticBackupError
            ? Theme.of(context).colorScheme.error
            : Colors.green,
        children: [
          _detailRow('النسخ المحلية', '${data.localBackupCount}'),
          _detailRow('آخر نسخة', _date(data.lastBackupAt)),
          _detailRow(
            'النسخ التلقائي',
            data.hasAutomaticBackupError
                ? 'يوجد خطأ يحتاج مراجعة'
                : 'لا يوجد خطأ معلق',
          ),
        ],
      );

  Widget _recordsCard(DiagnosticSnapshot data) => _sectionCard(
        title: 'أعداد السجلات المحلية',
        icon: Icons.storage_outlined,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: data.recordCounts.entries
                .map(
                  (entry) => Chip(
                    avatar: const Icon(Icons.data_usage_outlined, size: 16),
                    label: Text(
                      '${entry.key}: ${entry.value < 0 ? 'غير متوفر' : entry.value}',
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      );

  Widget _incidentsCard(DiagnosticSnapshot data) => _sectionCard(
        title: 'الحوادث البرمجية المنقحة',
        icon: Icons.bug_report_outlined,
        iconColor: data.incidents.isEmpty
            ? Colors.green
            : Theme.of(context).colorScheme.error,
        children: [
          if (data.incidents.isEmpty)
            const Text('لم تُسجل حوادث تشغيلية حديثة.')
          else
            ...data.incidents.take(10).map(
                  (incident) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.error_outline),
                    title: Text(
                      incident.fingerprint,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${incident.eventType} · ${incident.source}\n${_date(incident.createdAt)}',
                    ),
                    isThreeLine: true,
                  ),
                ),
        ],
      );

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Color? iconColor,
  }) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ...children,
            ],
          ),
        ),
      );

  Widget _detailRow(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 112,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(value)),
          ],
        ),
      );

  String _date(DateTime? value) {
    if (value == null) return 'غير متوفر';
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
