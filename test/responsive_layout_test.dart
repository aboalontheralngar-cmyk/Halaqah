import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/widgets/app_design_widgets.dart';

void main() {
  Widget testShell(Widget child) {
    return MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 640),
          textScaler: TextScaler.linear(2),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(width: 280, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('responsive information row stacks with large system text',
      (tester) async {
    await tester.pumpWidget(
      testShell(
        const AppResponsiveInfoRow(
          label: 'معلومات طويلة للطالب',
          value: 'قيمة طويلة يجب أن تبقى ظاهرة كاملة دون تجاوز أفقي',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('معلومات طويلة للطالب'), findsOneWidget);
    expect(
      find.text('قيمة طويلة يجب أن تبقى ظاهرة كاملة دون تجاوز أفقي'),
      findsOneWidget,
    );
  });

  testWidgets('responsive action buttons stack instead of overflowing',
      (tester) async {
    await tester.pumpWidget(
      testShell(
        AppResponsiveButtonRow(
          children: [
            OutlinedButton(onPressed: () {}, child: const Text('السابق')),
            OutlinedButton(onPressed: () {}, child: const Text('التالي')),
            FilledButton(
              onPressed: () {},
              child: const Text('إنهاء التسميع'),
            ),
          ],
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('إنهاء التسميع'), findsOneWidget);
  });

  testWidgets('dialog title keeps long Arabic title inside narrow width',
      (tester) async {
    await tester.pumpWidget(
      testShell(
        const AppDialogTitle(
          icon: Icons.picture_as_pdf_outlined,
          title: 'تصدير تقارير جميع الطلاب خلال الفترة المحددة',
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
