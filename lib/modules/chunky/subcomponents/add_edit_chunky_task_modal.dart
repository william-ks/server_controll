import 'package:flutter/material.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_switch_card.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/modal/app_modal.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../maintenance/models/maintenance_mode.dart';
import '../models/chunky_task.dart';
import '../models/chunky_task_status.dart';

class AddEditChunkyTaskModal extends StatefulWidget {
  const AddEditChunkyTaskModal({
    super.key,
    this.initialTask,
    required this.onCreate,
    required this.onUpdate,
  });

  final ChunkyTask? initialTask;
  final Future<void> Function({
    required String name,
    required String world,
    required int centerX,
    required int centerZ,
    required double radius,
    required String shape,
    required String pattern,
    required bool maintenanceEnabled,
    String? maintenanceMode,
  })
  onCreate;
  final Future<void> Function(ChunkyTask task) onUpdate;

  @override
  State<AddEditChunkyTaskModal> createState() => _AddEditChunkyTaskModalState();
}

class _AddEditChunkyTaskModalState extends State<AddEditChunkyTaskModal> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _centerXController = TextEditingController();
  final TextEditingController _centerZController = TextEditingController();

  String _world = 'overworld';
  String _shape = 'square';
  String _pattern = 'region';
  bool _maintenanceEnabled = false;
  MaintenanceMode _maintenanceMode = MaintenanceMode.total;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.initialTask != null;
  bool get _immutable => widget.initialTask?.hasEverStarted ?? false;

  @override
  void initState() {
    super.initState();
    final task = widget.initialTask;
    if (task != null) {
      _nameController.text = task.name;
      _radiusController.text = task.radius.toStringAsFixed(0);
      _centerXController.text = '${task.centerX}';
      _centerZController.text = '${task.centerZ}';
      _world = task.world;
      _shape = task.shape;
      _pattern = task.pattern;
      _maintenanceEnabled = task.maintenanceEnabled;
      _maintenanceMode = task.maintenanceMode == null
          ? MaintenanceMode.total
          : MaintenanceModeX.fromStorage(task.maintenanceMode!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    _centerXController.dispose();
    _centerZController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final centerXRaw = _centerXController.text.trim();
    final centerZRaw = _centerZController.text.trim();
    final radius = double.tryParse(_radiusController.text.trim()) ?? 0;
    final centerX = int.tryParse(centerXRaw);
    final centerZ = int.tryParse(centerZRaw);
    if (name.isEmpty) {
      setState(() => _error = 'Informe o título da task.');
      return;
    }
    if (centerXRaw.isEmpty || centerX == null) {
      setState(() => _error = 'Centro X deve ser um número inteiro válido.');
      return;
    }
    if (centerZRaw.isEmpty || centerZ == null) {
      setState(() => _error = 'Centro Z deve ser um número inteiro válido.');
      return;
    }
    if (radius <= 0) {
      setState(() => _error = 'Informe um raio válido.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_editing) {
        final existing = widget.initialTask!;
        await widget.onUpdate(
          existing.copyWith(
            name: name,
            world: _world,
            centerX: centerX,
            centerZ: centerZ,
            radius: radius,
            shape: _shape,
            pattern: _pattern,
            backupBeforeStart: false,
            maintenanceEnabled: _maintenanceEnabled,
            maintenanceMode: _maintenanceEnabled
                ? _maintenanceMode.storageValue
                : null,
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        await widget.onCreate(
          name: name,
          world: _world,
          centerX: centerX,
          centerZ: centerZ,
          radius: radius,
          shape: _shape,
          pattern: _pattern,
          maintenanceEnabled: _maintenanceEnabled,
          maintenanceMode: _maintenanceEnabled
              ? _maintenanceMode.storageValue
              : null,
        );
      }
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppModal(
      icon: Icons.task_alt_rounded,
      title: _editing ? 'Editar task' : 'Nova task',
      width: 820,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_immutable)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Esta task já foi executada e não pode ser modificada.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              return Column(
                children: [
                  _fieldRow(
                    compact: compact,
                    left: _labeled(
                      context,
                      'Título da task',
                      AppTextInput(
                        controller: _nameController,
                        enabled: !_immutable,
                      ),
                    ),
                    right: _labeled(
                      context,
                      'Região / Mundo',
                      AppSelect<String>(
                        value: _world,
                        enabled: !_immutable,
                        items: chunkyWorldOptions
                            .map(
                              (item) => AppSelectItem<String>(
                                value: item.id,
                                label: item.label,
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _world = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fieldRow(
                    compact: compact,
                    left: _labeled(
                      context,
                      'Centro X',
                      AppTextInput(
                        controller: _centerXController,
                        keyboardType: TextInputType.number,
                        enabled: !_immutable,
                      ),
                    ),
                    right: _labeled(
                      context,
                      'Centro Z',
                      AppTextInput(
                        controller: _centerZController,
                        keyboardType: TextInputType.number,
                        enabled: !_immutable,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _fieldRow(
                    compact: compact,
                    left: _labeled(
                      context,
                      'Forma',
                      AppSelect<String>(
                        value: _shape,
                        enabled: !_immutable,
                        items: const [
                          AppSelectItem(value: 'square', label: 'Quadrado'),
                          AppSelectItem(value: 'circle', label: 'Círculo'),
                          AppSelectItem(value: 'triangle', label: 'Triângulo'),
                          AppSelectItem(value: 'diamond', label: 'Losango'),
                          AppSelectItem(value: 'pentagon', label: 'Pentágono'),
                          AppSelectItem(value: 'hexagon', label: 'Hexágono'),
                          AppSelectItem(value: 'star', label: 'Estrela'),
                          AppSelectItem(value: 'rectangle', label: 'Retângulo'),
                          AppSelectItem(value: 'ellipse', label: 'Elipse'),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _shape = value);
                        },
                      ),
                    ),
                    right: _labeled(
                      context,
                      'Padrão',
                      AppSelect<String>(
                        value: _pattern,
                        enabled: !_immutable,
                        items: const [
                          AppSelectItem(value: 'spiral', label: 'Espiral'),
                          AppSelectItem(value: 'loop', label: 'Loop'),
                          AppSelectItem(
                            value: 'concentric',
                            label: 'Concêntrico',
                          ),
                          AppSelectItem(value: 'region', label: 'Região'),
                          AppSelectItem(value: 'csv', label: 'CSV'),
                          AppSelectItem(value: 'world', label: 'Mundo'),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _pattern = value);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _labeled(
                    context,
                    'Raio',
                    AppTextInput(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      enabled: !_immutable,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: AppSwitchCard(
                  label: 'Usar modo de manutenção',
                  value: _maintenanceEnabled,
                  onChanged: _immutable
                      ? null
                      : (value) => setState(() => _maintenanceEnabled = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppSelect<MaintenanceMode>(
            label: 'Tipo de manutenção',
            value: _maintenanceMode,
            enabled: !_immutable && _maintenanceEnabled,
            items: const [
              AppSelectItem(
                value: MaintenanceMode.total,
                label: 'Bloquear todos',
              ),
              AppSelectItem(
                value: MaintenanceMode.adminsOnly,
                label: 'Permitir apenas admins do app',
              ),
            ],
            onChanged: !_immutable && _maintenanceEnabled
                ? (value) {
                    if (value == null) return;
                    setState(() => _maintenanceMode = value);
                  }
                : null,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        AppButton(
          label: 'Cancelar',
          variant: AppVariant.danger,
          type: AppButtonType.textButton,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (!_immutable)
          AppButton(
            label: _editing ? 'Salvar' : 'Criar',
            variant: AppVariant.success,
            icon: _editing ? Icons.save_rounded : Icons.add_rounded,
            isLoading: _saving,
            isDisabled: _saving,
            onPressed: _save,
          ),
      ],
    );
  }

  Widget _labeled(BuildContext context, String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 6),
        field,
      ],
    );
  }

  Widget _fieldRow({
    required bool compact,
    required Widget left,
    required Widget right,
  }) {
    if (compact) {
      return Column(children: [left, const SizedBox(height: 12), right]);
    }
    return Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );
  }
}
