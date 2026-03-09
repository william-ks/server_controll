import 'package:flutter/material.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../subcomponents/advanced_settings_tab.dart';
import '../subcomponents/backup_settings_tab.dart';
import '../subcomponents/files_settings_tab.dart';
import '../subcomponents/maintenance_settings_tab.dart';
import '../subcomponents/properties_settings_tab.dart';

enum ConfigTab { arquivos, backup, propriedades, manutencao, avancado }

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  ConfigTab _active = ConfigTab.arquivos;
  int _filesReloadToken = 0;
  int _backupReloadToken = 0;
  int _propertiesReloadToken = 0;
  int _maintenanceReloadToken = 0;

  void _setTab(ConfigTab tab) {
    if (_active != tab && tab == ConfigTab.arquivos) {
      _filesReloadToken++;
    }
    if (_active != tab && tab == ConfigTab.backup) {
      _backupReloadToken++;
    }
    if (_active != tab && tab == ConfigTab.propriedades) {
      _propertiesReloadToken++;
    }
    if (_active != tab && tab == ConfigTab.manutencao) {
      _maintenanceReloadToken++;
    }
    setState(() => _active = tab);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.config,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _TabChip(
                    label: 'Arquivos',
                    active: _active == ConfigTab.arquivos,
                    onTap: () => _setTab(ConfigTab.arquivos),
                  ),
                  _TabChip(
                    label: 'Backup',
                    active: _active == ConfigTab.backup,
                    onTap: () => _setTab(ConfigTab.backup),
                  ),
                  _TabChip(
                    label: 'Propriedades',
                    active: _active == ConfigTab.propriedades,
                    onTap: () => _setTab(ConfigTab.propriedades),
                  ),
                  _TabChip(
                    label: 'Manutenção',
                    active: _active == ConfigTab.manutencao,
                    onTap: () => _setTab(ConfigTab.manutencao),
                  ),
                  _TabChip(
                    label: 'Avançado',
                    active: _active == ConfigTab.avancado,
                    onTap: () => _setTab(ConfigTab.avancado),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _TabContent(
                tab: _active,
                filesReloadToken: _filesReloadToken,
                backupReloadToken: _backupReloadToken,
                propertiesReloadToken: _propertiesReloadToken,
                maintenanceReloadToken: _maintenanceReloadToken,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: AppStyles.radiusFull,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: AppStyles.radiusFull,
          border: Border.all(
            color: active ? scheme.primary : Theme.of(context).dividerColor,
          ),
          color: active
              ? scheme.primary.withValues(alpha: 0.14)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? scheme.primary : scheme.onSurface,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({
    required this.tab,
    required this.filesReloadToken,
    required this.backupReloadToken,
    required this.propertiesReloadToken,
    required this.maintenanceReloadToken,
  });

  final ConfigTab tab;
  final int filesReloadToken;
  final int backupReloadToken;
  final int propertiesReloadToken;
  final int maintenanceReloadToken;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ConfigTab.arquivos => FilesSettingsTab(
        key: ValueKey('files-$filesReloadToken'),
      ),
      ConfigTab.backup => BackupSettingsTab(
        key: ValueKey('backup-$backupReloadToken'),
      ),
      ConfigTab.propriedades => PropertiesSettingsTab(
        key: ValueKey('properties-$propertiesReloadToken'),
      ),
      ConfigTab.manutencao => MaintenanceSettingsTab(
        key: ValueKey('maintenance-$maintenanceReloadToken'),
      ),
      ConfigTab.avancado => const AdvancedSettingsTab(),
    };
  }
}
