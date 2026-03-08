import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../models/player_registry_history_event.dart';
import '../models/player_registry_item.dart';
import '../providers/player_ban_provider.dart';
import '../providers/player_permissions_provider.dart';
import '../providers/players_registry_provider.dart';

enum _PlayersTab { all, whitelist, admins, ops, banned, history }

class PlayersPage extends ConsumerStatefulWidget {
  const PlayersPage({super.key});

  @override
  ConsumerState<PlayersPage> createState() => _PlayersPageState();
}

class _PlayersPageState extends ConsumerState<PlayersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  _PlayersTab _tab = _PlayersTab.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final registryState = ref.watch(playersRegistryProvider);
    final registryNotifier = ref.read(playersRegistryProvider.notifier);
    final permissionsNotifier = ref.read(playerPermissionsProvider.notifier);
    final banNotifier = ref.read(playerBanProvider.notifier);

    final players = _filterPlayers(registryState.players);
    final history = registryState.history.where((event) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return event.playerNickname.toLowerCase().contains(q) ||
          event.description.toLowerCase().contains(q) ||
          event.eventType.toLowerCase().contains(q);
    }).toList();

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.players,
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
                hint: 'Pesquisar player por nickname/uuid/evento',
                prefixIcon: const Icon(Icons.search_rounded),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _tabChip('Todos', _PlayersTab.all),
                  _tabChip('Whitelist', _PlayersTab.whitelist),
                  _tabChip('Admins', _PlayersTab.admins),
                  _tabChip('OPs', _PlayersTab.ops),
                  _tabChip('Banidos', _PlayersTab.banned),
                  _tabChip('Histórico', _PlayersTab.history),
                  AppButton(
                    label: 'Atualizar',
                    icon: Icons.refresh_rounded,
                    variant: AppVariant.info,
                    transparent: true,
                    onPressed: registryNotifier.load,
                  ),
                ],
              ),
              if (_tab == _PlayersTab.whitelist) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton(
                    label: 'Gerenciar whitelist detalhada',
                    icon: Icons.open_in_new_rounded,
                    variant: AppVariant.secondary,
                    transparent: true,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(AppRoutes.whitelist),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (registryState.loading) const LinearProgressIndicator(),
              if (registryState.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    registryState.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: _tab == _PlayersTab.history
                    ? _buildHistoryList(history)
                    : _buildPlayersList(
                        players,
                        onToggleAdmin: (nickname, value) async {
                          try {
                            await permissionsNotifier.toggleAppAdmin(
                              nickname,
                              value,
                            );
                            await registryNotifier.load();
                          } catch (error) {
                            _showError(
                              error.toString().replaceFirst('Bad state: ', ''),
                            );
                          }
                        },
                        onToggleOp: (nickname, value) async {
                          try {
                            await permissionsNotifier.toggleOp(nickname, value);
                            await registryNotifier.load();
                          } catch (error) {
                            _showError(
                              error.toString().replaceFirst('Bad state: ', ''),
                            );
                          }
                        },
                        onBanAction: (item) async {
                          try {
                            if (item.isBanned) {
                              await banNotifier.unbanPlayer(
                                nickname: item.nickname,
                              );
                              await registryNotifier.load();
                              return;
                            }
                            final request = await _openBanDialog(item.nickname);
                            if (request == null) return;
                            await banNotifier.banPlayer(
                              nickname: item.nickname,
                              reason: request.reason,
                              duration: request.duration,
                            );
                            await registryNotifier.load();
                          } catch (error) {
                            _showError(
                              error.toString().replaceFirst('Bad state: ', ''),
                            );
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabChip(String label, _PlayersTab tab) {
    return Builder(
      builder: (context) {
        final active = _tab == tab;
        return InkWell(
          onTap: () => setState(() => _tab = tab),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).dividerColor,
              ),
              color: active
                  ? Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.14)
                  : Colors.transparent,
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }

  List<PlayerRegistryItem> _filterPlayers(List<PlayerRegistryItem> players) {
    Iterable<PlayerRegistryItem> filtered = players;
    filtered = filtered.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.nickname.toLowerCase().contains(q) ||
          (item.uuid ?? '').toLowerCase().contains(q);
    });

    filtered = switch (_tab) {
      _PlayersTab.all => filtered,
      _PlayersTab.whitelist => filtered.where((item) => item.isWhitelisted),
      _PlayersTab.admins => filtered.where((item) => item.isAppAdmin),
      _PlayersTab.ops => filtered.where((item) => item.isOp),
      _PlayersTab.banned => filtered.where((item) => item.isBanned),
      _PlayersTab.history => filtered,
    };

    return filtered.toList();
  }

  Widget _buildPlayersList(
    List<PlayerRegistryItem> players, {
    required Future<void> Function(String nickname, bool value) onToggleAdmin,
    required Future<void> Function(String nickname, bool value) onToggleOp,
    required Future<void> Function(PlayerRegistryItem item) onBanAction,
  }) {
    if (players.isEmpty) {
      return const Center(
        child: Text('Nenhum player encontrado para este filtro.'),
      );
    }
    return ListView.separated(
      itemCount: players.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = players[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nickname,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                'UUID: ${item.uuid?.trim().isNotEmpty == true ? item.uuid : 'vazio'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _badge(
                    context,
                    label: item.isWhitelisted ? 'WHITELIST' : 'SEM WHITELIST',
                    active: item.isWhitelisted,
                  ),
                  _badge(
                    context,
                    label: item.isAppAdmin ? 'ADMIN APP' : 'PLAYER',
                    active: item.isAppAdmin,
                  ),
                  _badge(
                    context,
                    label: item.isOp ? 'OP' : 'SEM OP',
                    active: item.isOp,
                  ),
                  _badge(
                    context,
                    label: item.isBanned ? 'BANIDO' : 'NÃO BANIDO',
                    active: item.isBanned,
                  ),
                  if (item.hasIdentityConflict)
                    _badge(
                      context,
                      label: 'CONFLITO UUID',
                      active: true,
                      danger: true,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  AppButton(
                    label: item.isAppAdmin ? 'Remover admin' : 'Tornar admin',
                    variant: AppVariant.info,
                    transparent: true,
                    onPressed: () =>
                        onToggleAdmin(item.nickname, !item.isAppAdmin),
                  ),
                  AppButton(
                    label: item.isOp ? 'Remover OP' : 'Tornar OP',
                    variant: AppVariant.warning,
                    transparent: true,
                    isDisabled: !item.isAppAdmin,
                    onPressed: item.isAppAdmin
                        ? () => onToggleOp(item.nickname, !item.isOp)
                        : null,
                  ),
                  AppButton(
                    label: item.isBanned ? 'Desbanir' : 'Banir',
                    variant: item.isBanned
                        ? AppVariant.success
                        : AppVariant.danger,
                    transparent: true,
                    onPressed: () => onBanAction(item),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryList(List<PlayerRegistryHistoryEvent> history) {
    if (history.isEmpty) {
      return const Center(child: Text('Sem histórico disponível.'));
    }
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    return ListView.separated(
      itemCount: history.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final item = history[index];
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.playerNickname} • ${item.eventType}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(item.description),
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
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<_BanRequest?> _openBanDialog(String nickname) async {
    final reasonController = TextEditingController();
    final durationController = TextEditingController();

    final result = await showDialog<_BanRequest>(
      context: context,
      builder: (context) {
        return AppModal(
          icon: Icons.block_rounded,
          title: 'Banir player: $nickname',
          width: 560,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTextInput(
                controller: reasonController,
                label: 'Motivo',
                hint: 'Ex.: griefing',
              ),
              const SizedBox(height: 10),
              AppTextInput(
                controller: durationController,
                label: 'Duração em horas (opcional)',
                hint: 'Vazio = ban permanente',
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            AppButton(
              label: 'Cancelar',
              onPressed: () => Navigator.of(context).pop(),
              type: AppButtonType.textButton,
              variant: AppVariant.danger,
            ),
            AppButton(
              label: 'Confirmar ban',
              onPressed: () {
                final hours = int.tryParse(durationController.text.trim());
                final duration = (hours == null || hours <= 0)
                    ? null
                    : Duration(hours: hours);
                Navigator.of(context).pop(
                  _BanRequest(
                    reason: reasonController.text.trim(),
                    duration: duration,
                  ),
                );
              },
              variant: AppVariant.warning,
              icon: Icons.check_rounded,
            ),
          ],
        );
      },
    );

    reasonController.dispose();
    durationController.dispose();
    return result;
  }

  Widget _badge(
    BuildContext context, {
    required String label,
    required bool active,
    bool danger = false,
  }) {
    final color = danger
        ? Theme.of(context).colorScheme.error
        : (active
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _BanRequest {
  const _BanRequest({required this.reason, required this.duration});

  final String reason;
  final Duration? duration;
}
