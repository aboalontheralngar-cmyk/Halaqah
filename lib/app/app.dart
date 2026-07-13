import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/setup_wizard_screen.dart';
import '../services/database_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

ThemeMode themeModeFromSetting(String? value) {
  switch (value) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

class HalaqahApp extends StatelessWidget {
  const HalaqahApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'حلقتي',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          locale: const Locale('ar'),
          builder: (context, child) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    isDark ? Brightness.dark : Brightness.light,
                systemNavigationBarColor: theme.scaffoldBackgroundColor,
                systemNavigationBarIconBrightness:
                    isDark ? Brightness.light : Brightness.dark,
                systemNavigationBarDividerColor: Colors.transparent,
              ),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: ColoredBox(
                  color: theme.scaffoldBackgroundColor,
                  // حجز المساحة السفلية مركزيًا يحمي جميع الشاشات والحوارات
                  // من أزرار Android ومنطقة الإيماءة، بما فيها المسارات القديمة.
                  child: SafeArea(
                    top: false,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          home: FutureBuilder<bool>(
            future: DatabaseService().getSetting('setup_completed').then((val) => val == 'true'),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.data == true) {
                return const HomeScreen();
              } else {
                return const SetupWizardScreen();
              }
            },
          ),
        );
      },
    );
  }
}
