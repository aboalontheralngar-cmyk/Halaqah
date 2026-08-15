import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// النظام البصري الموحد لتطبيق «حلقتي».
///
/// يعتمد توزيع P1.23 المضغوط والسلس مع هوية «حلقتي» الخضراء الأصلية:
/// أسطح هادئة، تباين واضح، خطوط صغيرة مقروءة، ومسافات مضبوطة.
class AppTheme {
  static const Color primaryColor = Color(0xFF176B57);
  static const Color primaryColorLight = Color(0xFF3B8B75);
  static const Color primaryColorDark = Color(0xFF0F4F40);
  static const Color accentColor = Color(0xFF9B6C2F);
  static const Color errorColor = Color(0xFFB4232F);
  static const Color successColor = Color(0xFF15803D);
  static const Color warningColor = Color(0xFFA15C0B);
  static const Color backgroundColor = Color(0xFFF5F3ED);
  static const Color surfaceColor = Color(0xFFFFFEFA);
  static const Color textPrimaryColor = Color(0xFF17241F);
  static const Color textSecondaryColor = Color(0xFF596861);

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
      primary: isDark ? const Color(0xFF83D6BE) : primaryColor,
      onPrimary: isDark ? const Color(0xFF00382D) : Colors.white,
      primaryContainer:
          isDark ? const Color(0xFF174C3E) : const Color(0xFFDCEFE7),
      onPrimaryContainer:
          isDark ? const Color(0xFFB7F4E0) : const Color(0xFF0D3D32),
      secondary: isDark ? const Color(0xFFE4BD73) : accentColor,
      onSecondary: isDark ? const Color(0xFF3D2B0F) : Colors.white,
      secondaryContainer:
          isDark ? const Color(0xFF4A3816) : const Color(0xFFF3E7D1),
      onSecondaryContainer:
          isDark ? const Color(0xFFFFDEA2) : const Color(0xFF3D2B0F),
      surface: isDark ? const Color(0xFF181B19) : surfaceColor,
      surfaceContainerLowest:
          isDark ? const Color(0xFF0F1110) : const Color(0xFFFFFFFF),
      surfaceContainerLow:
          isDark ? const Color(0xFF202421) : const Color(0xFFF0EEE7),
      surfaceContainer:
          isDark ? const Color(0xFF292E2A) : const Color(0xFFE9E7E0),
      surfaceContainerHigh:
          isDark ? const Color(0xFF313733) : const Color(0xFFE2E0D8),
      onSurface: isDark ? const Color(0xFFF0F6F2) : textPrimaryColor,
      onSurfaceVariant:
          isDark ? const Color(0xFFC1CEC8) : textSecondaryColor,
      outline: isDark ? const Color(0xFF61736B) : const Color(0xFFC9C7BF),
      outlineVariant:
          isDark ? const Color(0xFF373D39) : const Color(0xFFE1DED5),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF101211) : backgroundColor,
      visualDensity: const VisualDensity(horizontal: -0.9, vertical: -0.8),
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );

    final textTheme = base.textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    ).copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 19,
        height: 1.3,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 16.5,
        height: 1.35,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontSize: 14.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontSize: 12.5,
        height: 1.4,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(
        fontSize: 14,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(
        fontSize: 12.75,
        height: 1.5,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 11.25,
        height: 1.45,
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontSize: 12.25,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: base.textTheme.labelMedium?.copyWith(
        fontSize: 11.25,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.textTheme.labelSmall?.copyWith(
        fontSize: 9.75,
        fontWeight: FontWeight.w600,
      ),
    );

    final roundedMedium = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant, size: 20),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 52,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 8,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onPrimary,
          fontSize: 15.5,
        ),
        iconTheme: IconThemeData(color: scheme.onPrimary, size: 20),
        actionsIconTheme: IconThemeData(color: scheme.onPrimary, size: 20),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge,
          shape: roundedMedium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          elevation: 0,
          textStyle: textTheme.labelLarge,
          shape: roundedMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
          shape: roundedMedium,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(40, 40),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(40, 40),
          iconSize: 20,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.sm),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        isDense: true,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 12,
        ),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
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
          borderSide: BorderSide(color: scheme.secondary, width: 1.4),
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
        backgroundColor: scheme.secondary,
        foregroundColor: scheme.onSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 62,
        elevation: 0,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: selected ? 21 : 20,
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelSmall?.copyWith(
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: scheme.surface,
        selectedItemColor: scheme.secondary,
        unselectedItemColor: scheme.onSurfaceVariant,
        selectedLabelStyle: textTheme.labelSmall,
        unselectedLabelStyle: textTheme.labelSmall,
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
        selectedColor: scheme.secondaryContainer,
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(color: scheme.onSurface),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xs / 2),
        ),
        side: BorderSide(color: scheme.outline),
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
      ),
      radioTheme: RadioThemeData(
        visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.outline,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onSecondary
              : scheme.onSurfaceVariant,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.secondary
              : scheme.surfaceContainerHigh,
        ),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        backgroundColor: scheme.surface,
        collapsedBackgroundColor: scheme.surface,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
        iconColor: scheme.secondary,
        collapsedIconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
      ),
      listTileTheme: ListTileThemeData(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xxs,
        ),
        minTileHeight: 48,
        minLeadingWidth: 34,
        titleTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        iconColor: scheme.onSurfaceVariant,
      ),
      drawerTheme: DrawerThemeData(
        width: 290,
        elevation: 0,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(AppRadii.lg),
          ),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 2,
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
        indicatorColor: scheme.secondary,
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStateProperty.all(const Size(40, 40)),
          visualDensity: const VisualDensity(horizontal: -1, vertical: -1),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.secondaryContainer
                : scheme.surface,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurface,
          ),
          textStyle: WidgetStateProperty.all(textTheme.labelMedium),
          side: WidgetStateProperty.all(BorderSide(color: scheme.outline)),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 2,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(color: scheme.onSurface),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
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
        elevation: 1,
        backgroundColor:
            isDark ? const Color(0xFFEAF1F4) : const Color(0xFF183748),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? const Color(0xFF173442) : Colors.white,
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
        color: scheme.secondary,
        linearTrackColor: scheme.surfaceContainerLow,
        circularTrackColor: scheme.surfaceContainerLow,
      ),
      dividerColor: scheme.outlineVariant,
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStateProperty.all(scheme.surfaceContainerLow),
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w800,
        ),
        dataTextStyle: textTheme.bodySmall?.copyWith(color: scheme.onSurface),
        dividerThickness: 1,
        columnSpacing: AppSpacing.md,
        horizontalMargin: AppSpacing.sm,
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: scheme.surface,
        hourMinuteColor: scheme.surfaceContainerLow,
        dayPeriodColor: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.secondary,
        selectionColor: scheme.secondary.withValues(alpha: 0.20),
        selectionHandleColor: scheme.secondary,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 450),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFEAF1F4) : const Color(0xFF183748),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: isDark ? const Color(0xFF173442) : Colors.white,
        ),
      ),
      scrollbarTheme: ScrollbarThemeData(
        radius: const Radius.circular(AppRadii.pill),
        thickness: WidgetStateProperty.all(4),
        thumbColor: WidgetStateProperty.all(
          scheme.primary.withValues(alpha: 0.22),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        AppSemanticColors(
          success: isDark ? const Color(0xFF6BD99B) : const Color(0xFF15803D),
          onSuccess: isDark ? const Color(0xFF052E1A) : Colors.white,
          successContainer:
              isDark ? const Color(0xFF173C28) : const Color(0xFFE7F7EE),
          warning: isDark ? const Color(0xFFF1C06C) : const Color(0xFFA15C0B),
          onWarning: isDark ? const Color(0xFF382200) : Colors.white,
          warningContainer:
              isDark ? const Color(0xFF493516) : const Color(0xFFFFF1DA),
          info: isDark ? const Color(0xFF8FC9E9) : const Color(0xFF2B6F91),
          onInfo: isDark ? const Color(0xFF082B3E) : Colors.white,
          infoContainer:
              isDark ? const Color(0xFF183A4D) : const Color(0xFFE9F3F8),
        ),
      ],
    );
  }
}

@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  final Color success;
  final Color onSuccess;
  final Color successContainer;
  final Color warning;
  final Color onWarning;
  final Color warningContainer;
  final Color info;
  final Color onInfo;
  final Color infoContainer;

  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.onInfo,
    required this.infoContainer,
  });

  static AppSemanticColors of(BuildContext context) {
    return Theme.of(context).extension<AppSemanticColors>()!;
  }

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? onInfo,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant AppSemanticColors? other,
    double t,
  ) {
    if (other == null) return this;
    return AppSemanticColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      onInfo: Color.lerp(onInfo, other.onInfo, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
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
