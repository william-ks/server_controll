import 'package:flutter/material.dart';

import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_styles.dart';
import '../../../layout/default_layout.dart';
import '../subcomponents/advanced_settings_tab.dart';
import '../subcomponents/files_settings_tab.dart';

enum ConfigTab { arquivos, backup, propriedades, avancado }

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  ConfigTab _active = ConfigTab.arquivos;
  int _filesReloadToken = 0;

  void _setTab(ConfigTab tab) {
    if (_active != tab && tab == ConfigTab.arquivos) {
      _filesReloadToken++;
    }
    setState(() => _active = tab);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.config,
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
          padding: const EdgeInsets.all(20),
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
                      label: 'Avançado',
                      active: _active == ConfigTab.avancado,
                      onTap: () => _setTab(ConfigTab.avancado),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(child: _TabContent(tab: _active, filesReloadToken: _filesReloadToken)),
            ],
          ),
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
          border: Border.all(color: active ? scheme.primary : Theme.of(context).dividerColor),
          color: active ? scheme.primary.withValues(alpha: 0.14) : Colors.transparent,
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
  const _TabContent({required this.tab, required this.filesReloadToken});

  final ConfigTab tab;
  final int filesReloadToken;

  @override
  Widget build(BuildContext context) {
    return switch (tab) {
      ConfigTab.arquivos => FilesSettingsTab(key: ValueKey('files-$filesReloadToken')),
      ConfigTab.backup => _PlaceholderContent(text: 'Configurações de Backup em construção.'),
      ConfigTab.propriedades => _PlaceholderContent(text: 'Configurações de Propriedades em construção.'),
      ConfigTab.avancado => const AdvancedSettingsTab(),
    };
  }
}

class _PlaceholderContent extends StatelessWidget {
  const _PlaceholderContent({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Text(text),
    );
  }
}
