import 'package:flutter/material.dart';

import '../../config/routes/routes_config.dart';
import '../../config/theme/app_theme_extension.dart';
import '../models/navigation_item.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
  });

  final String currentRoute;
  final ValueChanged<String> onNavigate;

  List<NavigationItem> _items() {
    return AppRoutes.definitions
        .where((route) => route.showInSidebar)
        .map((route) => NavigationItem(path: route.path, label: route.label, icon: route.icon))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final items = _items();

    return Container(
      width: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(right: BorderSide(color: ext.subtleDivider)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SidebarTile(
                label: item.label,
                icon: item.icon,
                active: item.path == currentRoute,
                onTap: () => onNavigate(item.path),
              ),
            ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.extension<AppThemeExtension>()!;

    return Material(
      color: active ? ext.sidebarItemBackground : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        hoverColor: ext.hoverOverlay,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 4,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? ext.selectedIndicator : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: active ? ext.selectedIndicator : scheme.onSurfaceVariant),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? scheme.onSurface : scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
