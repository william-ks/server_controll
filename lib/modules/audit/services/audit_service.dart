import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../models/audit_event.dart';

final auditServiceProvider = Provider<AuditService>((_) => AuditService());

class AuditService {
  Future<void> logEvent({
    required String eventType,
    required String entityType,
    String? entityId,
    required String actorType,
    String? actorId,
    required Map<String, Object?> payload,
    required String resultStatus,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('audit_events', {
      'event_type': eventType.trim(),
      'entity_type': entityType.trim(),
      'entity_id': entityId?.trim(),
      'actor_type': actorType.trim(),
      'actor_id': actorId?.trim(),
      'payload_json': jsonEncode(payload),
      'result_status': resultStatus.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<AuditEvent>> listEvents({
    String? eventType,
    DateTime? from,
    DateTime? to,
    String? player,
    String? actionQuery,
    int limit = 600,
  }) async {
    final db = await AppDatabase.instance.database;
    final where = <String>[];
    final args = <Object?>[];

    final normalizedType = (eventType ?? '').trim();
    if (normalizedType.isNotEmpty) {
      where.add('event_type = ?');
      args.add(normalizedType);
    }

    if (from != null) {
      where.add('created_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('created_at <= ?');
      args.add(to.toIso8601String());
    }

    final normalizedPlayer = (player ?? '').trim().toLowerCase();
    if (normalizedPlayer.isNotEmpty) {
      where.add('(LOWER(actor_id) LIKE ? OR LOWER(payload_json) LIKE ?)');
      args.add('%$normalizedPlayer%');
      args.add('%$normalizedPlayer%');
    }

    final normalizedAction = (actionQuery ?? '').trim().toLowerCase();
    if (normalizedAction.isNotEmpty) {
      where.add(
        '(LOWER(event_type) LIKE ? OR LOWER(entity_type) LIKE ? OR LOWER(payload_json) LIKE ?)',
      );
      args.add('%$normalizedAction%');
      args.add('%$normalizedAction%');
      args.add('%$normalizedAction%');
    }

    final rows = await db.query(
      'audit_events',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: where.isEmpty ? null : args,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(AuditEvent.fromMap).toList();
  }
}
