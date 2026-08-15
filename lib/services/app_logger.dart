import 'dart:async';

import 'package:flutter/foundation.dart';

import 'operational_incident_service.dart';

/// Privacy-safe operational logging.
///
/// Raw Supabase responses, record identifiers, tokens, email addresses and
/// exception messages are never printed. Debug output contains only a stable
/// source/code and the exception runtime type. Structural incidents can be
/// captured in the existing audit-backed incident service.
class AppLogger {
  AppLogger._();

  static final OperationalIncidentService _incidents =
      OperationalIncidentService();

  static void info(String code, {required String source}) {
    if (kDebugMode) debugPrint('[$source] $code');
  }

  static void warning(String code, {required String source}) {
    if (kDebugMode) debugPrint('[$source] warning:$code');
  }

  static void error(
    Object error, {
    required String source,
    StackTrace? stackTrace,
    bool capture = true,
  }) {
    if (kDebugMode) {
      debugPrint('[$source] error_type:${error.runtimeType}');
    }
    if (!capture) return;
    unawaited(
      _incidents.capture(
        error: error,
        stackTrace: stackTrace ?? StackTrace.current,
        source: source,
      ),
    );
  }
}
