import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/recitation_points_policy.dart';

void main() {
  group('RecitationPointsPolicy', () {
    test('awards proportional points for partial completion', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 10,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );

      expect(result.completionPercent, 50);
      expect(result.completionPoints, 2.5);
      expect(result.bonusPoints, 0);
      expect(result.totalPoints, 2.5);
    });

    test('preserves the exact fractional reward for small real work', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 1,
        planAmount: 100,
        completionReward: 5,
      );

      expect(result.completionPoints, 0.05);
      expect(result.bonusPoints, 0);
    });

    test('full completion awards the full completion reward', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 20,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );

      expect(result.completionPoints, 5);
      expect(result.bonusPoints, 0);
      expect(result.totalPoints, 5);
    });

    test('extra reward is added only after exceeding the plan', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 25,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );

      expect(result.completionPoints, 5);
      expect(result.bonusPoints, 2);
      expect(result.totalPoints, 7);
    });

    test('extra reward scales every 25 percent above the plan', () {
      final fiftyPercentExtra = RecitationPointsPolicy.calculate(
        actualAmount: 30,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );
      final fiftyFivePercentExtra = RecitationPointsPolicy.calculate(
        actualAmount: 31,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );

      expect(fiftyPercentExtra.excessPercent, 50);
      expect(fiftyPercentExtra.bonusTier, 2);
      expect(fiftyPercentExtra.bonusPoints, 4);
      expect(fiftyPercentExtra.totalPoints, 9);
      expect(fiftyFivePercentExtra.bonusTier, 3);
      expect(fiftyFivePercentExtra.bonusPoints, 6);
      expect(fiftyFivePercentExtra.totalPoints, 11);
    });

    test('extra reward is capped at four bonus tiers', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 40,
        planAmount: 20,
        completionReward: 5,
        extraReward: 2,
      );

      expect(result.excessPercent, 100);
      expect(result.bonusTier, 4);
      expect(result.bonusPoints, 8);
      expect(result.totalPoints, 13);
    });

    test('zero work never produces positive points', () {
      final result = RecitationPointsPolicy.calculate(
        actualAmount: 0,
        planAmount: 20,
        completionReward: 5,
      );

      expect(result.totalPoints, 0);
    });


    test('supports explicit floor and ceil rounding', () {
      final floorResult = RecitationPointsPolicy.calculate(
        actualAmount: 10,
        planAmount: 20,
        completionReward: 5,
        roundingMode: 'floor',
      );
      final ceilResult = RecitationPointsPolicy.calculate(
        actualAmount: 10,
        planAmount: 20,
        completionReward: 5,
        roundingMode: 'ceil',
      );
      final nearestResult = RecitationPointsPolicy.calculate(
        actualAmount: 10,
        planAmount: 20,
        completionReward: 5,
        roundingMode: 'nearest',
      );
      expect(floorResult.completionPoints, 2);
      expect(ceilResult.completionPoints, 3);
      expect(nearestResult.completionPoints, 3);
    });
  });
}
