import 'package:flutter/material.dart';

import 'widgets/app_header.dart';
import 'widgets/app_sidebar.dart';

class DefaultLayout extends StatefulWidget {
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
  State<DefaultLayout> createState() => _DefaultLayoutState();
}

class _DefaultLayoutState extends State<DefaultLayout> {
  bool _sidebarOpen = true;

  void _navigate(String route) {
    if (route == widget.currentRoute) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          AppHeader(
            title: widget.title,
            onToggleSidebar: () => setState(() => _sidebarOpen = !_sidebarOpen),
          ),
          Expanded(
            child: Row(
              children: [
                if (_sidebarOpen)
                  AppSidebar(
                    currentRoute: widget.currentRoute,
                    onNavigate: _navigate,
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
