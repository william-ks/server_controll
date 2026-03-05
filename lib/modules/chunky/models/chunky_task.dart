import 'chunky_task_status.dart';

class ChunkyTask {
  const ChunkyTask({
    this.id,
    required this.name,
    required this.world,
    required this.centerX,
    required this.centerZ,
    required this.radius,
    required this.shape,
    required this.pattern,
    required this.backupBeforeStart,
    required this.status,
    required this.hasEverStarted,
    required this.createdAt,
    required this.updatedAt,
    this.lastRunAt,
    this.deletedAt,
  });

  final int? id;
  final String name;
  final String world;
  final int centerX;
  final int centerZ;
  final double radius;
  final String shape;
  final String pattern;
  final bool backupBeforeStart;
  final ChunkyTaskStatus status;
  final bool hasEverStarted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastRunAt;
  final DateTime? deletedAt;

  bool get isDeleted => deletedAt != null;

  ChunkyTask copyWith({
    int? id,
    String? name,
    String? world,
    int? centerX,
    int? centerZ,
    double? radius,
    String? shape,
    String? pattern,
    bool? backupBeforeStart,
    ChunkyTaskStatus? status,
    bool? hasEverStarted,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastRunAt,
    bool clearLastRunAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    return ChunkyTask(
      id: id ?? this.id,
      name: name ?? this.name,
      world: world ?? this.world,
      centerX: centerX ?? this.centerX,
      centerZ: centerZ ?? this.centerZ,
      radius: radius ?? this.radius,
      shape: shape ?? this.shape,
      pattern: pattern ?? this.pattern,
      backupBeforeStart: backupBeforeStart ?? this.backupBeforeStart,
      status: status ?? this.status,
      hasEverStarted: hasEverStarted ?? this.hasEverStarted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastRunAt: clearLastRunAt ? null : (lastRunAt ?? this.lastRunAt),
      deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      if (id != null) 'id': id,
      'name': name,
      'world': world,
      'center_x': centerX,
      'center_z': centerZ,
      'radius': radius,
      'shape': shape,
      'pattern': pattern,
      'backup_before_start': backupBeforeStart ? 1 : 0,
      'status': status.storageValue,
      'has_ever_started': hasEverStarted ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_run_at': lastRunAt?.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }

  factory ChunkyTask.fromMap(Map<String, Object?> map) {
    return ChunkyTask(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      world: (map['world'] as String?) ?? 'overworld',
      centerX: (map['center_x'] as num?)?.toInt() ?? 0,
      centerZ: (map['center_z'] as num?)?.toInt() ?? 0,
      radius: (map['radius'] as num?)?.toDouble() ?? 1000,
      shape: (map['shape'] as String?) ?? 'square',
      pattern: (map['pattern'] as String?) ?? 'spiral',
      backupBeforeStart: (map['backup_before_start'] as int? ?? 0) == 1,
      status: ChunkyTaskStatusX.fromStorage(
        (map['status'] as String?) ?? ChunkyTaskStatus.draft.storageValue,
      ),
      hasEverStarted: (map['has_ever_started'] as int? ?? 0) == 1,
      createdAt:
          DateTime.tryParse((map['created_at'] as String?) ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse((map['updated_at'] as String?) ?? '') ??
          DateTime.now(),
      lastRunAt: (map['last_run_at'] as String?) == null
          ? null
          : DateTime.tryParse(map['last_run_at'] as String),
      deletedAt: (map['deleted_at'] as String?) == null
          ? null
          : DateTime.tryParse(map['deleted_at'] as String),
    );
  }
}
