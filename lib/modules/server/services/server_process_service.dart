import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../database/app_database.dart';
import 'server_os_command_provider.dart';

abstract class ServerProcessService {
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Stream<int> get exitCodes;
  bool get isRunning;

  Future<void> prepareForAppStartup();
  Future<bool> hasAnyServerInstance();
  Future<void> start();
  Future<void> stop();
  Future<void> restart();
  Future<void> sendCommand(String command);
  Future<int?> getActiveServerMemoryMb();
  Future<void> shutdownForAppExit();
  Future<void> dispose();
}

class LocalServerProcessService implements ServerProcessService {
  LocalServerProcessService({ServerOsCommandProvider? osProvider})
    : _osProvider = osProvider ?? ServerOsCommandProvider.fromCurrentPlatform();

  final _stdoutController = StreamController<String>.broadcast();
  final _stderrController = StreamController<String>.broadcast();
  final _exitCodeController = StreamController<int>.broadcast();
  final ServerOsCommandProvider _osProvider;

  Process? _process;

  @override
  Stream<String> get stdoutLines => _stdoutController.stream;

  @override
  Stream<String> get stderrLines => _stderrController.stream;

  @override
  Stream<int> get exitCodes => _exitCodeController.stream;

  @override
  bool get isRunning => _process != null;

  @override
  Future<void> prepareForAppStartup() async {
    _ensureSupportedPlatform();
    final config = await _loadLaunchConfig();
    final activePids = await _osProvider.findMatchingServerProcessIds(
      config.jarFile,
    );
    if (activePids.isEmpty) {
      return;
    }

    // We cannot reattach stdin/stdout to old process handles safely.
    await _terminateByPids(
      activePids,
      reason:
          'Instancia anterior detectada ao iniciar app; encerrando para evitar duplicidade.',
    );
  }

  @override
  Future<bool> hasAnyServerInstance() async {
    _ensureSupportedPlatform();
    final config = await _loadLaunchConfig();
    final activePids = await _osProvider.findMatchingServerProcessIds(
      config.jarFile,
    );
    return activePids.isNotEmpty;
  }

  @override
  Future<void> start() async {
    _ensureSupportedPlatform();
    if (_process != null) {
      return;
    }

    final config = await _loadLaunchConfig();
    await _terminateDuplicateInstances(config.jarFile);

    final args = <String>['-Xms${config.xms}', '-Xmx${config.xmx}'];
    if (config.jvmArgs.trim().isNotEmpty) {
      args.addAll(
        config.jvmArgs
            .split(RegExp(r'\s+'))
            .where((arg) => arg.trim().isNotEmpty),
      );
    }
    args.addAll(['-jar', config.jarFile, 'nogui']);

    _stdoutController.add(
      '[system] Starting server: ${config.javaCommand} ${args.join(' ')}',
    );

    _process = await Process.start(
      config.javaCommand,
      args,
      workingDirectory: config.serverDir,
      runInShell: true,
    );

    await AppDatabase.instance.setSetting('server_pid', '${_process!.pid}');

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _stdoutController.add(line));

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _stderrController.add(line));

    unawaited(
      _process!.exitCode.then((code) async {
        _exitCodeController.add(code);
        _process = null;
        await AppDatabase.instance.setSetting('server_pid', '');
      }),
    );
  }

  @override
  Future<void> stop() async {
    _ensureSupportedPlatform();
    final known = _process;
    if (known != null) {
      await _gracefulStopKnownProcess(known);
      return;
    }

    final config = await _loadLaunchConfig();
    final pids = await _osProvider.findMatchingServerProcessIds(config.jarFile);
    if (pids.isEmpty) {
      return;
    }

    _stderrController.add(
      '[system] Instancia de servidor sem handle local encontrada. Encerrando processo do servidor.',
    );
    await _terminateByPids(pids, reason: 'stop solicitado sem handle local.');
  }

  @override
  Future<void> restart() async {
    await stop();
    for (var i = 0; i < 80; i++) {
      if (!await hasAnyServerInstance()) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    await start();
  }

  @override
  Future<void> sendCommand(String command) async {
    final process = _process;
    if (process == null) {
      return;
    }
    process.stdin.writeln(command);
    await process.stdin.flush();
  }

  @override
  Future<int?> getActiveServerMemoryMb() async {
    _ensureSupportedPlatform();
    final config = await _loadLaunchConfig();
    final pids = await _osProvider.findMatchingServerProcessIds(config.jarFile);
    if (pids.isEmpty) return null;

    var highest = 0;
    for (final pid in pids.toSet()) {
      final mb = await _getPidMemoryMb(pid);
      if (mb != null && mb > highest) {
        highest = mb;
      }
    }
    if (highest <= 0) return null;
    return highest;
  }

  @override
  Future<void> shutdownForAppExit() async {
    await stop();
  }

  @override
  Future<void> dispose() async {
    await _stdoutController.close();
    await _stderrController.close();
    await _exitCodeController.close();
  }

  Future<void> _gracefulStopKnownProcess(Process process) async {
    process.stdin.writeln('stop');
    await process.stdin.flush();

    var exited = false;
    for (var i = 0; i < 60; i++) {
      final running = await _osProvider.isPidRunning(process.pid);
      if (!running) {
        exited = true;
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }

    if (exited) {
      return;
    }

    _stderrController.add(
      '[system] Timeout no stop gracioso. Finalizando processo do servidor (pid ${process.pid}).',
    );
    await _osProvider.killPid(process.pid);
  }

  Future<void> _terminateDuplicateInstances(String jarFile) async {
    final pids = await _osProvider.findMatchingServerProcessIds(jarFile);
    if (pids.isEmpty) return;

    await _terminateByPids(
      pids,
      reason: 'Duplicidade detectada antes de iniciar nova instancia.',
    );
  }

  Future<void> _terminateByPids(
    List<int> pids, {
    required String reason,
  }) async {
    final uniquePids = pids.toSet().toList()..sort();
    for (final pid in uniquePids) {
      _stderrController.add(
        '[system] Encerrando processo do servidor pid=$pid. Motivo: $reason',
      );
      await _osProvider.killPid(pid);
    }
    await AppDatabase.instance.setSetting('server_pid', '');
  }

  Future<int?> _getPidMemoryMb(int pid) async {
    return _osProvider.getPidMemoryMb(pid);
  }

  Future<_LaunchConfig> _loadLaunchConfig() async {
    final db = AppDatabase.instance;
    final serverDirRaw = await db.getSetting('server_dir');
    final serverDir = (serverDirRaw == null || serverDirRaw.trim().isEmpty)
        ? '${Directory.current.parent.path}${Platform.pathSeparator}server_copy'
        : serverDirRaw;

    final javaCommandRaw = await db.getSetting('java_command');
    final javaCommand =
        (javaCommandRaw == null || javaCommandRaw.trim().isEmpty)
        ? 'java'
        : javaCommandRaw;

    final jarFileRaw = await db.getSetting('jar_file');
    final jarFile = (jarFileRaw == null || jarFileRaw.trim().isEmpty)
        ? 'fabric-server-mc.1.21.1-loader.0.18.4-launcher.1.1.1.jar'
        : jarFileRaw;

    final xmsRaw = await db.getSetting('xms');
    final xmxRaw = await db.getSetting('xmx');
    final normalized = _normalizeRam(xmsRaw: xmsRaw, xmxRaw: xmxRaw);
    final jvmArgs = await db.getSetting('jvm_args') ?? '';

    return _LaunchConfig(
      serverDir: serverDir,
      javaCommand: javaCommand,
      jarFile: jarFile,
      xms: normalized.$1,
      xmx: normalized.$2,
      jvmArgs: jvmArgs,
    );
  }

  (String, String) _normalizeRam({String? xmsRaw, String? xmxRaw}) {
    String normalize(String? raw, String fallback) {
      final base = (raw == null || raw.trim().isEmpty) ? fallback : raw.trim();
      final upper = base.toUpperCase();
      if (RegExp(r'^[0-9]+[MGT]$').hasMatch(upper)) {
        return upper;
      }
      if (RegExp(r'^[0-9]+$').hasMatch(upper)) {
        return '${upper}G';
      }
      return fallback;
    }

    var xms = normalize(xmsRaw, '2G');
    var xmx = normalize(xmxRaw, '4G');

    int toMb(String value) {
      final number = int.tryParse(value.substring(0, value.length - 1)) ?? 0;
      final unit = value.substring(value.length - 1);
      return switch (unit) {
        'T' => number * 1024 * 1024,
        'G' => number * 1024,
        'M' => number,
        _ => number,
      };
    }

    if (toMb(xmx) < toMb(xms)) {
      xmx = xms;
    }

    return (xms, xmx);
  }

  void _ensureSupportedPlatform() {
    if (_osProvider.isSupported) {
      return;
    }
    throw UnsupportedError(
      'Sistema operacional nao suportado para gerenciamento de processos do servidor.',
    );
  }
}

class _LaunchConfig {
  const _LaunchConfig({
    required this.serverDir,
    required this.javaCommand,
    required this.jarFile,
    required this.xms,
    required this.xmx,
    required this.jvmArgs,
  });

  final String serverDir;
  final String javaCommand;
  final String jarFile;
  final String xms;
  final String xmx;
  final String jvmArgs;
}
