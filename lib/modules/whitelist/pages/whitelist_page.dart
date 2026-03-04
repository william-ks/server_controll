import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../../layout/default_layout.dart';
import '../providers/whitelist_provider.dart';
import '../subcomponents/add_edit_player_modal.dart';
import '../subcomponents/whitelist_actions_bar.dart';
import '../subcomponents/whitelist_empty_state.dart';
import '../subcomponents/whitelist_player_card.dart';

class WhitelistPage extends ConsumerStatefulWidget {
  const WhitelistPage({super.key});

  @override
  ConsumerState<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends ConsumerState<WhitelistPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(whitelistProvider);
    final notifier = ref.read(whitelistProvider.notifier);
    final onlinePlayers = ref.watch(onlinePlayersProvider);
    final runtime = ref.watch(serverRuntimeProvider);
    final requirements = ref.watch(whitelistRequirementsProvider);

    Future<void> openModal({int? id}) async {
      final player = id == null
          ? null
          : state.players.firstWhere(
              (item) => item.id == id,
              orElse: () => state.players.first,
            );

      await showDialog<void>(
        context: context,
        builder: (_) => AddEditPlayerModal(
          player: player,
          onPickIcon: notifier.pickIconAndSave,
          onSave: ({required nickname, uuid, iconPath}) {
            return notifier.savePlayer(id: id, nickname: nickname, uuid: uuid, iconPath: iconPath);
          },
        ),
      );
    }

    Future<void> confirmDelete(int id, String nickname) async {
      await showDialog<void>(
        context: context,
        builder: (_) => AppModal(
          icon: Icons.delete_outline_rounded,
          title: 'Remover jogador',
          body: Text('Deseja remover $nickname da whitelist?'),
          actions: [
            AppButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
              variant: AppVariant.danger,
              transparent: true,
              icon: Icons.close_rounded,
            ),
            AppButton(
              label: 'Confirmar',
              onPressed: () async {
                await notifier.removePlayer(id);
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              variant: AppVariant.success,
              icon: Icons.check_rounded,
            ),
          ],
        ),
      );
    }

    final filtered = state.players.where((player) {
      if (_query.trim().isEmpty) return true;
      final q = _query.toLowerCase();
      return player.nickname.toLowerCase().contains(q) || (player.uuid ?? '').toLowerCase().contains(q);
    }).toList();

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.whitelist,
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
            children: [
              AppTextInput(
                controller: _searchController,
                hint: 'Pesquisar por nickname ou UUID',
                prefixIcon: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              WhitelistActionsBar(
                onAdd: () => openModal(),
                onRefresh: notifier.refreshAndSyncFromFile,
                onSyncPending: notifier.syncPending,
                addEnabled: requirements.maybeWhen(data: (data) => data.canManagePlayers, orElse: () => false),
                syncEnabled: requirements.maybeWhen(
                  data: (data) => data.canManagePlayers && runtime.lifecycle == ServerLifecycleState.online,
                  orElse: () => false,
                ),
              ),
              requirements.when(
                data: (data) {
                  if (!data.hasEssentialConfig) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Defina Path do servidor, Comando do Java e Nome do file server em Config > Arquivos antes de gerenciar a whitelist.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }
                  if (!data.hasWhitelistFile) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Arquivo whitelist.json não encontrado em ${data.whitelistFilePath}.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              if (state.loading) const LinearProgressIndicator(),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? const WhitelistEmptyState()
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        clipBehavior: Clip.none,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 14),
                        itemBuilder: (_, index) {
                          final player = filtered[index];
                          return WhitelistPlayerCard(
                            player: player,
                            isOnline: onlinePlayers.contains(player.nickname),
                            onEdit: () => openModal(id: player.id),
                            onDelete: () => confirmDelete(player.id!, player.nickname),
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
