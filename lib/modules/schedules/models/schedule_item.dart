import 'schedule_action.dart';

class ScheduleItem {
  const ScheduleItem({
    this.id,
    required this.title,
    required this.cronExpression,
    required this.action,
    required this.withBackup,
    required this.isActive,
    this.lastExecutedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String title;
  final String cronExpression;
  final ScheduleAction action;
  final bool withBackup;
  final bool isActive;
  final DateTime? lastExecutedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduleItem copyWith({
    int? id,
    String? title,
    String? cronExpression,
    ScheduleAction? action,
    bool? withBackup,
    bool? isActive,
    DateTime? lastExecutedAt,
    bool clearLastExecutedAt = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      cronExpression: cronExpression ?? this.cronExpression,
      action: action ?? this.action,
      withBackup: withBackup ?? this.withBackup,
      isActive: isActive ?? this.isActive,
      lastExecutedAt: clearLastExecutedAt
          ? null
          : (lastExecutedAt ?? this.lastExecutedAt),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'cron_expression': cronExpression,
      'action': action.storageValue,
      'with_backup': withBackup ? 1 : 0,
      'is_active': isActive ? 1 : 0,
      'last_executed_at': lastExecutedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ScheduleItem.fromMap(Map<String, Object?> map) {
    return ScheduleItem(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      cronExpression: map['cron_expression'] as String,
      action: ScheduleActionX.fromStorage(map['action'] as String),
      withBackup: (map['with_backup'] as int? ?? 0) == 1,
      isActive: (map['is_active'] as int? ?? 0) == 1,
      lastExecutedAt: (map['last_executed_at'] as String?) == null
          ? null
          : DateTime.tryParse(map['last_executed_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
