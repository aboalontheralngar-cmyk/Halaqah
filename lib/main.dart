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
import 'services/legacy_memorized_reconciliation_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final incidents = OperationalIncidentService();
  _installGlobalErrorCapture(incidents);

  // The bundled Quran asset is the only hard startup dependency. Opening
  // SQLite only to read the theme must never block the whole app: a transient
  // migration/lock can be retried by the normal screens while we start with
  // the system theme and preserve all local data.
  try {
    await _initializeQuranWithRetry();
  } catch (error, stackTrace) {
    final incidentCode = await incidents.capture(
      error: error,
      stackTrace: stackTrace,
      source: 'startup.quran',
      fatal: true,
      operation: 'load_bundled_quran',
    );
    runApp(HalaqahStartupFailureApp(incidentCode: incidentCode));
    return;
  }

  await _runNonCriticalStartupTask(
    incidents: incidents,
    source: 'startup.theme',
    action: () async {
      themeNotifier.value = themeModeFromSetting(
        await DatabaseService().getSetting('theme'),
      );
    },
  );

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

  // مصالحة بيانات الطلاب القدامى قد تمر على عشرات الطلاب؛ لا نحبس أول إطار
  // للتطبيق بسببها. تعمل مرة واحدة في الخلفية وتضيف الخلايا الناقصة فقط.
  unawaited(
    Future<void>.delayed(const Duration(seconds: 2)).then(
      (_) => _runNonCriticalStartupTask(
        incidents: incidents,
        source: 'startup.legacy_memorized_reconciliation',
        action: () => LegacyMemorizedReconciliationService().reconcileAllOnce(),
      ),
    ),
  );
}

Future<void> _initializeQuranWithRetry() async {
  Object? lastError;
  StackTrace? lastStack;
  for (var attempt = 0; attempt < 2; attempt++) {
    try {
      await QuranService.instance.initialize();
      return;
    } catch (error, stackTrace) {
      lastError = error;
      lastStack = stackTrace;
      if (attempt == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
    }
  }
  Error.throwWithStackTrace(
    lastError ?? StateError('تعذر تحميل بيانات القرآن المضمنة'),
    lastStack ?? StackTrace.current,
  );
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
            color: colors.surface,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final content = Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: colors.error,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تعذر عرض هذا الجزء',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurface,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'بقية التطبيق وبياناتك ما زالت تعمل بأمان. أغلق النافذة وحاول مرة أخرى.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      SelectableText(
                        'رمز الحادثة: $code',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
                // ErrorWidget قد يظهر داخل BottomSheet أو خلية قصيرة جدًا؛
                // لذلك يجب أن يكون قابلًا للتمرير ولا يفرض ارتفاعًا ثابتًا.
                return SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.hasBoundedHeight
                          ? constraints.maxHeight
                          : 0,
                    ),
                    child: Center(
                      child: DefaultTextStyle.merge(
                        style: const TextStyle(fontSize: 12, height: 1.3),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 360),
                          child: content,
                        ),
                      ),
                    ),
                  ),
                );
              },
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
