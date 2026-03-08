enum MaintenanceMode { total, adminsOnly }

extension MaintenanceModeX on MaintenanceMode {
  String get storageValue => switch (this) {
    MaintenanceMode.total => 'total',
    MaintenanceMode.adminsOnly => 'admins_only',
  };

  String get label => switch (this) {
    MaintenanceMode.total => 'Manutenção total',
    MaintenanceMode.adminsOnly => 'Somente admins do app',
  };

  static MaintenanceMode fromStorage(String raw) {
    return switch (raw) {
      'admins_only' => MaintenanceMode.adminsOnly,
      _ => MaintenanceMode.total,
    };
  }
}
