import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  static const EdgeInsets page = EdgeInsets.fromLTRB(md, sm, md, lg);
  static const EdgeInsets card = EdgeInsets.all(md);
}

class AppRadii {
  const AppRadii._();

  static const double sm = 12;
  static const double md = 18;
  static const double lg = 26;
  static const double pill = 999;
}

class AppDurations {
  const AppDurations._();

  static const Duration quick = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 240);
}

class AppBreakpoints {
  const AppBreakpoints._();

  static const double compact = 600;
  static const double medium = 900;
  static const double maxContentWidth = 1180;
}
