import 'package:uuid/uuid.dart';

import '../models/audit_event.dart';
import 'database_service.dart';

/// Records security-sensitive local actions without storing student names,
/// phone numbers, backup passwords, or backup contents in the log.
class AuditLogService {
  AuditLogService({DatabaseService? database})
      : _database = database ?? DatabaseService();

  final DatabaseService _database;
  static const Uuid _uuid = Uuid();

  Future<void> record({
    required String eventType,
    required String entityType,
    String? entityId,
    String outcome = 'success',
    Map<String, dynamic> details = const <String, dynamic>{},
    DateTime? now,
  }) async {
    final sanitizedDetails = Map<String, dynamic>.from(details)
      ..removeWhere((key, _) => _sensitiveKeys.contains(key.toLowerCase()));
    await _database.saveAuditEvent(
      AuditEvent(
        id: _uuid.v4(),
        eventType: eventType,
        entityType: entityType,
        entityId: entityId,
        outcome: outcome,
        details: sanitizedDetails,
        createdAt: now ?? DateTime.now(),
      ),
    );
  }

  Future<List<AuditEvent>> recent({int limit = 200}) =>
      _database.getAuditEvents(limit: limit.clamp(1, 1000).toInt());

  Future<int> prune({required int retentionDays, DateTime? now}) {
    final safeDays = retentionDays.clamp(30, 3650).toInt();
    return _database.deleteAuditEventsBefore(
      (now ?? DateTime.now()).subtract(Duration(days: safeDays)),
    );
  }

  static const Set<String> _sensitiveKeys = <String>{
    'password',
    'passphrase',
    'token',
    'anon_key',
    'service_role',
    'phone',
    'guardian_phone',
    'parent_phone',
    'student_name',
    'backup_contents',
  };
}
