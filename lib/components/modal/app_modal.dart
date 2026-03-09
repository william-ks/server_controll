import 'package:flutter/material.dart';

import '../../config/theme/app_theme_extension.dart';

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
    this.showHeaderDivider,
    this.showFooterDivider,
    this.actionsAlignment = Alignment.centerRight,
    this.actionsWrapAlignment = WrapAlignment.end,
  });

  final IconData icon;
  final String title;
  final Widget body;
  final List<Widget> actions;
  final double width;
  final double maxBodyHeight;
  final VoidCallback? onClose;
  final bool showDividers;
  final bool? showHeaderDivider;
  final bool? showFooterDivider;
  final AlignmentGeometry actionsAlignment;
  final WrapAlignment actionsWrapAlignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final effectiveBodyHeight = (screenHeight * 0.58).clamp(180.0, maxBodyHeight);
    final showHeader = showHeaderDivider ?? showDividers;
    final showFooter = showFooterDivider ?? showDividers;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: ext.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
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
              if (showHeader)
                Divider(
                  height: 16,
                  thickness: 1,
                  color: dividerColor,
                ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: effectiveBodyHeight),
                child: SingleChildScrollView(child: body),
              ),
              if (actions.isNotEmpty) ...[
                if (showFooter)
                  Divider(
                    height: 16,
                    thickness: 1,
                    color: dividerColor,
                  ),
                Align(
                  alignment: actionsAlignment,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: actionsWrapAlignment,
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
