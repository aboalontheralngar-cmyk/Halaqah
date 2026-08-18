import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/widgets/deliberate_swipe_action_card.dart';

Widget _scrollHarness({
  required VoidCallback onSwipeRight,
  required VoidCallback onSwipeLeft,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: [
          DeliberateSwipeActionCard(
            key: const Key('swipe-card'),
            onSwipeRight: onSwipeRight,
            onSwipeLeft: onSwipeLeft,
            child: const SizedBox(
              height: 180,
              child: Center(child: Text('طالب')),
            ),
          ),
          const SizedBox(height: 900),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('vertical scrolling does not trigger recitation actions',
      (tester) async {
    var rightCount = 0;
    var leftCount = 0;
    await tester.pumpWidget(
      _scrollHarness(
        onSwipeRight: () => rightCount++,
        onSwipeLeft: () => leftCount++,
      ),
    );

    await tester.drag(find.byKey(const Key('swipe-card')), const Offset(18, -180));
    await tester.pumpAndSettle();
    expect(rightCount, 0);
    expect(leftCount, 0);
  });

  testWidgets('diagonal scrolling does not trigger recitation actions',
      (tester) async {
    var rightCount = 0;
    var leftCount = 0;
    await tester.pumpWidget(
      _scrollHarness(
        onSwipeRight: () => rightCount++,
        onSwipeLeft: () => leftCount++,
      ),
    );

    await tester.drag(find.byKey(const Key('swipe-card')), const Offset(70, -130));
    await tester.pumpAndSettle();
    expect(rightCount, 0);
    expect(leftCount, 0);
  });

  testWidgets('clear horizontal swipe triggers only the intended action',
      (tester) async {
    var rightCount = 0;
    var leftCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: DeliberateSwipeActionCard(
              key: const Key('swipe-card'),
              onSwipeRight: () => rightCount++,
              onSwipeLeft: () => leftCount++,
              child: const SizedBox(
                width: 320,
                height: 120,
                child: Center(child: Text('طالب')),
              ),
            ),
          ),
        ),
      ),
    );

    final card = find.byKey(const Key('swipe-card'));
    await tester.drag(card, const Offset(150, 5));
    await tester.pumpAndSettle();
    expect(rightCount, 1);
    expect(leftCount, 0);

    await tester.drag(card, const Offset(-150, 5));
    await tester.pumpAndSettle();
    expect(rightCount, 1);
    expect(leftCount, 1);
  });
}
