import 'dart:convert';

class AuditEvent {
  final String id;
  final String eventType;
  final String entityType;
  final String? entityId;
  final String outcome;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    this.entityId,
    this.outcome = 'success',
    this.details = const <String, dynamic>{},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'event_type': eventType,
        'entity_type': entityType,
        'entity_id': entityId,
        'outcome': outcome,
        'details_json': jsonEncode(details),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  factory AuditEvent.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> details = const <String, dynamic>{};
    try {
      final decoded = jsonDecode(map['details_json']?.toString() ?? '{}');
      if (decoded is Map) details = Map<String, dynamic>.from(decoded);
    } catch (_) {
      details = const <String, dynamic>{};
    }
    return AuditEvent(
      id: map['id'].toString(),
      eventType: map['event_type']?.toString() ?? 'unknown',
      entityType: map['entity_type']?.toString() ?? 'unknown',
      entityId: map['entity_id']?.toString(),
      outcome: map['outcome']?.toString() ?? 'success',
      details: details,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
