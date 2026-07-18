import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app/app.dart';
import 'services/database_service.dart';
import 'services/operational_incident_service.dart';
import 'services/quran_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final incidents = OperationalIncidentService();
  _installGlobalErrorCapture(incidents);

  try {
    await QuranService.instance.initialize();
    themeNotifier.value = themeModeFromSetting(
      await DatabaseService().getSetting('theme'),
    );
    await SupabaseService.initialize();

    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    runApp(const HalaqahApp());
  } catch (error, stackTrace) {
    final incidentCode = await incidents.capture(
      error: error,
      stackTrace: stackTrace,
      source: 'startup',
      fatal: true,
    );
    runApp(HalaqahStartupFailureApp(incidentCode: incidentCode));
  }
}

void _installGlobalErrorCapture(OperationalIncidentService incidents) {
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
        source: 'flutter_framework',
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
      ),
    );
    return previousPlatformHandler?.call(error, stackTrace) ?? false;
  };
}
