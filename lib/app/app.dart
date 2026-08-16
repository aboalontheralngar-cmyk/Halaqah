import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'design_tokens.dart';
import '../screens/home/home_screen.dart';
import '../screens/settings/setup_wizard_screen.dart';
import '../services/database_service.dart';
import '../services/quran_service.dart';

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
          themeAnimationDuration: AppDurations.normal,
          themeAnimationCurve: Curves.easeOutCubic,
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
                child: ScrollConfiguration(
                  behavior: const _HalaqahScrollBehavior(),
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

class _HalaqahScrollBehavior extends MaterialScrollBehavior {
  const _HalaqahScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class HalaqahStartupFailureApp extends StatefulWidget {
  final String incidentCode;

  const HalaqahStartupFailureApp({
    super.key,
    required this.incidentCode,
  });

  @override
  State<HalaqahStartupFailureApp> createState() =>
      _HalaqahStartupFailureAppState();
}

class _HalaqahStartupFailureAppState extends State<HalaqahStartupFailureApp> {
  bool _retrying = false;
  String? _retryMessage;

  Future<void> _retryStartup() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _retryMessage = null;
    });
    try {
      await QuranService.instance.initialize();
      try {
        themeNotifier.value = themeModeFromSetting(
          await DatabaseService().getSetting('theme'),
        );
      } catch (_) {
        themeNotifier.value = ThemeMode.system;
      }
      runApp(const HalaqahApp());
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _retrying = false;
        _retryMessage =
            'تعذرت إعادة المحاولة. احتفظ برمز الحادثة وأعد فتح التطبيق مرة أخرى.';
      });
    }
  }

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
                    const Icon(
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
                      'لم تُحذف بياناتك. جرّب إعادة المحاولة أولًا. لا تمسح بيانات التطبيق أو تعِد تثبيته قبل أخذ نسخة احتياطية.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      'رمز الحادثة: ${widget.incidentCode}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_retryMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _retryMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 280,
                      child: FilledButton.icon(
                        onPressed: _retrying ? null : _retryStartup,
                        icon: _retrying
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(
                          _retrying ? 'جارٍ إعادة المحاولة…' : 'إعادة المحاولة',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _retrying ? null : SystemNavigator.pop,
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

