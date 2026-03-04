import 'package:flutter/material.dart';

import '../../config/theme/app_styles.dart';

class AppModal extends StatelessWidget {
  const AppModal({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.actions = const [],
    this.width = 520,
    this.onClose,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double width;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppStyles.radiusLg),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppStyles.radiusLg,
          boxShadow: AppStyles.softShadow(opacity: 0.25),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: scheme.primary, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(
                    onPressed: onClose ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              body,
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: actions,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
