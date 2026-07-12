import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrService {
  static const String _prefix = 'HALAQAH:STUDENT:1:';
  // Kept only to read QR cards printed by older Android releases.
  static const String _secretKey = 'HalaqahApp2024!';

  static String generateQrData(String qrToken) {
    return '$_prefix${qrToken.trim()}';
  }

  static String? decodeQrData(String encodedData) {
    final value = encodedData.trim();
    if (value.startsWith(_prefix)) {
      final token = value.substring(_prefix.length).trim();
      return token.isEmpty ? null : token;
    }

    // Backward compatibility: old printed cards contain a signed student id.
    try {
      final decoded = utf8.decode(base64Decode(value));
      final qrData = json.decode(decoded) as Map<String, dynamic>;
      
      final studentId = qrData['sid'] as String;
      final timestamp = qrData['ts'] as String;
      final checksum = qrData['cs'] as String;
      
      final data = '$studentId|$timestamp';
      if (_generateChecksum(data) != checksum) {
        return null;
      }
      
      return studentId;
    } catch (e) {
      return null;
    }
  }

  static String _generateChecksum(String data) {
    final key = utf8.encode(_secretKey);
    final bytes = utf8.encode(data);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  static bool isValidQrCode(String encodedData) {
    return decodeQrData(encodedData) != null;
  }
}
