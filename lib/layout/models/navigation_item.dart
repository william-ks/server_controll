import 'package:flutter/material.dart';

class NavigationItem {
  const NavigationItem({
    required this.path,
    required this.label,
    required this.icon,
  });

  final String path;
  final String label;
  final IconData icon;
}
