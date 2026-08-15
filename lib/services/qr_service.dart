import 'dart:convert';

import 'package:crypto/crypto.dart';

class QrService {
  static const String _prefix = 'HALAQAH:STUDENT:1:';

  // Legacy cards used a shared HMAC secret. That secret is intentionally no
  // longer stored in source or normal production binaries. A short-lived
  // migration build may inject it with --dart-define=HALAQAH_LEGACY_QR_SECRET.
  static const String _legacySecret = String.fromEnvironment(
    'HALAQAH_LEGACY_QR_SECRET',
  );
  static const Duration _legacyMaxAge = Duration(days: 365 * 5);
  static const Duration _legacyFutureSkew = Duration(minutes: 10);

  static String generateQrData(String qrToken) {
    return '$_prefix${qrToken.trim()}';
  }

  static String? decodeQrData(
    String encodedData, {
    DateTime? now,
    String? legacySecretOverrideForTesting,
  }) {
    final value = encodedData.trim();
    if (value.startsWith(_prefix)) {
      final token = value.substring(_prefix.length).trim();
      return token.isEmpty ? null : token;
    }

    final legacySecret =
        legacySecretOverrideForTesting ?? _legacySecret.trim();
    if (legacySecret.isEmpty) return null;

    // Compatibility path for a deliberately built migration APK only. Legacy
    // cards are never treated as a security credential; they merely resolve a
    // student identifier and remain subject to the app's normal permissions.
    try {
      final decoded = utf8.decode(base64Decode(value));
      final qrData = json.decode(decoded);
      if (qrData is! Map) return null;

      final studentId = qrData['sid']?.toString().trim() ?? '';
      final timestampText = qrData['ts']?.toString().trim() ?? '';
      final checksum = qrData['cs']?.toString().trim() ?? '';
      final timestampMs = int.tryParse(timestampText);
      if (studentId.isEmpty || timestampMs == null || checksum.length != 16) {
        return null;
      }

      final issuedAt = DateTime.fromMillisecondsSinceEpoch(timestampMs);
      final referenceNow = now ?? DateTime.now();
      if (issuedAt.isAfter(referenceNow.add(_legacyFutureSkew)) ||
          referenceNow.difference(issuedAt) > _legacyMaxAge) {
        return null;
      }

      final data = '$studentId|$timestampText';
      if (_generateChecksum(data, legacySecret) != checksum) return null;
      return studentId;
    } catch (_) {
      return null;
    }
  }

  static String _generateChecksum(String data, String secret) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static bool isValidQrCode(String encodedData) {
    return decodeQrData(encodedData) != null;
  }
}
