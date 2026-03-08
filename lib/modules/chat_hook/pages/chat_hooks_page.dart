import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_styles.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../database/app_database.dart';
import '../../../layout/default_layout.dart';
import '../services/chat_command_registry.dart';

class ChatHooksPage extends ConsumerStatefulWidget {
  const ChatHooksPage({super.key});

  @override
  ConsumerState<ChatHooksPage> createState() => _ChatHooksPageState();
}

class _ChatHooksPageState extends ConsumerState<ChatHooksPage> {
  late Future<List<_HookHistoryItem>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _historyFuture = _loadHistory();
  }

  Future<List<_HookHistoryItem>> _loadHistory() async {
    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'chat_hook_history',
      orderBy: 'created_at DESC',
      limit: 120,
    );
    return rows.map((row) {
      return _HookHistoryItem(
        player: (row['player'] as String? ?? '').trim(),
        command: ((row['parsed_command'] as String?) ?? '').trim(),
        status: (row['result_status'] as String? ?? 'unknown').trim(),
        message: (row['result_message'] as String? ?? '').trim(),
        createdAt:
            DateTime.tryParse((row['created_at'] as String? ?? '')) ??
            DateTime.now(),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final commands = ref.read(chatCommandRegistryProvider).allDefinitions();
    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.hooks,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: AppStyles.radiusLg,
            border: Border.all(color: Theme.of(context).dividerColor),
            boxShadow: AppStyles.softShadow(opacity: 0.18),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hooks cadastrados',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < commands.length; i++) ...[
                    Expanded(child: _HookCommandCard(command: commands[i])),
                    if (i < commands.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Últimas execuções',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Atualizar',
                    onPressed: () {
                      setState(() {
                        _historyFuture = _loadHistory();
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: FutureBuilder<List<_HookHistoryItem>>(
                  future: _historyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          snapshot.error.toString().replaceFirst('Bad state: ', ''),
                        ),
                      );
                    }
                    final items = snapshot.data ?? const <_HookHistoryItem>[];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'Nenhum hook executado até agora. Os eventos já estão cadastrados acima.',
                        ),
                      );
                    }
                    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = items[index];
                        return Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).dividerColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${item.player} • ${item.command.isEmpty ? 'comando não identificado' : item.command} • ${item.status}',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (item.message.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(item.message),
                              ],
                              const SizedBox(height: 4),
                              Text(
                                formatter.format(item.createdAt.toLocal()),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HookCommandCard extends StatelessWidget {
  const _HookCommandCard({required this.command});

  final ChatCommandDefinition command;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ext.cardBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ext.cardBorder.withValues(alpha: 0.65)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hub_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '<server> ${command.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            command.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            command.permission == ChatCommandPermissionPolicy.appAdmin
                ? 'Permissão: admin do app'
                : 'Permissão: todos',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: ext.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

class _HookHistoryItem {
  const _HookHistoryItem({
    required this.player,
    required this.command,
    required this.status,
    required this.message,
    required this.createdAt,
  });

  final String player;
  final String command;
  final String status;
  final String message;
  final DateTime createdAt;
}
