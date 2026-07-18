import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/cloud_connection_diagnostics.dart';

void main() {
  final endpoint = Uri.parse('https://example.supabase.co/auth/v1/health');

  CloudConnectionDiagnostics diagnostics({
    required CloudHostLookup lookup,
    required CloudEndpointProbe probe,
  }) =>
      CloudConnectionDiagnostics(
        endpoint: endpoint,
        timeout: const Duration(milliseconds: 50),
        lookup: lookup,
        probe: probe,
      );

  test('reports a healthy endpoint without requiring authentication', () async {
    final result = await diagnostics(
      lookup: (_) async => [InternetAddress.loopbackIPv4],
      probe: (_, __) async => HttpStatus.unauthorized,
    ).run();

    expect(result.status, CloudConnectionStatus.healthy);
    expect(result.httpStatus, HttpStatus.unauthorized);
    expect(result.isHealthy, isTrue);
  });

  test('distinguishes DNS lookup failure', () async {
    final result = await diagnostics(
      lookup: (_) => throw SocketException('Failed host lookup'),
      probe: (_, __) async => HttpStatus.ok,
    ).run();

    expect(result.status, CloudConnectionStatus.dnsFailure);
    expect(result.isHealthy, isFalse);
  });

  test('distinguishes a connection timeout', () async {
    final result = await diagnostics(
      lookup: (_) async => [InternetAddress.loopbackIPv4],
      probe: (_, __) => throw TimeoutException('timed out'),
    ).run();

    expect(result.status, CloudConnectionStatus.timeout);
  });

  test('reports a server-side failure separately', () async {
    final result = await diagnostics(
      lookup: (_) async => [InternetAddress.loopbackIPv4],
      probe: (_, __) async => HttpStatus.serviceUnavailable,
    ).run();

    expect(result.status, CloudConnectionStatus.serverFailure);
    expect(result.httpStatus, HttpStatus.serviceUnavailable);
  });

  test('rejects a non-HTTPS configuration before network access', () async {
    final result = await CloudConnectionDiagnostics(
      endpoint: Uri.parse('http://example.supabase.co/auth/v1/health'),
      lookup: (_) => throw StateError('must not be called'),
      probe: (_, __) => throw StateError('must not be called'),
    ).run();

    expect(result.status, CloudConnectionStatus.configurationFailure);
  });
}
