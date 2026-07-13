import 'package:flutter/material.dart';

import '../../models/audit_event.dart';
import '../../services/audit_log_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final AuditLogService _audit = AuditLogService();
  late Future<List<AuditEvent>> _events;

  @override
  void initState() {
    super.initState();
    _events = _audit.recent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التدقيق'),
        actions: [
          IconButton(
            onPressed: () => setState(() => _events = _audit.recent()),
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<List<AuditEvent>>(
        future: _events,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل سجل التدقيق'));
          }
          final events = snapshot.data ?? const <AuditEvent>[];
          if (events.isEmpty) {
            return const Center(
              child: Text('لا توجد أحداث حساسة مسجلة حتى الآن'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _eventCard(events[index]),
          );
        },
      ),
    );
  }

  Widget _eventCard(AuditEvent event) {
    final failed = event.outcome != 'success';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: failed
              ? Theme.of(context).colorScheme.errorContainer
              : Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            failed ? Icons.error_outline : _iconFor(event.eventType),
            color: failed
                ? Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          _labelFor(event.eventType),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatDate(event.createdAt)}'
          '${event.entityId == null ? '' : '\nالمعرف: ${event.entityId}'}',
        ),
        isThreeLine: event.entityId != null,
      ),
    );
  }

  IconData _iconFor(String eventType) {
    if (eventType.contains('cloud')) return Icons.cloud_outlined;
    if (eventType.contains('restore')) return Icons.restore;
    if (eventType.contains('passphrase')) return Icons.key_outlined;
    if (eventType.contains('pruned')) return Icons.auto_delete_outlined;
    return Icons.backup_outlined;
  }

  String _labelFor(String eventType) {
    const labels = <String, String>{
      'backup.created': 'إنشاء نسخة مشفرة',
      'backup.auto_created': 'إنشاء نسخة تلقائية مشفرة',
      'backup.restored': 'استعادة نسخة احتياطية',
      'backup.pruned': 'تنظيف نسخة محلية قديمة',
      'backup.cloud_uploaded': 'رفع نسخة مشفرة إلى السحابة',
      'backup.cloud_downloaded': 'تنزيل نسخة من السحابة',
      'backup.cloud_deleted': 'حذف نسخة سحابية',
      'backup.cloud_pruned': 'تنظيف نسخ سحابية قديمة',
      'backup.passphrase_changed': 'تغيير عبارة حماية النسخ',
      'backup.create_failed': 'فشل إنشاء نسخة',
      'backup.restore_failed': 'فشل استعادة نسخة',
      'backup.cloud_upload_failed': 'فشل رفع نسخة سحابية',
    };
    return labels[eventType] ?? eventType;
  }

  String _formatDate(DateTime value) {
    final date = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
