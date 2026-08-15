import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/review_plan_policy.dart';

void main() {
  test('review recommendation grows with memorized content', () {
    final fiveJuz = ReviewPlanPolicy.recommend(1039);
    final halfQuran = ReviewPlanPolicy.recommend(3118);
    final fullQuran = ReviewPlanPolicy.recommend(6236);

    expect(fiveJuz.dailyPages, lessThan(halfQuran.dailyPages));
    expect(halfQuran.dailyPages, lessThan(fullQuran.dailyPages));
    expect(fullQuran.dailyPages, 20);
  });

  test('recommendation converts consistently to supported units', () {
    final result = ReviewPlanPolicy.recommend(3118);
    expect(result.amountForUnit('pages'), result.dailyPages);
    expect(result.amountForUnit('lines'), result.dailyPages * 15);
    expect(result.amountForUnit('ayahs'), greaterThan(0));
    expect(result.amountForUnit('hizbs'), greaterThan(0));
  });
}
