import 'maintenance_mode.dart';

class MaintenanceSnapshot {
  const MaintenanceSnapshot({
    required this.isActive,
    required this.mode,
    this.startsAt,
    this.endsAt,
    required this.countdownSeconds,
    this.motdBefore,
    this.motdDuring,
    this.iconBeforePath,
    this.iconDuringPath,
  });

  final bool isActive;
  final MaintenanceMode mode;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int countdownSeconds;
  final String? motdBefore;
  final String? motdDuring;
  final String? iconBeforePath;
  final String? iconDuringPath;

  factory MaintenanceSnapshot.inactive() {
    return const MaintenanceSnapshot(
      isActive: false,
      mode: MaintenanceMode.total,
      countdownSeconds: 0,
    );
  }
}
