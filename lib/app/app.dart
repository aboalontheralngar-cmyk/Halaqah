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

class HalaqahStartupFailureApp extends StatelessWidget {
  final String incidentCode;

  const HalaqahStartupFailureApp({
    super.key,
    required this.incidentCode,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.health_and_safety_outlined,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'تعذر إكمال تشغيل حلقتي',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'لم تُحذف بياناتك. أغلق التطبيق وافتحه مرة أخرى، ولا تمسح بياناته أو تعِد تثبيته قبل أخذ نسخة احتياطية.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'رمز الحادثة: $incidentCode',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: SystemNavigator.pop,
                      icon: const Icon(Icons.close),
                      label: const Text('إغلاق التطبيق'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
