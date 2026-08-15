import 'package:flutter/material.dart';

class ColorContrast {
  const ColorContrast._();

  static Color on(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
          ? Colors.white
          : const Color(0xFF111714);
}
