import 'package:flutter/material.dart';

import '../buttons/app_button.dart';
import '../shared/app_variant.dart';
import 'app_modal.dart';

class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.body,
    this.confirmLabel = 'Confirmar',
    this.cancelLabel = 'Cancelar',
    this.confirmVariant = AppVariant.success,
    this.cancelVariant = AppVariant.danger,
    this.confirmIcon = Icons.check_rounded,
    this.width = 560,
    this.showDividers = true,
    this.showHeaderDivider,
    this.showFooterDivider,
    this.actionsAlignment = Alignment.centerRight,
    this.actionsWrapAlignment = WrapAlignment.end,
  }) : assert(
         message != null || body != null,
         'AppConfirmDialog requires a message or body.',
       );

  final IconData icon;
  final String title;
  final String? message;
  final Widget? body;
  final String confirmLabel;
  final String cancelLabel;
  final AppVariant confirmVariant;
  final AppVariant cancelVariant;
  final IconData? confirmIcon;
  final double width;
  final bool showDividers;
  final bool? showHeaderDivider;
  final bool? showFooterDivider;
  final AlignmentGeometry actionsAlignment;
  final WrapAlignment actionsWrapAlignment;

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: icon,
      title: title,
      width: width,
      showDividers: showDividers,
      showHeaderDivider: showHeaderDivider,
      showFooterDivider: showFooterDivider,
      actionsAlignment: actionsAlignment,
      actionsWrapAlignment: actionsWrapAlignment,
      body:
          body ??
          Text(
            message!,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
      actions: [
        AppButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(context).pop(false),
          type: AppButtonType.textButton,
          variant: cancelVariant,
        ),
        AppButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(context).pop(true),
          variant: confirmVariant,
          icon: confirmIcon,
        ),
      ],
    );
  }
}

Future<bool> showAppConfirmDialog(
  BuildContext context, {
  required IconData icon,
  required String title,
  String? message,
  Widget? body,
  String confirmLabel = 'Confirmar',
  String cancelLabel = 'Cancelar',
  AppVariant confirmVariant = AppVariant.success,
  AppVariant cancelVariant = AppVariant.danger,
  IconData? confirmIcon = Icons.check_rounded,
  double width = 560,
  bool showDividers = true,
  bool? showHeaderDivider,
  bool? showFooterDivider,
  AlignmentGeometry actionsAlignment = Alignment.centerRight,
  WrapAlignment actionsWrapAlignment = WrapAlignment.end,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AppConfirmDialog(
      icon: icon,
      title: title,
      message: message,
      body: body,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      confirmVariant: confirmVariant,
      cancelVariant: cancelVariant,
      confirmIcon: confirmIcon,
      width: width,
      showDividers: showDividers,
      showHeaderDivider: showHeaderDivider,
      showFooterDivider: showFooterDivider,
      actionsAlignment: actionsAlignment,
      actionsWrapAlignment: actionsWrapAlignment,
    ),
  );
  return confirmed == true;
}
