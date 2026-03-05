import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../providers/console_provider.dart';
import '../subcomponents/console_input_bar.dart';
import '../subcomponents/console_output_view.dart';

class ConsolePage extends ConsumerWidget {
  const ConsolePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final console = ref.watch(consoleProvider);
    final notifier = ref.read(consoleProvider.notifier);
    final extension = Theme.of(context).extension<AppThemeExtension>();

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.console,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color:
                extension?.cardBackground ??
                Theme.of(context).colorScheme.surface,
            borderRadius: AppStyles.radiusLg,
            border: Border.all(
              color: extension?.cardBorder ?? Theme.of(context).dividerColor,
            ),
            boxShadow: AppStyles.softShadow(
              opacity: Theme.of(context).brightness == Brightness.dark
                  ? 0.16
                  : 0.08,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AppButton(
                    label: 'Copiar terminal',
                    icon: Icons.copy_all_rounded,
                    variant: AppVariant.info,
                    onPressed: () async {
                      final content = console.entries
                          .map((entry) => entry.message)
                          .join('\n');
                      await Clipboard.setData(ClipboardData(text: content));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Terminal copiado.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  AppButton(
                    label: 'Limpar terminal',
                    icon: Icons.cleaning_services_rounded,
                    variant: AppVariant.secondary,
                    onPressed: notifier.clearTerminal,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: ConsoleOutputView(entries: console.entries)),
              const SizedBox(height: 12),
              ConsoleInputBar(onSend: notifier.sendCommand),
            ],
          ),
        ),
      ),
    );
  }
}
