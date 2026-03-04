import 'package:flutter/material.dart';

import '../../config/theme/app_theme_extension.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    required this.onToggleSidebar,
    required this.sidebarOpen,
    required this.onToggleTheme,
    required this.isDarkMode,
  });

  final String title;
  final VoidCallback onToggleSidebar;
  final bool sidebarOpen;
  final VoidCallback onToggleTheme;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(bottom: BorderSide(color: ext.subtleDivider)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(sidebarOpen ? Icons.close_rounded : Icons.menu_rounded),
            onPressed: onToggleSidebar,
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Alternar tema',
            icon: Icon(isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded),
            onPressed: onToggleTheme,
          ),
        ],
      ),
    );
  }
}
