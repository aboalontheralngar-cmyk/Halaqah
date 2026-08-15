import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/daily_closing_service.dart';

void main() {
  group('DailyClosingEvaluator', () {
    test('suspended study day exempts every student', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: true,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: false,
      );
      expect(state, DailyClosingState.holiday);
    });

    test('approved vacation wins over an absent record', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: true,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'absent',
      );
      expect(state, DailyClosingState.excused);
    });

    test('actual attendance wins over a previously approved vacation', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: true,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'present',
        revisionDone: true,
      );
      expect(state, DailyClosingState.completed);
    });

    test('missing attendance remains reviewable until explicit close', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: false,
      );
      expect(state, DailyClosingState.unrecorded);
    });

    test('present student with recitation is complete', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'present',
        memorizationDone: true,
      );
      expect(state, DailyClosingState.completed);
    });

    test('hold exempts recitation but not attendance', () {
      final presentHeld = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: true,
        hasRecord: true,
        attendance: 'present',
      );
      final missingHeld = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: true,
        hasRecord: false,
      );
      expect(presentHeld, DailyClosingState.held);
      expect(missingHeld, DailyClosingState.unrecorded);
    });

    test('full pause exempts attendance even without a daily record', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: true,
        hasAttendanceExemptHold: true,
        hasRecord: false,
      );
      expect(state, DailyClosingState.held);
    });

    test('activity is present attendance without a recitation penalty', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'present',
        recitationExempt: true,
      );
      expect(state, DailyClosingState.activity);
    });

    test('talaqqin is a valid present-day outcome', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'present',
        talaqqinDone: true,
      );
      expect(state, DailyClosingState.talaqqin);
    });

    test('present student without recitation needs follow-up', () {
      final state = DailyClosingEvaluator.classify(
        isHoliday: false,
        hasApprovedVacation: false,
        hasActiveHold: false,
        hasRecord: true,
        attendance: 'late',
      );
      expect(state, DailyClosingState.noRecitation);
    });
  });
}
