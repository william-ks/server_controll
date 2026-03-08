import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../../models/server_lifecycle_state.dart';
import '../../maintenance/models/maintenance_defaults.dart';
import '../../maintenance/models/maintenance_mode.dart';
import '../../maintenance/providers/maintenance_provider.dart';
import '../../server/providers/server_runtime_provider.dart';

class MaintenanceModeModal extends ConsumerStatefulWidget {
  const MaintenanceModeModal({super.key});

  @override
  ConsumerState<MaintenanceModeModal> createState() =>
      _MaintenanceModeModalState();
}

class _MaintenanceModeModalState extends ConsumerState<MaintenanceModeModal> {
  final TextEditingController _motdTotalController = TextEditingController();
  final TextEditingController _motdAdminsController = TextEditingController();
  final TextEditingController _adminNicknamesController =
      TextEditingController();

  MaintenanceMode _mode = MaintenanceMode.total;
  bool _initialized = false;

  @override
  void dispose() {
    _motdTotalController.dispose();
    _motdAdminsController.dispose();
    _adminNicknamesController.dispose();
    super.dispose();
  }

  void _hydrateIfNeeded(MaintenanceState state) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _mode = state.defaults.defaultMode;
    _motdTotalController.text = state.defaults.motdTotal;
    _motdAdminsController.text = state.defaults.motdAdminsOnly;
    _adminNicknamesController.text = state.defaults.adminNicknames;
  }

  Future<void> _saveDefaults() async {
    final notifier = ref.read(maintenanceProvider.notifier);
    final maintenanceState = ref.read(maintenanceProvider);
    final defaults = MaintenanceDefaults(
      defaultMode: _mode,
      defaultCountdownSeconds: maintenanceState.defaults.defaultCountdownSeconds,
      motdTotal: _motdTotalController.text.trim().isEmpty
          ? 'Servidor em manutenção'
          : _motdTotalController.text.trim(),
      motdAdminsOnly: _motdAdminsController.text.trim().isEmpty
          ? 'Servidor em manutenção (somente admins)'
          : _motdAdminsController.text.trim(),
      maintenanceIconPath: maintenanceState.defaults.maintenanceIconPath,
      adminNicknames: _adminNicknamesController.text.trim(),
    );
    await notifier.saveDefaults(defaults);
  }

  Future<void> _activateFlow() async {
    await _saveDefaults();
    final notifier = ref.read(maintenanceProvider.notifier);
    final maintenanceState = ref.read(maintenanceProvider);
    final runtime = ref.read(serverRuntimeProvider);
    var countdown = 0;
    if (runtime.lifecycle == ServerLifecycleState.online &&
        runtime.activePlayers > 0) {
      final useCountdown = await _askCountdownForOnlinePlayers(
        runtime.activePlayers,
      );
      if (useCountdown == null || !mounted) {
        return;
      }
      if (useCountdown) {
        final seconds = await _askCountdownSeconds(
          initialValue: maintenanceState.defaults.defaultCountdownSeconds,
        );
        if (seconds == null) {
          return;
        }
        countdown = seconds;
      }
    }
    await notifier.activateNow(mode: _mode, countdownSeconds: countdown);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<bool?> _askCountdownForOnlinePlayers(int playersCount) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AppModal(
        icon: Icons.groups_rounded,
        title: 'Players online detectados',
        body: Text(
          'Detecção de jogadores online ($playersCount). Quer usar contagem regressiva antes de ativar a manutenção?',
        ),
        actions: [
          AppButton(
            label: 'Sem contagem',
            onPressed: () => Navigator.of(context).pop(false),
            type: AppButtonType.textButton,
            variant: AppVariant.info,
          ),
          AppButton(
            label: 'Usar contagem',
            onPressed: () => Navigator.of(context).pop(true),
            variant: AppVariant.warning,
            icon: Icons.timer_rounded,
          ),
        ],
      ),
    );
  }

  Future<int?> _askCountdownSeconds({required int initialValue}) async {
    final controller = TextEditingController(
      text: initialValue <= 0 ? '60' : '$initialValue',
    );
    int? seconds;
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final parsed = int.tryParse(controller.text.trim());
          final hasError = parsed == null || parsed <= 0;
          return AppModal(
            icon: Icons.timer_outlined,
            title: 'Contagem regressiva',
            body: AppTextInput(
              controller: controller,
              label: 'Tempo (segundos)',
              hint: 'Ex.: 60',
              keyboardType: TextInputType.number,
              errorText: hasError ? 'Informe um número inteiro maior que 0.' : null,
              onChanged: (_) => setModalState(() {}),
            ),
            actions: [
              AppButton(
                label: 'Cancelar',
                onPressed: () => Navigator.of(context).pop(false),
                type: AppButtonType.textButton,
                variant: AppVariant.danger,
              ),
              AppButton(
                label: 'Confirmar',
                onPressed: hasError
                    ? null
                    : () {
                        seconds = parsed;
                        Navigator.of(context).pop(true);
                      },
                variant: AppVariant.success,
                icon: Icons.check_rounded,
                isDisabled: hasError,
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (result == true) {
      return seconds;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    _hydrateIfNeeded(state);

    final active = state.snapshot.isActive;
    final countdown = state.countdownRemainingSeconds;

    return AppModal(
      icon: Icons.build_circle_outlined,
      title: 'Modo de manutenção',
      width: 760,
      maxBodyHeight: 520,
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active)
              _statusBanner(
                context,
                text:
                    'Manutenção ativa em modo ${state.snapshot.mode.label.toLowerCase()}.',
                isActive: true,
              ),
            if (!active && countdown > 0)
              _statusBanner(
                context,
                text: 'Ativação agendada em $countdown segundo(s).',
                isActive: false,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Modo de acesso',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppSelect<MaintenanceMode>(
                        value: _mode,
                        items: const [
                          AppSelectItem(
                            value: MaintenanceMode.total,
                            label: 'Manutenção total',
                          ),
                          AppSelectItem(
                            value: MaintenanceMode.adminsOnly,
                            label: 'Somente admins do app',
                          ),
                        ],
                        onChanged: active
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() => _mode = value);
                              },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admins permitidos',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      AppTextInput(
                        controller: _adminNicknamesController,
                        hint: 'Ex.: steve, alex',
                        enabled: !active,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: AppTextInput(
                    controller: _motdTotalController,
                    label: 'MOTD para manutenção total',
                    hint: 'Ex.: Servidor em manutenção',
                    enabled: !active,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppTextInput(
                    controller: _motdAdminsController,
                    label: 'MOTD para modo somente admins',
                    hint: 'Ex.: Somente admins do app',
                    enabled: !active,
                  ),
                ),
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 16),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        AppButton(
          label: 'Fechar',
          onPressed: () => Navigator.of(context).pop(),
          type: AppButtonType.textButton,
          variant: AppVariant.danger,
        ),
        if (!active)
          AppButton(
            label: 'Salvar padrões',
            onPressed: _saveDefaults,
            isDisabled: state.saving,
            variant: AppVariant.info,
            icon: Icons.save_outlined,
          ),
        if (!active)
          AppButton(
            label: 'Ativar',
            onPressed: _activateFlow,
            isLoading: state.saving,
            isDisabled: state.saving,
            variant: AppVariant.warning,
            icon: Icons.play_arrow_rounded,
          ),
        if (active)
          AppButton(
            label: 'Desativar manutenção',
            onPressed: () =>
                ref.read(maintenanceProvider.notifier).deactivate(),
            isLoading: state.saving,
            isDisabled: state.saving,
            variant: AppVariant.success,
            icon: Icons.lock_open_rounded,
          ),
      ],
    );
  }

  Widget _statusBanner(
    BuildContext context, {
    required String text,
    required bool isActive,
  }) {
    final bg = isActive
        ? Theme.of(context).colorScheme.error.withValues(alpha: 0.15)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    final border = isActive
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border.withValues(alpha: 0.55)),
      ),
      child: Text(
        text,
        style: TextStyle(color: border, fontWeight: FontWeight.w700),
      ),
    );
  }
}
