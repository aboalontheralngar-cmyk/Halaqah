import 'package:flutter_test/flutter_test.dart';
import 'package:halaqah_teacher/services/audit_log_service.dart';
import 'package:halaqah_teacher/services/operational_incident_service.dart';

class _FakeAuditLogService extends AuditLogService {
  final List<Map<String, dynamic>> records = <Map<String, dynamic>>[];

  @override
  Future<void> record({
    required String eventType,
    required String entityType,
    String? entityId,
    String outcome = 'success',
    Map<String, dynamic> details = const <String, dynamic>{},
    DateTime? now,
  }) async {
    records.add(<String, dynamic>{
      'event_type': eventType,
      'entity_type': entityType,
      'outcome': outcome,
      'details': details,
    });
  }
}

void main() {
  test('fingerprint removes raw paths and exception messages', () {
    final first = OperationalIncidentService.stackFingerprint(
      Exception('student private value'),
      StackTrace.fromString(
        r'#0 C:\Users\teacher\Halaqah\lib\main.dart:12:3',
      ),
    );
    final second = OperationalIncidentService.stackFingerprint(
      Exception('different private value'),
      StackTrace.fromString(
        r'#0 D:\Build\Halaqah\lib\main.dart:99:8',
      ),
    );

    expect(first, hasLength(16));
    expect(first, second);
    expect(first, isNot(contains('student')));
  });

  test('capture stores only structural diagnostic fields', () async {
    final audit = _FakeAuditLogService();
    final service = OperationalIncidentService(audit: audit);
    final now = DateTime.utc(2026, 7, 18, 10);

    await service.capture(
      error: StateError('private message'),
      stackTrace: StackTrace.fromString('#0 saveThing (private.dart:1:2)'),
      source: 'flutter framework',
      now: now,
    );

    expect(audit.records, hasLength(1));
    final details = audit.records.single['details'] as Map<String, dynamic>;
    expect(details.keys, containsAll(<String>[
      'source',
      'error_type',
      'fingerprint',
      'fatal',
    ]));
    expect(details.toString(), isNot(contains('private message')));
    expect(details.toString(), isNot(contains('saveThing')));
  });

  test('identical incidents are rate-limited for five minutes', () async {
    final audit = _FakeAuditLogService();
    final service = OperationalIncidentService(audit: audit);
    final stack = StackTrace.fromString('#0 uniqueFrame (unique.dart:7:9)');
    final now = DateTime.utc(2026, 7, 18, 11);

    await service.capture(
      error: ArgumentError('first'),
      stackTrace: stack,
      source: 'test',
      now: now,
    );
    await service.capture(
      error: ArgumentError('second'),
      stackTrace: stack,
      source: 'test',
      now: now.add(const Duration(minutes: 1)),
    );

    expect(audit.records, hasLength(1));
  });
}
