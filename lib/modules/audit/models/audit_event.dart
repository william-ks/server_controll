class AuditEvent {
  const AuditEvent({
    required this.id,
    required this.eventType,
    required this.entityType,
    required this.entityId,
    required this.actorType,
    required this.actorId,
    required this.payloadJson,
    required this.resultStatus,
    required this.createdAt,
  });

  final int id;
  final String eventType;
  final String entityType;
  final String? entityId;
  final String actorType;
  final String? actorId;
  final String payloadJson;
  final String resultStatus;
  final DateTime createdAt;

  factory AuditEvent.fromMap(Map<String, Object?> row) {
    return AuditEvent(
      id: row['id'] as int? ?? 0,
      eventType: row['event_type'] as String? ?? '',
      entityType: row['entity_type'] as String? ?? '',
      entityId: row['entity_id'] as String?,
      actorType: row['actor_type'] as String? ?? '',
      actorId: row['actor_id'] as String?,
      payloadJson: row['payload_json'] as String? ?? '{}',
      resultStatus: row['result_status'] as String? ?? '',
      createdAt:
          DateTime.tryParse(row['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
