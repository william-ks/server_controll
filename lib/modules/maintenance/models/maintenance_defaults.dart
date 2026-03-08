import '../../../database/app_database.dart';
import 'maintenance_mode.dart';

class MaintenanceDefaults {
  const MaintenanceDefaults({
    required this.defaultMode,
    required this.defaultCountdownSeconds,
    required this.motdTotal,
    required this.motdAdminsOnly,
    required this.maintenanceIconPath,
    required this.adminNicknames,
  });

  final MaintenanceMode defaultMode;
  final int defaultCountdownSeconds;
  final String motdTotal;
  final String motdAdminsOnly;
  final String maintenanceIconPath;
  final String adminNicknames;

  factory MaintenanceDefaults.defaults() {
    return const MaintenanceDefaults(
      defaultMode: MaintenanceMode.total,
      defaultCountdownSeconds: 60,
      motdTotal: 'Servidor em manutenção',
      motdAdminsOnly: 'Servidor em manutenção (somente admins)',
      maintenanceIconPath: '',
      adminNicknames: '',
    );
  }

  static Future<MaintenanceDefaults> fromDatabase(AppDatabase db) async {
    final fallback = MaintenanceDefaults.defaults();
    final modeRaw =
        await db.getSetting('maintenance_default_mode') ??
        fallback.defaultMode.storageValue;
    final countdownRaw =
        await db.getSetting('maintenance_countdown_default') ??
        '${fallback.defaultCountdownSeconds}';
    final motdTotal =
        await db.getSetting('maintenance_motd_total') ?? fallback.motdTotal;
    final motdAdminsOnly =
        await db.getSetting('maintenance_motd_admin') ??
        fallback.motdAdminsOnly;
    final iconPath =
        await db.getSetting('maintenance_icon_path') ??
        fallback.maintenanceIconPath;
    final adminNicknames =
        await db.getSetting('maintenance_admin_nicknames') ??
        fallback.adminNicknames;

    return MaintenanceDefaults(
      defaultMode: MaintenanceModeX.fromStorage(modeRaw),
      defaultCountdownSeconds:
          int.tryParse(countdownRaw) ?? fallback.defaultCountdownSeconds,
      motdTotal: motdTotal,
      motdAdminsOnly: motdAdminsOnly,
      maintenanceIconPath: iconPath,
      adminNicknames: adminNicknames,
    );
  }
}
