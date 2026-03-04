import 'package:flutter/material.dart';

import '../../modules/chunky/pages/chunky_page.dart';
import '../../modules/config/pages/config_page.dart';
import '../../modules/console/pages/console_page.dart';
import '../../modules/home/pages/home_page.dart';
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
  static const whitelist = '/whitelist';
  static const config = '/config';
  static const chunky = '/chunky';

  static final List<RouteDefinition> definitions = [
    RouteDefinition(path: home, label: 'Home', icon: Icons.home_rounded, builder: (_) => const HomePage()),
    RouteDefinition(
      path: console,
      label: 'Console',
      icon: Icons.terminal_rounded,
      builder: (_) => const ConsolePage(),
    ),
    RouteDefinition(
      path: whitelist,
      label: 'Whitelist',
      icon: Icons.verified_user_rounded,
      builder: (_) => const WhitelistPage(),
    ),
    RouteDefinition(
      path: config,
      label: 'Config',
      icon: Icons.settings_rounded,
      builder: (_) => const ConfigPage(),
    ),
    RouteDefinition(
      path: chunky,
      label: 'Chunky',
      icon: Icons.grid_view_rounded,
      builder: (_) => const ChunkyPage(),
    ),
  ];

  static RouteDefinition byPath(String path) {
    return definitions.firstWhere((route) => route.path == path, orElse: () => definitions.first);
  }
}
