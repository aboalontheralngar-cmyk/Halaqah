import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../services/sync/cloud_sync_progress.dart';

class CloudSyncProgressDialog extends StatelessWidget {
  final SupabaseService service;
  final CloudSyncDirection direction;

  const CloudSyncProgressDialog({
    super.key,
    required this.service,
    required this.direction,
  });

  String get _title => switch (direction) {
        CloudSyncDirection.uploadOnly => 'رفع بيانات الجهاز',
        CloudSyncDirection.downloadOnly => 'تنزيل بيانات السحابة',
        CloudSyncDirection.bidirectional => 'المزامنة الثنائية',
      };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_title),
      content: ValueListenableBuilder<CloudSyncProgress?>(
        valueListenable: service.syncProgress,
        builder: (context, progress, _) {
          final current = progress?.currentStage ?? 0;
          final total = progress?.totalStages ?? 1;
          final failed = progress?.state == CloudSyncProgressState.failed;
          final colorScheme = Theme.of(context).colorScheme;
          return SizedBox(
            width: 340,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: progress == null || current == 0
                      ? null
                      : progress.fraction,
                  color: failed ? colorScheme.error : null,
                ),
                const SizedBox(height: 16),
                Text(
                  progress?.stageLabel ?? 'تهيئة المزامنة...',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  progress == null
                      ? 'يرجى الانتظار'
                      : 'المرحلة $current من $total',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                if (failed && progress?.safeCode != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'رمز التشخيص: ${progress!.safeCode}',
                    style: TextStyle(
                      color: colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
