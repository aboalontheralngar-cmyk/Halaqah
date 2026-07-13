import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BackupPassphraseStore {
  BackupPassphraseStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            FlutterSecureStorage(
              aOptions: AndroidOptions(migrateWithBackup: true),
            );

  static const String _storageKey = 'halaqah_backup_passphrase_v1';
  final FlutterSecureStorage _storage;

  Future<bool> get isConfigured async =>
      (await _storage.read(key: _storageKey))?.isNotEmpty == true;

  Future<String?> read() => _storage.read(key: _storageKey);

  Future<void> save(String passphrase) async {
    if (passphrase.runes.length < 10 || passphrase.runes.length > 256) {
      throw ArgumentError(
        'يجب أن تكون عبارة حماية النسخ بين 10 و256 حرفًا',
      );
    }
    await _storage.write(key: _storageKey, value: passphrase);
  }

  Future<void> clear() => _storage.delete(key: _storageKey);
}
