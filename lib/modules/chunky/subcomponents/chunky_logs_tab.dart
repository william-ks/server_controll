import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../providers/chunky_execution_provider.dart';

class ChunkyLogsTab extends ConsumerWidget {
  const ChunkyLogsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(chunkyExecutionProvider);
    final notifier = ref.read(chunkyExecutionProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${state.logs.length} linhas geradas',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            AppButton(
              label: 'Copiar logs',
              icon: Icons.copy_rounded,
              variant: AppVariant.info,
              transparent: true,
              onPressed: () async {
                final text = notifier.buildLogsAsPlainText().trim();
                if (text.isEmpty) return;
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Logs copiados com sucesso.')),
                  );
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: ext.cardBackground,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ext.cardBorder),
            ),
            child: state.logs.isEmpty
                ? const Center(child: Text('Nenhum log de execução registrado.'))
                : SelectableText(
                    notifier.buildLogsAsPlainText(),
                    style: const TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
