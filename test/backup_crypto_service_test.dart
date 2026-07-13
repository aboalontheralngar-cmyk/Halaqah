import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/backup_crypto_service.dart';

void main() {
  const crypto = BackupCryptoService(derivationIterations: 10000);
  const passphrase = 'عبارة حماية اختبارية قوية 2026';

  test('encrypted backup round-trips and contains no clear student data', () async {
    const clearText = '{"student_name":"طالب اختبار","rows":12}';
    final envelope = await crypto.encrypt(
      clearText: clearText,
      passphrase: passphrase,
      payloadVersion: '3.0',
      createdAt: DateTime.utc(2026, 7, 13),
    );

    expect(crypto.isEncryptedEnvelope(envelope), isTrue);
    expect(jsonEncode(envelope), isNot(contains('طالب اختبار')));
    expect(
      await crypto.decrypt(envelope: envelope, passphrase: passphrase),
      clearText,
    );
  });

  test('wrong passphrase is rejected before returning any content', () async {
    final envelope = await crypto.encrypt(
      clearText: '{"tables":{}}',
      passphrase: passphrase,
      payloadVersion: '3.0',
    );

    await expectLater(
      crypto.decrypt(
        envelope: envelope,
        passphrase: 'عبارة مختلفة تمامًا 2026',
      ),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });

  test('tampering with ciphertext is detected by AES-GCM authentication', () async {
    final envelope = await crypto.encrypt(
      clearText: '{"tables":{"students":[]}}',
      passphrase: passphrase,
      payloadVersion: '3.0',
    );
    final bytes = base64Decode(envelope['ciphertext'] as String);
    bytes[0] ^= 1;
    envelope['ciphertext'] = base64Encode(bytes);

    await expectLater(
      crypto.decrypt(envelope: envelope, passphrase: passphrase),
      throwsA(isA<BackupAuthenticationException>()),
    );
  });
}
