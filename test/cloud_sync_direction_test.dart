import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/supabase_service.dart';

void main() {
  group('CloudSyncDirectionPolicy', () {
    test('upload only never downloads', () {
      expect(CloudSyncDirection.uploadOnly.shouldUpload, isTrue);
      expect(CloudSyncDirection.uploadOnly.shouldDownload, isFalse);
      expect(CloudSyncDirection.uploadOnly.settingSuffix, 'upload');
    });

    test('download only never uploads', () {
      expect(CloudSyncDirection.downloadOnly.shouldUpload, isFalse);
      expect(CloudSyncDirection.downloadOnly.shouldDownload, isTrue);
      expect(CloudSyncDirection.downloadOnly.settingSuffix, 'download');
    });

    test('bidirectional performs upload then download', () {
      expect(CloudSyncDirection.bidirectional.shouldUpload, isTrue);
      expect(CloudSyncDirection.bidirectional.shouldDownload, isTrue);
      expect(
        CloudSyncDirection.bidirectional.settingSuffix,
        'bidirectional',
      );
    });
  });
}
