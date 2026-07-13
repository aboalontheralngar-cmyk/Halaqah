import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

class BackupCryptoException implements Exception {
  final String message;

  const BackupCryptoException(this.message);

  @override
  String toString() => message;
}

class BackupAuthenticationException extends BackupCryptoException {
  const BackupAuthenticationException()
      : super('عبارة الحماية غير صحيحة أو أن ملف النسخة تالف');
}

/// Encodes Halaqah backups in an authenticated, versioned envelope.
///
/// AES-GCM protects both confidentiality and integrity. A fresh random salt and
/// nonce are generated for every file, so identical backups never produce the
/// same encrypted content.
class BackupCryptoService {
  final int derivationIterations;

  const BackupCryptoService({
    this.derivationIterations = defaultKdfIterations,
  }) : assert(derivationIterations >= 10000);

  static const String format = 'halaqah-encrypted-backup';
  static const int envelopeVersion = 1;
  static const int defaultKdfIterations = 600000;
  static const int _saltLength = 16;
  static const List<int> _associatedData = <int>[
    104,
    97,
    108,
    97,
    113,
    97,
    104,
    45,
    98,
    97,
    99,
    107,
    117,
    112,
    45,
    118,
    49,
  ];

  Future<Map<String, dynamic>> encrypt({
    required String clearText,
    required String passphrase,
    required String payloadVersion,
    DateTime? createdAt,
  }) async {
    _validatePassphrase(passphrase);
    final salt = _randomBytes(_saltLength);
    final secretKey = await _deriveKey(
      passphrase: passphrase,
      salt: salt,
      iterations: derivationIterations,
    );
    final algorithm = AesGcm.with256bits();
    final secretBox = await algorithm.encrypt(
      utf8.encode(clearText),
      secretKey: secretKey,
      aad: _associatedData,
    );

    return <String, dynamic>{
      'format': format,
      'envelope_version': envelopeVersion,
      'payload_version': payloadVersion,
      'created_at': (createdAt ?? DateTime.now()).toUtc().toIso8601String(),
      'encryption': <String, dynamic>{
        'cipher': 'AES-256-GCM',
        'kdf': 'PBKDF2-HMAC-SHA256',
        'iterations': derivationIterations,
        'salt': base64Encode(salt),
        'nonce': base64Encode(secretBox.nonce),
        'mac': base64Encode(secretBox.mac.bytes),
      },
      'ciphertext': base64Encode(secretBox.cipherText),
    };
  }

  Future<String> decrypt({
    required Map<String, dynamic> envelope,
    required String passphrase,
  }) async {
    _validatePassphrase(passphrase);
    _validateEnvelopeHeader(envelope);
    try {
      final encryption = Map<String, dynamic>.from(
        envelope['encryption'] as Map,
      );
      final iterations = encryption['iterations'] as int;
      if (iterations < 10000 || iterations > 2000000) {
        throw const BackupCryptoException(
          'إعداد اشتقاق المفتاح في النسخة غير صالح',
        );
      }
      final salt = base64Decode(encryption['salt'] as String);
      final nonce = base64Decode(encryption['nonce'] as String);
      final mac = base64Decode(encryption['mac'] as String);
      final cipherText = base64Decode(envelope['ciphertext'] as String);
      if (salt.length < _saltLength || nonce.length != 12 || mac.length != 16) {
        throw const BackupCryptoException('بنية ملف النسخة المشفرة غير صالحة');
      }

      final secretKey = await _deriveKey(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
      );
      final clearBytes = await AesGcm.with256bits().decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: secretKey,
        aad: _associatedData,
      );
      return utf8.decode(clearBytes);
    } on SecretBoxAuthenticationError {
      throw const BackupAuthenticationException();
    } on BackupCryptoException {
      rethrow;
    } on FormatException {
      throw const BackupCryptoException('ترميز ملف النسخة غير صالح');
    } on TypeError {
      throw const BackupCryptoException('بنية ملف النسخة المشفرة غير صالحة');
    }
  }

  bool isEncryptedEnvelope(Map<String, dynamic> value) =>
      value['format'] == format && value['envelope_version'] == envelopeVersion;

  void _validateEnvelopeHeader(Map<String, dynamic> envelope) {
    if (!isEncryptedEnvelope(envelope)) {
      throw const BackupCryptoException('صيغة النسخة المشفرة غير مدعومة');
    }
    final encryption = envelope['encryption'];
    if (encryption is! Map ||
        encryption['cipher'] != 'AES-256-GCM' ||
        encryption['kdf'] != 'PBKDF2-HMAC-SHA256' ||
        encryption['iterations'] is! int ||
        encryption['salt'] is! String ||
        encryption['nonce'] is! String ||
        encryption['mac'] is! String ||
        envelope['ciphertext'] is! String) {
      throw const BackupCryptoException('بنية ملف النسخة المشفرة غير صالحة');
    }
  }

  Future<SecretKey> _deriveKey({
    required String passphrase,
    required List<int> salt,
    required int iterations,
  }) {
    return Pbkdf2.hmacSha256(iterations: iterations, bits: 256)
        .deriveKeyFromPassword(password: passphrase, nonce: salt);
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  void _validatePassphrase(String passphrase) {
    if (passphrase.runes.length < 10) {
      throw const BackupCryptoException(
        'يجب ألا تقل عبارة حماية النسخ الاحتياطية عن 10 أحرف',
      );
    }
    if (passphrase.runes.length > 256) {
      throw const BackupCryptoException('عبارة الحماية أطول من الحد المسموح');
    }
  }
}
