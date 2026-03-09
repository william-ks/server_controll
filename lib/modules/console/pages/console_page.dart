import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
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

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.console,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
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
    );
  }
}
