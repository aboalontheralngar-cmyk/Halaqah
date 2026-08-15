import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'services/database_service.dart';
import 'services/background_backup_scheduler.dart';
import 'services/operational_incident_service.dart';
import 'services/quran_service.dart';
import 'services/supabase_service.dart';
import 'services/cloud_auto_sync_coordinator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final incidents = OperationalIncidentService();
  _installGlobalErrorCapture(incidents);

  // Only the local database/theme and Quran asset are essential. Cloud,
  // backup scheduling, and system UI setup must never replace the whole app
  // with a fatal screen when one of them is temporarily unavailable.
  try {
    await QuranService.instance.initialize();
    themeNotifier.value = themeModeFromSetting(
      await DatabaseService().getSetting('theme'),
    );
  } catch (error, stackTrace) {
    final incidentCode = await incidents.capture(
      error: error,
      stackTrace: stackTrace,
      source: 'startup',
      fatal: true,
    );
    runApp(HalaqahStartupFailureApp(incidentCode: incidentCode));
    return;
  }

  await _runNonCriticalStartupTask(
    incidents: incidents,
    source: 'startup.backup_scheduler',
    action: () => BackgroundBackupScheduler.initializeAndSynchronize(),
  );
  await _runNonCriticalStartupTask(
    incidents: incidents,
    source: 'startup.supabase',
    action: () async {
      await SupabaseService.initialize();
      CloudAutoSyncCoordinator.instance.start();
    },
  );
  await _runNonCriticalStartupTask(
    incidents: incidents,
    source: 'startup.system_ui',
    action: () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    },
  );

  // Kept outside the startup try/catch: a fault in a descendant widget is a
  // local UI incident and must not be misclassified as failure to start.
  runApp(const HalaqahApp());
}

Future<void> _runNonCriticalStartupTask({
  required OperationalIncidentService incidents,
  required String source,
  required Future<void> Function() action,
}) async {
  try {
    await action();
  } catch (error, stackTrace) {
    await incidents.capture(
      error: error,
      stackTrace: stackTrace,
      source: source,
    );
  }
}

void _installGlobalErrorCapture(OperationalIncidentService incidents) {
  String contextSource(FlutterErrorDetails details) {
    final raw = details.context?.toDescription() ?? 'unknown_widget';
    final normalized = raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return normalized.isEmpty ? 'unknown_widget' : normalized;
  }

  ErrorWidget.builder = (details) {
    final code = OperationalIncidentService.stackFingerprint(
      details.exception,
      details.stack ?? StackTrace.current,
    );
    final source = contextSource(details);
    unawaited(
      incidents.capture(
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        source: 'error_widget.$source',
        operation: 'render',
      ),
    );
    return Builder(
      builder: (context) {
        final colors = Theme.of(context).colorScheme;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: ColoredBox(
            color: colors.errorContainer,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: colors.onErrorContainer,
                      size: 30,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'تعذر عرض هذا الجزء، وبقية التطبيق وبياناتك ما زالت تعمل بأمان.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'أغلق النافذة وحاول مرة أخرى. إذا تكرر الخطأ أرسل رمز الحادثة من شاشة التشخيص.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onErrorContainer),
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      'رمز الحادثة: $code',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: colors.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  };
  final previousFlutterHandler = FlutterError.onError;
  FlutterError.onError = (details) {
    if (previousFlutterHandler != null) {
      previousFlutterHandler(details);
    } else {
      FlutterError.presentError(details);
    }
    unawaited(
      incidents.capture(
        error: details.exception,
        stackTrace: details.stack ?? StackTrace.current,
        source: 'flutter_framework.${contextSource(details)}',
        operation: 'framework_callback',
      ),
    );
  };

  final previousPlatformHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    unawaited(
      incidents.capture(
        error: error,
        stackTrace: stackTrace,
        source: 'platform_dispatcher',
        operation: 'async_uncaught',
      ),
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? true;
  };
}
