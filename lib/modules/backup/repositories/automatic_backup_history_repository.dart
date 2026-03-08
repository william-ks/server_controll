import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';

final automaticBackupHistoryRepositoryProvider =
    Provider<AutomaticBackupHistoryRepository>(
      (_) => AutomaticBackupHistoryRepository(),
    );

class AutomaticBackupHistoryRepository {
  Future<void> logAttempt({
    required int? scheduleId,
    required String scheduleTitle,
    required String scheduleAction,
    required String backupKind,
    required int attemptNumber,
    required String resultStatus,
    String? message,
  }) async {
    final db = await AppDatabase.instance.database;
    await db.insert('automatic_backup_history', {
      'schedule_id': scheduleId,
      'schedule_title': scheduleTitle.trim(),
      'schedule_action': scheduleAction.trim(),
      'backup_kind': backupKind.trim(),
      'attempt_number': attemptNumber,
      'result_status': resultStatus.trim(),
      'message': message?.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
