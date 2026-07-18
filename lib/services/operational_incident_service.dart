import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'audit_log_service.dart';

/// Captures only structural diagnostics. Exception messages and raw stack
/// traces are deliberately excluded because they may contain local paths or
/// application data.
class OperationalIncidentService {
  OperationalIncidentService({AuditLogService? audit})
      : _audit = audit ?? AuditLogService();

  final AuditLogService _audit;

  static String? _lastFingerprint;
  static DateTime? _lastRecordedAt;

  Future<String> capture({
    required Object error,
    required StackTrace stackTrace,
    required String source,
    bool fatal = false,
    DateTime? now,
  }) async {
    final capturedAt = now ?? DateTime.now();
    final fingerprint = stackFingerprint(error, stackTrace);
    final duplicateWindow = _lastFingerprint == fingerprint &&
        _lastRecordedAt != null &&
        capturedAt.difference(_lastRecordedAt!).abs() <
            const Duration(minutes: 5);
    if (duplicateWindow) return fingerprint;

    _lastFingerprint = fingerprint;
    _lastRecordedAt = capturedAt;
    try {
      await _audit.record(
        eventType: fatal ? 'runtime.fatal' : 'runtime.error',
        entityType: 'application',
        outcome: 'failure',
        details: <String, dynamic>{
          'source': _safeSource(source),
          'error_type': error.runtimeType.toString(),
          'fingerprint': fingerprint,
          'fatal': fatal,
        },
        now: capturedAt,
      );
    } catch (_) {
      // Error capture must never cause a second application failure.
    }
    return fingerprint;
  }

  static String stackFingerprint(Object error, StackTrace stackTrace) {
    final frames = stackTrace
        .toString()
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .take(12)
        .map(
          (line) => line
              .replaceAll(RegExp(r'([A-Za-z]:)?[/\\][^\s:()]+'), '<path>')
              .replaceAll(RegExp(r':\d+:\d+'), ':#:#'),
        )
        .join('|');
    final input = '${error.runtimeType}|$frames';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 16);
  }

  static String _safeSource(String source) {
    final normalized = source
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_.-]'), '_');
    return normalized.isEmpty ? 'unknown' : normalized.substring(
      0,
      normalized.length.clamp(0, 48).toInt(),
    );
  }
}
