import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/buttons/app_button.dart';
import '../../../components/inputs/app_text_input.dart';
import '../../../components/selects/app_select.dart';
import '../../../components/shared/app_variant.dart';
import '../../../config/routes/routes_config.dart';
import '../../../config/theme/app_theme_extension.dart';
import '../../../layout/default_layout.dart';
import '../models/audit_event.dart';
import '../providers/audit_events_provider.dart';

class AuditPage extends ConsumerStatefulWidget {
  const AuditPage({super.key});

  @override
  ConsumerState<AuditPage> createState() => _AuditPageState();
}

class _AuditPageState extends ConsumerState<AuditPage> {
  final TextEditingController _playerController = TextEditingController();
  final TextEditingController _actionController = TextEditingController();
  int? _selectedEventId;

  @override
  void dispose() {
    _playerController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditEventsProvider);
    final notifier = ref.read(auditEventsProvider.notifier);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    AuditEvent? selected;
    for (final event in state.events) {
      if (event.id == _selectedEventId) {
        selected = event;
        break;
      }
    }

    return DefaultLayout(
      title: 'MineControl',
      currentRoute: AppRoutes.audit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppSelect<String>(
                    value: state.eventTypeFilter,
                    items: _eventTypeItems,
                    onChanged: (value) {
                      if (value == null) return;
                      notifier.setEventTypeFilter(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppSelect<AuditDateFilter>(
                    value: state.dateFilter,
                    items: [
                      for (final filter in AuditDateFilter.values)
                        AppSelectItem(value: filter, label: filter.label),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      notifier.setDateFilter(value);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextInput(
                    controller: _playerController,
                    hint: 'Filtro por player',
                    prefixIcon: const Icon(Icons.person_search_rounded),
                    onSubmitted: notifier.setPlayerFilter,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppTextInput(
                    controller: _actionController,
                    hint: 'Filtro por ação',
                    prefixIcon: const Icon(Icons.filter_alt_rounded),
                    onSubmitted: notifier.setActionFilter,
                  ),
                ),
                const SizedBox(width: 10),
                AppButton(
                  label: 'Atualizar',
                  icon: Icons.refresh_rounded,
                  variant: AppVariant.info,
                  onPressed: notifier.load,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (state.error != null)
              Text(
                state.error!.replaceFirst('Bad state: ', ''),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 8),
            if (state.loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (state.events.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('Nenhum evento de auditoria encontrado.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: state.events.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final event = state.events[index];
                    final selected = event.id == _selectedEventId;
                    final created = DateFormat(
                      'dd/MM/yyyy HH:mm:ss',
                    ).format(event.createdAt);
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        setState(() {
                          _selectedEventId = selected ? null : event.id;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ext.cardBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : ext.cardBorder.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${event.eventType} • ${event.resultStatus}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Entity: ${event.entityType}/${event.entityId ?? '-'} | Actor: ${event.actorType}/${event.actorId ?? '-'} | $created',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 12),
              _SelectedAuditPayloadCard(event: selected),
            ],
          ],
        ),
      ),
    );
  }

  List<AppSelectItem<String>> get _eventTypeItems => const [
    AppSelectItem(value: '', label: 'Todos os tipos'),
    AppSelectItem(value: 'lifecycle.start', label: 'Lifecycle start'),
    AppSelectItem(value: 'lifecycle.stop', label: 'Lifecycle stop'),
    AppSelectItem(value: 'lifecycle.restart', label: 'Lifecycle restart'),
    AppSelectItem(value: 'backup.manual', label: 'Backup manual'),
    AppSelectItem(value: 'backup.automatic', label: 'Backup automático'),
    AppSelectItem(value: 'backup.restore', label: 'Restore backup'),
    AppSelectItem(value: 'config.change', label: 'Configuração'),
    AppSelectItem(value: 'permissions.change', label: 'Permissões'),
    AppSelectItem(value: 'ban.change', label: 'Banimento'),
    AppSelectItem(value: 'chat_hook.command', label: 'Chat hook'),
  ];
}

class _SelectedAuditPayloadCard extends StatelessWidget {
  const _SelectedAuditPayloadCard({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final prettyPayload = _pretty(event.payloadJson);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payload do evento #${event.id}',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SelectableText(
            prettyPayload,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontFamily: 'Consolas'),
          ),
        ],
      ),
    );
  }

  String _pretty(String raw) {
    try {
      final decoded = jsonDecode(raw);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return raw;
    }
  }
}
