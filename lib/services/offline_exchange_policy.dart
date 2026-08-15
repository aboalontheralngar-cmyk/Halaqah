import 'dart:math';

class OfflineExchangePolicy {
  const OfflineExchangePolicy._();

  static const Duration validity = Duration(minutes: 30);
  static const int codeLength = 12;
  static const String _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode({Random? random}) {
    final secureRandom = random ?? Random.secure();
    return List<String>.generate(
      codeLength,
      (_) => _alphabet[secureRandom.nextInt(_alphabet.length)],
    ).join();
  }

  static String normalizeCode(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static bool isValidCode(String value) {
    final normalized = normalizeCode(value);
    if (normalized.length != codeLength) return false;
    return normalized.runes.every(
      (codePoint) => _alphabet.contains(String.fromCharCode(codePoint)),
    );
  }

  static String formatCode(String value) {
    final normalized = normalizeCode(value);
    final groups = <String>[];
    for (var index = 0; index < normalized.length; index += 4) {
      groups.add(
        normalized.substring(
          index,
          min(index + 4, normalized.length),
        ),
      );
    }
    return groups.join('-');
  }

  static String passphrase(String code) {
    final normalized = normalizeCode(code);
    if (!isValidCode(normalized)) {
      throw const FormatException('كود الربط غير صالح');
    }
    return 'Halaqah-Offline-$normalized-Link';
  }

  static bool isWithinValidityWindow({
    required DateTime createdAt,
    required DateTime expiresAt,
    DateTime? now,
  }) {
    final current = (now ?? DateTime.now()).toUtc();
    final created = createdAt.toUtc();
    final expires = expiresAt.toUtc();
    if (expires.isBefore(created) ||
        expires.difference(created) > validity) {
      return false;
    }
    if (created.isAfter(current.add(const Duration(minutes: 5)))) {
      return false;
    }
    return current.isBefore(expires) || current.isAtSameMomentAs(expires);
  }
}
