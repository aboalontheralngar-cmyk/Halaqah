import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  // هوية هادئة مستلهمة من ألوان المصحف: أخضر عميق، عاجي دافئ، وذهبي خافت.
  static const Color primaryColor = Color(0xFF1F6B5D);
  static const Color primaryColorLight = Color(0xFF3C8978);
  static const Color primaryColorDark = Color(0xFF174F45);
  static const Color accentColor = Color(0xFFA87936);
  static const Color errorColor = Color(0xFFBA3A3A);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFB7791F);
  static const Color backgroundColor = Color(0xFFF7F4ED);
  static const Color surfaceColor = Color(0xFFFFFDF8);
  static const Color textPrimaryColor = Color(0xFF1C2925);
  static const Color textSecondaryColor = Color(0xFF63706B);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final generatedScheme = ColorScheme.fromSeed(
      seedColor: primaryColor,
      brightness: brightness,
      error: errorColor,
    );
    final scheme = generatedScheme.copyWith(
      primary: isDark ? const Color(0xFF8ED7C5) : primaryColor,
      onPrimary: isDark ? const Color(0xFF00382F) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF1D4F44) : const Color(0xFFDDEFE8),
      onPrimaryContainer:
          isDark ? const Color(0xFFB7F3E3) : const Color(0xFF113D35),
      secondary: isDark ? const Color(0xFFE7C078) : accentColor,
      secondaryContainer:
          isDark ? const Color(0xFF4C3A18) : const Color(0xFFF6EAD3),
      surface: isDark ? const Color(0xFF121A17) : surfaceColor,
      surfaceContainerLowest:
          isDark ? const Color(0xFF0B110F) : Colors.white,
      surfaceContainerLow:
          isDark ? const Color(0xFF18231F) : const Color(0xFFF3EFE6),
      surfaceContainer:
          isDark ? const Color(0xFF202C27) : const Color(0xFFEDE9DF),
      onSurface:
          isDark ? const Color(0xFFE5EEE9) : textPrimaryColor,
      onSurfaceVariant:
          isDark ? const Color(0xFFB6C4BE) : textSecondaryColor,
      outline: isDark ? const Color(0xFF52625C) : const Color(0xFFCFCAC0),
      outlineVariant:
          isDark ? const Color(0xFF2C3934) : const Color(0xFFE4DFD5),
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF0B1210) : backgroundColor,
      visualDensity: const VisualDensity(horizontal: -0.25, vertical: -0.1),
      splashFactory: InkSparkle.splashFactory,
    );
    final textTheme = base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 28,
        height: 1.25,
        fontWeight: FontWeight.w800,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 23,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 20,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 16,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 16,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 14.5,
        height: 1.55,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12.5,
        height: 1.45,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
    final roundedMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 64,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
        ),
        iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(isDark ? 0.18 : 0.035),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          elevation: 0,
          shape: roundedMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          shape: roundedMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          side: BorderSide(color: scheme.outline),
          shape: roundedMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withOpacity(0.78),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 1,
        focusElevation: 1,
        hoverElevation: 2,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 74,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          return textTheme.labelSmall?.copyWith(
            color: states.contains(MaterialState.selected)
                ? scheme.primary
                : scheme.onSurfaceVariant,
            fontWeight: states.contains(MaterialState.selected)
                ? FontWeight.w800
                : FontWeight.w600,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.primary,
        unselectedItemColor: scheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
      bottomAppBarTheme: BottomAppBarThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        minTileHeight: 54,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      drawerTheme: DrawerThemeData(
        width: 304,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(left: Radius.circular(28)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 4,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorColor: scheme.primary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 4,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadii.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFFE8F2EE)
            : const Color(0xFF17332C),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF17332C) : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerLow,
        circularTrackColor: scheme.surfaceContainerLow,
      ),
      dividerColor: scheme.outlineVariant,
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFE8F2EE) : const Color(0xFF17332C),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? const Color(0xFF17332C) : Colors.white,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppRadii.pill),
        thickness: MaterialStateProperty.all(5),
        thumbColor: MaterialStateProperty.all(
          scheme.primary.withOpacity(0.25),
        ),
      ),
    );
  }
}

class AppColors {
  static const Color present = Color(0xFF16A34A);
  static const Color late = Color(0xFFD97706);
  static const Color absent = Color(0xFFDC2626);
  static const Color excused = Color(0xFF2563EB);

  static const Color excellent = Color(0xFF16A34A);
  static const Color veryGood = Color(0xFF65A30D);
  static const Color good = Color(0xFFEAB308);
  static const Color acceptable = Color(0xFFD97706);
  static const Color weak = Color(0xFFDC2626);

  static Color getAttendanceColor(String status) {
    switch (status) {
      case 'present':
        return present;
      case 'late':
        return late;
      case 'absent':
        return absent;
      case 'excused':
        return excused;
      default:
        return Colors.grey;
    }
  }

  static Color getScoreColor(int score) {
    if (score >= 90) return excellent;
    if (score >= 80) return veryGood;
    if (score >= 70) return good;
    if (score >= 60) return acceptable;
    return weak;
  }

  static Color getQualityColor(int rating) {
    switch (rating) {
      case 4:
        return excellent;
      case 3:
        return veryGood;
      case 2:
        return good;
      case 1:
        return acceptable;
      default:
        return Colors.grey;
    }
  }
}
