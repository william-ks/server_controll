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
    this.maxBodyHeight = 420,
    this.onClose,
    this.showDividers = true,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double width;
  final double maxBodyHeight;
  final VoidCallback? onClose;
  final bool showDividers;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;

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
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
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
              if (showDividers)
                Divider(
                  height: 16,
                  thickness: 1,
                  color: dividerColor,
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                child: SingleChildScrollView(child: body),
              ),
              if (actions.isNotEmpty) ...[
                if (showDividers)
                  Divider(
                    height: 16,
                    thickness: 1,
                    color: dividerColor,
                  ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: actions,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
