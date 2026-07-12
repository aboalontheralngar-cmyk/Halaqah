import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:halaqah_teacher/app/app.dart';

void main() {
  test('theme preference maps to a persistent ThemeMode', () {
    expect(themeModeFromSetting('system'), ThemeMode.system);
    expect(themeModeFromSetting('light'), ThemeMode.light);
    expect(themeModeFromSetting('dark'), ThemeMode.dark);
    expect(themeModeFromSetting(null), ThemeMode.system);
    expect(themeModeFromSetting('invalid'), ThemeMode.system);
  });
}
