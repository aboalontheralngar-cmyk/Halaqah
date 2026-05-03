import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrService {
  static const String _secretKey = 'HalaqahApp2024!';

  static String generateQrData(String studentId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final data = '$studentId|$timestamp';
    final checksum = _generateChecksum(data);
    
    final qrData = {
      'sid': studentId,
      'ts': timestamp,
      'cs': checksum,
    };
    
    return base64Encode(utf8.encode(json.encode(qrData)));
  }

  static String? decodeQrData(String encodedData) {
    try {
      final decoded = utf8.decode(base64Decode(encodedData));
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
