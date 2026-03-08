import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme/app_theme_extension.dart';
import '../../modules/server/providers/server_runtime_provider.dart';
import 'server_status_badge.dart';

class AppHeader extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final runtime = ref.watch(serverRuntimeProvider);
    final canShowInlineStatus = MediaQuery.sizeOf(context).width >= 920;

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
          if (canShowInlineStatus) ...[
            ServerStatusBadge(lifecycle: runtime.lifecycle, compact: true),
            const SizedBox(width: 6),
          ],
          IconButton(
            tooltip: 'Notificações',
            icon: const Icon(Icons.notifications_none_rounded),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Funcionalidade em desenvolvimento.'),
                ),
              );
            },
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
