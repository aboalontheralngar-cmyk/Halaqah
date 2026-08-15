import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/offline_exchange_policy.dart';

void main() {
  test('exchange code is strong, normalized, and readable', () {
    final code = OfflineExchangePolicy.generateCode(random: Random(2026));

    expect(code, hasLength(OfflineExchangePolicy.codeLength));
    expect(OfflineExchangePolicy.isValidCode(code), isTrue);
    expect(
      OfflineExchangePolicy.normalizeCode(
        OfflineExchangePolicy.formatCode(code).toLowerCase(),
      ),
      code,
    );
  });

  test('ambiguous or short exchange codes are rejected', () {
    expect(OfflineExchangePolicy.isValidCode('0000-0000-0000'), isFalse);
    expect(OfflineExchangePolicy.isValidCode('ABCD-EFGH'), isFalse);
  });

  test('exchange package expires after thirty minutes', () {
    final createdAt = DateTime.utc(2026, 7, 28, 12);
    final expiresAt = createdAt.add(OfflineExchangePolicy.validity);

    expect(
      OfflineExchangePolicy.isWithinValidityWindow(
        createdAt: createdAt,
        expiresAt: expiresAt,
        now: createdAt.add(const Duration(minutes: 29)),
      ),
      isTrue,
    );
    expect(
      OfflineExchangePolicy.isWithinValidityWindow(
        createdAt: createdAt,
        expiresAt: expiresAt,
        now: createdAt.add(const Duration(minutes: 31)),
      ),
      isFalse,
    );
  });
}
