import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/badges/app_badge.dart';
import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_confirm_dialog.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../../config/routes/routes_config.dart';

import '../../../config/theme/app_theme_extension.dart';
import '../../players/providers/player_ban_provider.dart';
import '../../players/providers/player_permissions_provider.dart';
import '../../players/providers/players_registry_provider.dart';
import '../../server/providers/server_runtime_provider.dart';
import '../../../layout/default_layout.dart';
import '../providers/whitelist_provider.dart';
import '../subcomponents/add_edit_player_modal.dart';
import '../subcomponents/whitelist_actions_bar.dart';
import '../subcomponents/whitelist_empty_state.dart';
import '../subcomponents/whitelist_player_card.dart';

class WhitelistPage extends ConsumerStatefulWidget {
  const WhitelistPage({
    super.key,
    this.currentRoute = AppRoutes.players,
    this.title = 'Players',
  });

  final String currentRoute;
  final String title;

  @override
  ConsumerState<WhitelistPage> createState() => _WhitelistPageState();
}

class _WhitelistPageState extends ConsumerState<WhitelistPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _permissionsSyncKey = '';
  bool _filterAdmin = false;
  bool _filterOp = false;
  bool _filterBanned = false;

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
    final registryState = ref.watch(playersRegistryProvider);
    final permissionsState = ref.watch(playerPermissionsProvider);
    final permissionsNotifier = ref.read(playerPermissionsProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
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
            return notifier.savePlayer(
              id: id,
              nickname: nickname,
              uuid: uuid,
              iconPath: iconPath,
            );
          },
        ),
      );
    }

    Future<void> confirmRemoveWhitelist(int id, String nickname) async {
      final confirmed = await showAppConfirmDialog(
        context,
        icon: Icons.delete_outline_rounded,
        title: runtime.lifecycle == ServerLifecycleState.online
            ? 'Remover da whitelist'
            : 'Agendar remoção da whitelist',
        width: 600,
        showFooterDivider: false,
        actionsAlignment: Alignment.center,
        actionsWrapAlignment: WrapAlignment.center,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Você está prestes a remover $nickname da whitelist do servidor. Ele perderá acesso via whitelist.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      runtime.lifecycle == ServerLifecycleState.online
                          ? 'Como o servidor está online, a remoção será aplicada imediatamente.'
                          : 'Como o servidor está offline, a remoção ficará pendente e será sincronizada com o comando whitelist remove quando o servidor voltar.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],
        ),
      );
      if (confirmed) {
        await notifier.removeFromWhitelist(id: id, nickname: nickname);
      }
    }

    Future<void> confirmCancelPendingWhitelistRemoval(
      int id,
      String nickname,
    ) async {
      final confirmed = await showAppConfirmDialog(
        context,
        icon: Icons.undo_rounded,
        title: 'Cancelar remoção pendente',
        message:
            'Deseja cancelar a remoção pendente de $nickname da whitelist? Como ela ainda não foi aplicada no servidor, o acesso via whitelist será mantido.',
        confirmLabel: 'Cancelar remoção',
        confirmVariant: AppVariant.warning,
      );
      if (confirmed) {
        await notifier.cancelPendingWhitelistRemoval(id: id);
      }
    }

    Future<void> confirmBan(int id, String nickname) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AppModal(
          icon: Icons.gpp_bad_rounded,
          title: runtime.lifecycle == ServerLifecycleState.online
              ? 'Banir jogador'
              : 'Agendar banimento',
          width: 640,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppBadge(
                icon: Icons.warning_amber_rounded,
                variant: AppVariant.danger,
                title: 'Ação irreversível',
                description:
                    'Ao banir $nickname, ele será removido da whitelist e terá o histórico de ranking/sessões zerado. Esta ação é irreversível para os dados de playtime.',
              ),
              const SizedBox(height: 14),
              Text(
                runtime.lifecycle == ServerLifecycleState.online
                    ? 'Como o servidor está online, o banimento será aplicado imediatamente.'
                    : 'Como o servidor está offline, o banimento ficará pendente até o servidor voltar a ficar online. Enquanto isso, você poderá cancelar esse banimento pendente.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(false),
              type: AppButtonType.textButton,
              variant: AppVariant.danger,
            ),
            AppButton(
              label: runtime.lifecycle == ServerLifecycleState.online
                  ? 'Banir agora'
                  : 'Agendar banimento',
              icon: Icons.delete_forever_rounded,
              variant: AppVariant.danger,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        await ref
            .read(playerBanProvider.notifier)
            .banPlayer(
              nickname: nickname,
              reason: 'Banido pelo operador do app',
            );
        await ref.read(playersRegistryProvider.notifier).load();
        await notifier.load();
      }
    }

    Future<void> confirmCancelPendingBan(String nickname) async {
      final confirmed = await showAppConfirmDialog(
        context,
        icon: Icons.undo_rounded,
        title: 'Cancelar banimento pendente',
        message:
            'Deseja cancelar o banimento pendente de $nickname? Como ele ainda não foi aplicado no servidor, a ação será revertida.',
        confirmLabel: 'Cancelar banimento',
        confirmVariant: AppVariant.warning,
      );
      if (confirmed) {
        await ref
            .read(playerBanProvider.notifier)
            .cancelPendingBan(nickname: nickname);
        await ref.read(playersRegistryProvider.notifier).load();
      }
    }

    Future<void> confirmUnban(String nickname) async {
      final confirmed = await showAppConfirmDialog(
        context,
        icon: Icons.gpp_good_rounded,
        title: 'Desfazer banimento',
        message: runtime.lifecycle == ServerLifecycleState.online
            ? 'Deseja desfazer o banimento de $nickname agora?'
            : 'Deseja desfazer o banimento de $nickname? Como o servidor está offline, o desfazer ficará pendente até ele voltar.',
        confirmLabel: 'Desfazer banimento',
        confirmVariant: AppVariant.success,
      );
      if (confirmed) {
        await ref
            .read(playerBanProvider.notifier)
            .unbanPlayer(nickname: nickname);
        await ref.read(playersRegistryProvider.notifier).load();
      }
    }

    final registryByNickname = {
      for (final player in registryState.players)
        player.nickname.trim().toLowerCase(): player,
    };

    final filtered = state.players
        .where((player) {
          if (_query.trim().isEmpty) return true;
          final q = _query.toLowerCase();
          final matchesQuery =
              player.nickname.toLowerCase().contains(q) ||
              (player.uuid ?? '').toLowerCase().contains(q);
          if (!matchesQuery) return false;
          return true;
        })
        .where((player) {
          final nicknameKey = player.nickname.trim().toLowerCase();
          final permissions = permissionsState.statusByNickname[nicknameKey];
          final registry = registryByNickname[nicknameKey];
          if (_filterAdmin && !(permissions?.isAppAdmin ?? false)) return false;
          if (_filterOp && !(permissions?.isOp ?? false)) return false;
          if (_filterBanned && !(registry?.isBanned ?? false)) return false;
          return true;
        })
        .toList();

    final syncNicknames = [...state.players]
      ..sort(
        (a, b) => a.nickname.toLowerCase().compareTo(b.nickname.toLowerCase()),
      );
    final syncKey = syncNicknames
        .map((item) => item.nickname.trim().toLowerCase())
        .join('|');
    if (syncKey != _permissionsSyncKey) {
      _permissionsSyncKey = syncKey;
      Future<void>(() async {
        await permissionsNotifier.loadForNicknames(
          state.players.map((item) => item.nickname).toList(),
        );
      });
    }

    return DefaultLayout(
      title: widget.title,
      currentRoute: widget.currentRoute,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: ext.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ext.cardBorder.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              AppTextInput(
                controller: _searchController,
                hint: 'Pesquisar por nickname ou UUID',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Filtros',
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.filter_alt_rounded),
                      if (_activeFiltersCount > 0)
                        Positioned(
                          top: -2,
                          right: -4,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$_activeFiltersCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: _openFiltersModal,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              if (_activeFiltersCount > 0) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (_filterAdmin) _filterChip('Admin'),
                      if (_filterOp) _filterChip('OP'),
                      if (_filterBanned) _filterChip('Banido'),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              WhitelistActionsBar(
                onAdd: () => openModal(),
                onRefresh: notifier.refreshAndSyncFromFile,
                onSyncPending: notifier.syncPending,
                addEnabled: requirements.maybeWhen(
                  data: (data) => data.canManagePlayers,
                  orElse: () => false,
                ),
                syncEnabled: requirements.maybeWhen(
                  data: (data) =>
                      data.canManagePlayers &&
                      runtime.lifecycle == ServerLifecycleState.online,
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (!data.hasWhitelistFile) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'Arquivo whitelist.json não encontrado em ${data.whitelistFilePath}.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
                  child: Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (permissionsState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    permissionsState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ClipRect(
                  child: filtered.isEmpty
                      ? const WhitelistEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 6,
                          ),
                          clipBehavior: Clip.hardEdge,
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 14),
                          itemBuilder: (_, index) {
                            final player = filtered[index];
                            final nicknameKey = player.nickname
                                .trim()
                                .toLowerCase();
                            final permissions =
                                permissionsState.statusByNickname[nicknameKey];
                            final registry = registryByNickname[nicknameKey];
                            return WhitelistPlayerCard(
                              player: player,
                              isOnline: onlinePlayers.contains(player.nickname),
                              isAppAdmin: permissions?.isAppAdmin ?? false,
                              isOp: permissions?.isOp ?? false,
                              isBanned: registry?.isBanned ?? false,
                              isBanPending: registry?.isBanPending ?? false,
                              isUnbanPending: registry?.isUnbanPending ?? false,
                              pendingOpsCount:
                                  permissions?.pendingOpsCount ?? 0,
                              canCancelPendingBan:
                                  runtime.lifecycle !=
                                  ServerLifecycleState.online,
                              canCancelPendingWhitelistRemoval:
                                  player.isPendingRemoval,
                              onToggleAppAdmin: (value) async {
                                try {
                                  await permissionsNotifier.toggleAppAdmin(
                                    player.nickname,
                                    value,
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                          'Bad state: ',
                                          '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              onToggleOp: (value) async {
                                try {
                                  await permissionsNotifier.toggleOp(
                                    player.nickname,
                                    value,
                                  );
                                } catch (error) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.toString().replaceFirst(
                                          'Bad state: ',
                                          '',
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                              onEdit: () => openModal(id: player.id),
                              onBan: () =>
                                  confirmBan(player.id!, player.nickname),
                              onCancelPendingBan: () =>
                                  confirmCancelPendingBan(player.nickname),
                              onUnban: () => confirmUnban(player.nickname),
                              onRemoveWhitelist: () => confirmRemoveWhitelist(
                                player.id!,
                                player.nickname,
                              ),
                              onCancelPendingWhitelistRemoval: () =>
                                  confirmCancelPendingWhitelistRemoval(
                                    player.id!,
                                    player.nickname,
                                  ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int get _activeFiltersCount {
    var total = 0;
    if (_filterAdmin) total++;
    if (_filterOp) total++;
    if (_filterBanned) total++;
    return total;
  }

  Widget _filterChip(String label) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _openFiltersModal() async {
    var filterAdmin = _filterAdmin;
    var filterOp = _filterOp;
    var filterBanned = _filterBanned;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          return AppModal(
            icon: Icons.filter_alt_rounded,
            title: 'Filtros',
            width: 520,
            body: Column(
              children: [
                CheckboxListTile(
                  value: filterAdmin,
                  title: const Text('Somente admins'),
                  onChanged: (value) =>
                      setModalState(() => filterAdmin = value ?? false),
                ),
                CheckboxListTile(
                  value: filterOp,
                  title: const Text('Somente OPs'),
                  onChanged: (value) =>
                      setModalState(() => filterOp = value ?? false),
                ),
                CheckboxListTile(
                  value: filterBanned,
                  title: const Text('Somente banidos'),
                  onChanged: (value) =>
                      setModalState(() => filterBanned = value ?? false),
                ),
              ],
            ),
            actions: [
              AppButton(
                label: 'Limpar',
                icon: Icons.clear_rounded,
                type: AppButtonType.textButton,
                variant: AppVariant.danger,
                onPressed: () {
                  setState(() {
                    _filterAdmin = false;
                    _filterOp = false;
                    _filterBanned = false;
                  });
                  Navigator.of(context).pop();
                },
              ),
              AppButton(
                label: 'Aplicar',
                icon: Icons.check_rounded,
                variant: AppVariant.success,
                onPressed: () {
                  setState(() {
                    _filterAdmin = filterAdmin;
                    _filterOp = filterOp;
                    _filterBanned = filterBanned;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
