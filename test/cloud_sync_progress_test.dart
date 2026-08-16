import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/sync/cloud_sync_progress.dart';

void main() {
  group('CloudSyncProgress', () {
    test('calculates bounded stage fraction', () {
      const progress = CloudSyncProgress(
        state: CloudSyncProgressState.running,
        stageId: 'students',
        stageLabel: 'الطلاب',
        currentStage: 3,
        totalStages: 12,
      );

      expect(progress.fraction, 0.25);
    });

    test('zero total stages produces zero progress', () {
      const progress = CloudSyncProgress(
        state: CloudSyncProgressState.preparing,
        stageId: 'prepare',
        stageLabel: 'تهيئة',
        currentStage: 0,
        totalStages: 0,
      );

      expect(progress.fraction, 0);
    });

    test('stage exception exposes only the privacy-safe code in toString', () {
      const failure = CloudSyncStageException(
        stageId: 'mushaf',
        stageLabel: 'خريطة المصحف',
        safeCode: 'SYNC_MUSHAF_42P10',
        cause: 'raw-server-detail-should-not-be-rendered',
      );

      expect(failure.toString(), contains('SYNC_MUSHAF_42P10'));
      expect(failure.toString(), isNot(contains('raw-server-detail')));
    });
  });
}
