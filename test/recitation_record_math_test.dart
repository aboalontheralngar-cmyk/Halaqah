import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/recitation_record_math.dart';

void main() {
  test('preserves legacy memorized balance while applying tracked delta', () {
    expect(
      RecitationRecordMath.adjustMemorizedTotal(
        currentTotal: 500,
        previousTrackedCount: 120,
        currentTrackedCount: 115,
      ),
      495,
    );
  });

  test('does not exceed Quran total or become negative', () {
    expect(
      RecitationRecordMath.adjustMemorizedTotal(
        currentTotal: 6234,
        previousTrackedCount: 100,
        currentTrackedCount: 110,
      ),
      6236,
    );
    expect(
      RecitationRecordMath.adjustMemorizedTotal(
        currentTotal: 2,
        previousTrackedCount: 20,
        currentTrackedCount: 0,
      ),
      0,
    );
  });
}
