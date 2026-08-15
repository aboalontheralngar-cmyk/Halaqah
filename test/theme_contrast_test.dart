import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/app/theme.dart';

void main() {
  double contrast(Color a, Color b) {
    final l1 = a.computeLuminance();
    final l2 = b.computeLuminance();
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  void expectReadable(ThemeData theme) {
    final scheme = theme.colorScheme;
    expect(contrast(scheme.primary, scheme.onPrimary), greaterThanOrEqualTo(4.5));
    expect(
      contrast(scheme.primaryContainer, scheme.onPrimaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(contrast(scheme.surface, scheme.onSurface), greaterThanOrEqualTo(4.5));
    expect(
      contrast(scheme.surface, scheme.onSurfaceVariant),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(scheme.secondaryContainer, scheme.onSecondaryContainer),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrast(scheme.errorContainer, scheme.onErrorContainer),
      greaterThanOrEqualTo(4.5),
    );
    final semantic = theme.extension<AppSemanticColors>()!;
    expect(contrast(semantic.success, semantic.onSuccess), greaterThanOrEqualTo(4.5));
    expect(contrast(semantic.warning, semantic.onWarning), greaterThanOrEqualTo(4.5));
    expect(contrast(semantic.info, semantic.onInfo), greaterThanOrEqualTo(4.5));
  }

  test('light theme semantic color pairs are readable', () {
    expectReadable(AppTheme.lightTheme);
  });

  test('dark theme semantic color pairs are readable', () {
    expectReadable(AppTheme.darkTheme);
  });
}
