import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/build_info.dart';
import '../../services/operational_readiness_service.dart';

class OperationalReadinessScreen extends StatefulWidget {
  const OperationalReadinessScreen({super.key});

  @override
  State<OperationalReadinessScreen> createState() =>
      _OperationalReadinessScreenState();
}

class _OperationalReadinessScreenState
    extends State<OperationalReadinessScreen> {
  final OperationalReadinessService _service = OperationalReadinessService();
  late Future<OperationalReadinessReport> _report;
  bool _savingManualCheck = false;

  @override
  void initState() {
    super.initState();
    _report = _service.collect();
  }

  Future<void> _reload() async {
    final next = _service.collect();
    setState(() => _report = next);
    await next;
  }

  Future<void> _setManualCheck(String code, bool value) async {
    if (_savingManualCheck) return;
    setState(() => _savingManualCheck = true);
    try {
      await _service.setManualCheck(code, value);
      await _reload();
    } finally {
      if (mounted) setState(() => _savingManualCheck = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جاهزية التشغيل والإطلاق'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة الفحص',
          ),
        ],
      ),
      body: FutureBuilder<OperationalReadinessReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return _failureState();
          }
          final report = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _summaryCard(report),
                const SizedBox(height: 12),
                _actions(report),
                const SizedBox(height: 12),
                _section(
                  title: 'الفحوص التلقائية',
                  subtitle:
                      'تُقرأ من الجهاز والسحابة دون تنفيذ رفع أو تنزيل أو تعديل.',
                  checks: report.automaticChecks.toList(),
                ),
                const SizedBox(height: 12),
                _section(
                  title: 'اختبارات القبول الفعلية',
                  subtitle:
                      'فعّل البند فقط بعد تنفيذه فعليًا لهذه النسخة. يُعاد السجل تلقائيًا عند تغير رقم الإصدار.',
                  checks: report.manualChecks.toList(),
                  manual: true,
                ),
                const SizedBox(height: 12),
                _privacyNotice(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _summaryCard(OperationalReadinessReport report) {
    final color = report.blockedCount > 0
        ? Theme.of(context).colorScheme.error
        : report.pendingCount > 0 || report.warningCount > 0
            ? Colors.orange
            : Colors.green;
    final icon = report.blockedCount > 0
        ? Icons.gpp_bad_outlined
        : report.isReady
            ? Icons.verified_outlined
            : Icons.pending_actions_outlined;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 10),
            Text(
              report.statusLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'اجتاز ${report.passedCount} من ${report.checks.length} · '
              'عوائق ${report.blockedCount} · ملاحظات ${report.warningCount} · '
              'قبول متبقٍ ${report.pendingCount}',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: report.checks.isEmpty
                  ? 0
                  : report.passedCount / report.checks.length,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actions(OperationalReadinessReport report) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: () => Share.share(
              report.toSafeReport(),
              subject: 'جاهزية حلقتي ${AppBuildInfo.displayVersion}',
            ),
            icon: const Icon(Icons.share_outlined),
            label: const Text('مشاركة التقرير'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: report.toSafeReport()),
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم نسخ تقرير الجاهزية')),
              );
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('نسخ'),
          ),
        ],
      );

  Widget _section({
    required String title,
    required String subtitle,
    required List<OperationalReadinessCheck> checks,
    bool manual = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const Divider(height: 24),
            ...checks.map(
              (check) => manual
                  ? CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value:
                          check.state == OperationalReadinessState.passed,
                      onChanged: _savingManualCheck
                          ? null
                          : (value) =>
                              _setManualCheck(check.code, value ?? false),
                      title: Text(check.title),
                      subtitle: Text(check.description),
                    )
                  : ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _stateIcon(check.state),
                        color: _stateColor(check.state),
                      ),
                      title: Text(check.title),
                      subtitle: Text(check.description),
                      trailing: Text(
                        _stateLabel(check.state),
                        style: TextStyle(
                          color: _stateColor(check.state),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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
                'تقرير الجاهزية منقح ولا يتضمن أسماء الطلاب أو الهواتف أو المعرفات أو الملاحظات أو كلمات المرور أو رموز الجلسات.',
              ),
            ),
          ],
        ),
      );

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
              const Text('تعذر إكمال فحص الجاهزية'),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );

  IconData _stateIcon(OperationalReadinessState state) => switch (state) {
        OperationalReadinessState.passed => Icons.check_circle_outline,
        OperationalReadinessState.warning => Icons.warning_amber_outlined,
        OperationalReadinessState.blocked => Icons.cancel_outlined,
        OperationalReadinessState.pending => Icons.pending_outlined,
      };

  Color _stateColor(OperationalReadinessState state) => switch (state) {
        OperationalReadinessState.passed => Colors.green,
        OperationalReadinessState.warning => Colors.orange,
        OperationalReadinessState.blocked =>
          Theme.of(context).colorScheme.error,
        OperationalReadinessState.pending => Colors.blueGrey,
      };

  String _stateLabel(OperationalReadinessState state) => switch (state) {
        OperationalReadinessState.passed => 'ناجح',
        OperationalReadinessState.warning => 'ملاحظة',
        OperationalReadinessState.blocked => 'عائق',
        OperationalReadinessState.pending => 'متبقٍ',
      };
}
