import 'package:flutter/material.dart';

/// مسافات موحدة ومضغوطة لواجهة هاتف عملية وخفيفة.
class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 7;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double xxl = 34;

  static const EdgeInsets page = EdgeInsets.fromLTRB(md, sm, md, xl);
  static const EdgeInsets card = EdgeInsets.all(md);

  static EdgeInsets pageFor(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontal = width >= AppBreakpoints.medium
        ? xl
        : width >= AppBreakpoints.compact
            ? lg
            : md;
    return EdgeInsets.fromLTRB(horizontal, sm, horizontal, xl);
  }
}

class AppRadii {
  const AppRadii._();

  static const double xs = 7;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double pill = 999;
}

class AppDurations {
  const AppDurations._();

  static const Duration quick = Duration(milliseconds: 110);
  static const Duration normal = Duration(milliseconds: 170);
  static const Duration deliberate = Duration(milliseconds: 230);
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;
  static const double wide = 1200;
  static const double maxContentWidth = 1120;
}
