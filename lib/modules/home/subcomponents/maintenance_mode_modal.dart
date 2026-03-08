import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../maintenance/models/maintenance_defaults.dart';
import '../../maintenance/models/maintenance_mode.dart';
import '../../maintenance/providers/maintenance_provider.dart';

class MaintenanceModeModal extends ConsumerStatefulWidget {
  const MaintenanceModeModal({super.key});

  @override
  ConsumerState<MaintenanceModeModal> createState() =>
      _MaintenanceModeModalState();
}

class _MaintenanceModeModalState extends ConsumerState<MaintenanceModeModal> {
  final TextEditingController _countdownController = TextEditingController();
  final TextEditingController _motdTotalController = TextEditingController();
  final TextEditingController _motdAdminsController = TextEditingController();
  final TextEditingController _iconPathController = TextEditingController();
  final TextEditingController _adminNicknamesController =
      TextEditingController();

  MaintenanceMode _mode = MaintenanceMode.total;
  bool _initialized = false;

  @override
  void dispose() {
    _countdownController.dispose();
    _motdTotalController.dispose();
    _motdAdminsController.dispose();
    _iconPathController.dispose();
    _adminNicknamesController.dispose();
    super.dispose();
  }

  void _hydrateIfNeeded(MaintenanceState state) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _mode = state.defaults.defaultMode;
    _countdownController.text = '${state.defaults.defaultCountdownSeconds}';
    _motdTotalController.text = state.defaults.motdTotal;
    _motdAdminsController.text = state.defaults.motdAdminsOnly;
    _iconPathController.text = state.defaults.maintenanceIconPath;
    _adminNicknamesController.text = state.defaults.adminNicknames;
  }

  Future<void> _saveDefaults() async {
    final notifier = ref.read(maintenanceProvider.notifier);
    final defaults = MaintenanceDefaults(
      defaultMode: _mode,
      defaultCountdownSeconds:
          int.tryParse(_countdownController.text.trim()) ?? 60,
      motdTotal: _motdTotalController.text.trim().isEmpty
          ? 'Servidor em manutenção'
          : _motdTotalController.text.trim(),
      motdAdminsOnly: _motdAdminsController.text.trim().isEmpty
          ? 'Servidor em manutenção (somente admins)'
          : _motdAdminsController.text.trim(),
      maintenanceIconPath: _iconPathController.text.trim(),
      adminNicknames: _adminNicknamesController.text.trim(),
    );
    await notifier.saveDefaults(defaults);
  }

  Future<void> _activate({required bool withCountdown}) async {
    await _saveDefaults();
    final notifier = ref.read(maintenanceProvider.notifier);
    final countdown = withCountdown
        ? (int.tryParse(_countdownController.text.trim()) ?? 60)
        : 0;
    await notifier.activateNow(mode: _mode, countdownSeconds: countdown);
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
            Text(
              'Modo de acesso',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
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
            const SizedBox(height: 12),
            AppTextInput(
              controller: _countdownController,
              label: 'Contagem regressiva (segundos)',
              hint: 'Ex.: 60',
              keyboardType: TextInputType.number,
              enabled: !active,
            ),
            const SizedBox(height: 10),
            AppTextInput(
              controller: _motdTotalController,
              label: 'MOTD para manutenção total',
              hint: 'Ex.: Servidor em manutenção',
              enabled: !active,
            ),
            const SizedBox(height: 10),
            AppTextInput(
              controller: _motdAdminsController,
              label: 'MOTD para modo somente admins',
              hint: 'Ex.: Somente admins do app',
              enabled: !active,
            ),
            const SizedBox(height: 10),
            AppTextInput(
              controller: _iconPathController,
              label: 'Caminho da imagem para manutenção',
              hint: r'Ex.: C:\icons\maintenance.png',
              enabled: !active,
            ),
            const SizedBox(height: 10),
            AppTextInput(
              controller: _adminNicknamesController,
              label: 'Admins do app (apelidos separados por vírgula)',
              hint: 'Ex.: steve, alex',
              enabled: !active,
            ),
            if (state.error != null) ...[
              const SizedBox(height: 10),
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
            label: 'Ativar agora',
            onPressed: () => _activate(withCountdown: false),
            isLoading: state.saving,
            isDisabled: state.saving,
            variant: AppVariant.warning,
            icon: Icons.play_arrow_rounded,
          ),
        if (!active)
          AppButton(
            label: 'Ativar com contagem',
            onPressed: () => _activate(withCountdown: true),
            isDisabled: state.saving,
            variant: AppVariant.primary,
            icon: Icons.timer_rounded,
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
