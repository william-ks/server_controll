import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/providers/theme_provider.dart';
import 'widgets/app_header.dart';
import 'widgets/app_sidebar.dart';

class DefaultLayout extends ConsumerStatefulWidget {
  const DefaultLayout({
    super.key,
    required this.currentRoute,
    required this.child,
    this.title = 'MineControl',
  });

  final String currentRoute;
  final Widget child;
  final String title;

  @override
  ConsumerState<DefaultLayout> createState() => _DefaultLayoutState();
}

class _DefaultLayoutState extends ConsumerState<DefaultLayout> {
  bool _sidebarOpen = true;

  void _navigate(String route) {
    if (route == widget.currentRoute) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: widget.title,
            sidebarOpen: _sidebarOpen,
            onToggleSidebar: () => setState(() => _sidebarOpen = !_sidebarOpen),
            onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
            isDarkMode: isDark,
          ),
          Expanded(
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubicEmphasized,
                  width: _sidebarOpen ? 240 : 0,
                  child: ClipRect(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeInOut,
                      opacity: _sidebarOpen ? 1 : 0,
                      child: _sidebarOpen
                          ? AppSidebar(
                              currentRoute: widget.currentRoute,
                              onNavigate: _navigate,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
                Expanded(child: widget.child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
