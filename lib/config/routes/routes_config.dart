import 'package:flutter/material.dart';

import '../../modules/chunky/pages/chunky_page.dart';
import '../../modules/config/pages/config_page.dart';
import '../../modules/console/pages/console_page.dart';
import '../../modules/home/pages/home_page.dart';
import '../../modules/backup/pages/backups_page.dart';
import '../../modules/audit/pages/audit_page.dart';
import '../../modules/schedules/pages/schedules_page.dart';
import '../../modules/players/pages/players_page.dart';
import '../../modules/whitelist/pages/whitelist_page.dart';

class RouteDefinition {
  const RouteDefinition({
    required this.path,
    required this.label,
    required this.icon,
    required this.builder,
    this.showInSidebar = true,
  });

  final String path;
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  final bool showInSidebar;
}

class AppRoutes {
  AppRoutes._();

  static const home = '/home';
  static const console = '/console';
  static const players = '/players';
  static const whitelist = '/whitelist';
  static const schedules = '/schedules';
  static const backups = '/backups';
  static const audit = '/audit';
  static const chunky = '/chunky';
  static const config = '/config';

  static final List<RouteDefinition> definitions = [
    RouteDefinition(
      path: home,
      label: 'Home',
      icon: Icons.home_rounded,
      builder: (_) => const HomePage(),
    ),
    RouteDefinition(
      path: console,
      label: 'Console',
      icon: Icons.terminal_rounded,
      builder: (_) => const ConsolePage(),
    ),
    RouteDefinition(
      path: players,
      label: 'Players',
      icon: Icons.groups_rounded,
      builder: (_) => const PlayersPage(),
    ),
    RouteDefinition(
      path: whitelist,
      label: 'Whitelist (legado)',
      icon: Icons.verified_user_rounded,
      builder: (_) => const WhitelistPage(),
      showInSidebar: false,
    ),
    RouteDefinition(
      path: schedules,
      label: 'Agendamentos',
      icon: Icons.schedule_rounded,
      builder: (_) => const SchedulesPage(),
    ),
    RouteDefinition(
      path: backups,
      label: 'Backups',
      icon: Icons.backup_table_rounded,
      builder: (_) => const BackupsPage(),
    ),
    RouteDefinition(
      path: audit,
      label: 'Auditoria',
      icon: Icons.fact_check_rounded,
      builder: (_) => const AuditPage(),
    ),
    RouteDefinition(
      path: chunky,
      label: 'Chunky',
      icon: Icons.grid_view_rounded,
      builder: (_) => const ChunkyPage(),
    ),
    RouteDefinition(
      path: config,
      label: 'Config',
      icon: Icons.settings_rounded,
      builder: (_) => const ConfigPage(),
    ),
  ];

  static RouteDefinition byPath(String path) {
    return definitions.firstWhere(
      (route) => route.path == path,
      orElse: () => definitions.first,
    );
  }
}
