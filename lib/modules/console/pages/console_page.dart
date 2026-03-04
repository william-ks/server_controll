import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../layout/default_layout.dart';
import '../../../routes/routes_config.dart';
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ConsoleOutputView(
                entries: console.entries,
                autoScroll: console.autoScroll,
              ),
            ),
            const SizedBox(height: 12),
            ConsoleInputBar(
              onSend: notifier.sendCommand,
              autoScroll: console.autoScroll,
              onToggleScroll: notifier.toggleAutoScroll,
            ),
          ],
        ),
      ),
    );
  }
}
