import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../../database/app_database.dart';

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
  Future<void> shutdownForAppExit();
  Future<void> dispose();
}

class LocalServerProcessService implements ServerProcessService {
  final _stdoutController = StreamController<String>.broadcast();
  final _stderrController = StreamController<String>.broadcast();
  final _exitCodeController = StreamController<int>.broadcast();

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
    final config = await _loadLaunchConfig();
    final activePids = await _findMatchingServerProcessIds(config.jarFile);
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
    final config = await _loadLaunchConfig();
    final activePids = await _findMatchingServerProcessIds(config.jarFile);
    return activePids.isNotEmpty;
  }

  @override
  Future<void> start() async {
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
    final known = _process;
    if (known != null) {
      await _gracefulStopKnownProcess(known);
      return;
    }

    final config = await _loadLaunchConfig();
    final pids = await _findMatchingServerProcessIds(config.jarFile);
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
    for (var i = 0; i < 120; i++) {
      final running = await _isPidRunning(process.pid);
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
    await _killPid(process.pid);
  }

  Future<void> _terminateDuplicateInstances(String jarFile) async {
    final pids = await _findMatchingServerProcessIds(jarFile);
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
      await _killPid(pid);
    }
    await AppDatabase.instance.setSetting('server_pid', '');
  }

  Future<void> _killPid(int pid) async {
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      return;
    }
    await Process.run('kill', ['-TERM', '$pid']);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (await _isPidRunning(pid)) {
      await Process.run('kill', ['-KILL', '$pid']);
    }
  }

  Future<bool> _isPidRunning(int pid) async {
    if (pid <= 0) return false;
    if (Platform.isWindows) {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        'if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }',
      ]);
      return result.exitCode == 0;
    }
    final result = await Process.run('kill', ['-0', '$pid']);
    return result.exitCode == 0;
  }

  Future<List<int>> _findMatchingServerProcessIds(String jarFile) async {
    final escapedJar = RegExp.escape(jarFile.trim());
    if (escapedJar.isEmpty) return [];

    if (Platform.isWindows) {
      final script = r'''
$jar = [regex]::Escape($args[0])
Get-CimInstance Win32_Process |
Where-Object {
  $_.Name -match '^java(w)?(\.exe)?$' -and
  $_.CommandLine -match '-jar' -and
  $_.CommandLine -match $jar
} |
Select-Object -ExpandProperty ProcessId
''';
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        script,
        jarFile,
      ]);
      if (result.exitCode != 0) {
        return [];
      }
      return result.stdout
          .toString()
          .split(RegExp(r'\s+'))
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
    }

    final ps = await Process.run('ps', ['-eo', 'pid=,args=']);
    if (ps.exitCode != 0) return [];

    final ids = <int>[];
    for (final raw in ps.stdout.toString().split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final firstSpace = line.indexOf(' ');
      if (firstSpace <= 0) continue;
      final pid = int.tryParse(line.substring(0, firstSpace).trim());
      if (pid == null) continue;
      final args = line.substring(firstSpace + 1);
      if (!RegExp('\\bjava(w)?\\b', caseSensitive: false).hasMatch(args)) {
        continue;
      }
      if (!args.contains('-jar')) continue;
      if (!RegExp(escapedJar, caseSensitive: false).hasMatch(args)) continue;
      ids.add(pid);
    }
    return ids;
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
