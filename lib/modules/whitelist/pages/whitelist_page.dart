import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../layout/default_layout.dart';
import '../../../routes/routes_config.dart';
import '../providers/whitelist_provider.dart';
import '../subcomponents/add_edit_player_modal.dart';
import '../subcomponents/whitelist_actions_bar.dart';
import '../subcomponents/whitelist_empty_state.dart';
import '../subcomponents/whitelist_player_card.dart';

class WhitelistPage extends ConsumerWidget {
  const WhitelistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(whitelistProvider);
    final notifier = ref.read(whitelistProvider.notifier);

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

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.whitelist,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            WhitelistActionsBar(
              onAdd: () => openModal(),
              onRefresh: notifier.refreshAndSyncFromFile,
              onSyncPending: notifier.syncPending,
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
              child: state.players.isEmpty
                  ? const WhitelistEmptyState()
                  : ListView.separated(
                      itemCount: state.players.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final player = state.players[index];
                        return WhitelistPlayerCard(
                          player: player,
                          onEdit: () => openModal(id: player.id),
                          onDelete: () => notifier.removePlayer(player.id!),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
