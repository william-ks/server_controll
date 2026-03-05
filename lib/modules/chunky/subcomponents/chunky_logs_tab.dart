import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';
import '../providers/chunky_execution_provider.dart';

class ChunkyLogsTab extends ConsumerWidget {
  const ChunkyLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chunkyExecutionProvider);
    final notifier = ref.read(chunkyExecutionProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppButton(
              label: 'Copiar logs',
              icon: Icons.copy_rounded,
              variant: AppVariant.info,
              onPressed: () async {
                final text = notifier.buildLogsAsPlainText().trim();
                if (text.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copiados.')),
                  );
                }
              },
            ),
            const SizedBox(width: 8),
            Text(
              '${state.logs.length} linhas',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: state.logs.isEmpty
                ? const Text('Sem logs de execução do Chunky.')
                : SelectableText(
                    notifier.buildLogsAsPlainText(),
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12.5,
                      height: 1.3,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
