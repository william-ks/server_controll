import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'components/modal/app_confirm_dialog.dart';
import 'config/providers/theme_provider.dart';
import 'config/routes/app_router.dart';
import 'config/routes/routes_config.dart';
import 'config/theme/app_theme.dart';
import 'models/server_lifecycle_state.dart';
import 'modules/audit/services/audit_service.dart';
import 'modules/maintenance/providers/maintenance_provider.dart';
import 'modules/players/providers/player_ban_provider.dart';
import 'modules/players/providers/player_permissions_provider.dart';
import 'modules/players/providers/player_playtime_provider.dart';
import 'modules/schedules/services/schedules_runner_service.dart';
import 'modules/server/providers/server_runtime_provider.dart';

class MineControlApp extends ConsumerStatefulWidget {
  const MineControlApp({super.key});

  @override
  ConsumerState<MineControlApp> createState() => _MineControlAppState();
}

class _MineControlAppState extends ConsumerState<MineControlApp> {
  AppLifecycleListener? _lifecycleListener;
  bool _shutdownRequested = false;

  bool _isServerActive(ServerLifecycleState lifecycle) {
    return lifecycle == ServerLifecycleState.online ||
        lifecycle == ServerLifecycleState.starting ||
        lifecycle == ServerLifecycleState.restarting ||
        lifecycle == ServerLifecycleState.stopping;
  }

  @override
  void initState() {
    super.initState();
    Future<void>(() async {
      await ref
          .read(auditServiceProvider)
          .logEvent(
            eventType: 'app.update',
            entityType: 'application',
            actorType: 'system',
            payload: {'status': 'not_checked'},
            resultStatus: 'info',
          );
    });
    _lifecycleListener = AppLifecycleListener(
      onExitRequested: () async {
        if (_shutdownRequested) return AppExitResponse.exit;

        final runtime = ref.read(serverRuntimeProvider);
        if (!_isServerActive(runtime.lifecycle)) {
          return AppExitResponse.exit;
        }

        if (!mounted) {
          return AppExitResponse.cancel;
        }

        final confirmed = await showAppConfirmDialog(
          context,
          icon: Icons.warning_rounded,
          title: 'Servidor ativo',
          message:
              'Para encerrar o aplicativo, e necessario que o servidor seja desligado. Deseja continuar?',
          confirmLabel: 'Confirmar',
          cancelLabel: 'Cancelar',
        );
        if (!confirmed) {
          return AppExitResponse.cancel;
        }

        _shutdownRequested = true;
        try {
          await ref.read(serverRuntimeProvider.notifier).shutdownForAppExit();
        } catch (_) {
          _shutdownRequested = false;
          return AppExitResponse.cancel;
        }
        return AppExitResponse.exit;
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final themeMode = ref.watch(themeModeProvider);
    ref.watch(schedulesRunnerProvider);
    ref.watch(playerPlaytimeProvider);
    ref.watch(playerPermissionsProvider);
    ref.watch(playerBanProvider);
    ref.watch(maintenanceProvider);

    return MaterialApp(
      title: 'MineControl',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRoutes.home,
      routes: AppRouter.routes,
    );
  }
}
