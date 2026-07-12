import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/qr_service.dart';

void main() {
  test('encodes and decodes the shared opaque student token contract', () {
    const token = 'b7ad9fc1-e4bf-4977-b627-bf584cb777a3';
    final encoded = QrService.generateQrData(token);

    expect(encoded, 'HALAQAH:STUDENT:1:$token');
    expect(QrService.decodeQrData(encoded), token);
  });

  test('continues to read QR cards printed by older Android releases', () {
    const studentId = 'a7d2ae45-0500-4cd4-b50b-1e0a708dfac8';
    const timestamp = '1710000000000';
    const secret = 'HalaqahApp2024!';
    const signedData = '$studentId|$timestamp';
    final checksum = Hmac(sha256, utf8.encode(secret))
        .convert(utf8.encode(signedData))
        .toString()
        .substring(0, 16);
    final legacy = base64Encode(utf8.encode(jsonEncode({
      'sid': studentId,
      'ts': timestamp,
      'cs': checksum,
    })));

    expect(QrService.decodeQrData(legacy), studentId);
  });

  test('rejects unrelated text', () {
    expect(QrService.decodeQrData('not-a-halaqah-code'), isNull);
  });
}
