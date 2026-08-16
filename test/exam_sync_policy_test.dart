import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/sync/exam_sync_policy.dart';

void main() {
  group('ExamSyncPolicy', () {
    test('keeps an active template reference', () {
      expect(
        ExamSyncPolicy.cloudTemplateId(
          'template-a',
          const {'template-a', 'template-b'},
        ),
        'template-a',
      );
    });

    test('drops a stale template reference before cloud upload', () {
      expect(
        ExamSyncPolicy.cloudTemplateId('deleted-template', const {'active'}),
        isNull,
      );
    });

    test('normalizes empty references to null', () {
      expect(ExamSyncPolicy.cloudTemplateId('   ', const {'active'}), isNull);
      expect(ExamSyncPolicy.cloudTemplateId(null, const {'active'}), isNull);
    });
  });
}
