import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../database/app_database.dart';

abstract class ServerProcessService {
  Stream<String> get stdoutLines;
  Stream<String> get stderrLines;
  Stream<int> get exitCodes;
  bool get isRunning;

  Future<void> start();
  Future<void> stop();
  Future<void> restart();
  Future<void> sendCommand(String command);
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
  Future<void> start() async {
    if (_process != null) {
      return;
    }

    final serverDir = await AppDatabase.instance.getSetting('server_dir') ??
        '${Directory.current.parent.path}${Platform.pathSeparator}server_copy';
    final javaCommand = await AppDatabase.instance.getSetting('java_command') ?? 'java';
    final jarFile = await AppDatabase.instance.getSetting('jar_file') ??
        'fabric-server-mc.1.21.1-loader.0.18.4-launcher.1.1.1.jar';
    final xms = await AppDatabase.instance.getSetting('xms') ?? '2G';
    final xmx = await AppDatabase.instance.getSetting('xmx') ?? '4G';
    final jvmArgs = await AppDatabase.instance.getSetting('jvm_args') ?? '';

    final args = <String>['-Xms$xms', '-Xmx$xmx'];
    if (jvmArgs.trim().isNotEmpty) {
      args.addAll(jvmArgs.split(' ').where((arg) => arg.trim().isNotEmpty));
    }
    args.addAll(['-jar', jarFile, 'nogui']);

    _process = await Process.start(
      javaCommand,
      args,
      workingDirectory: serverDir,
      runInShell: true,
    );

    _process!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _stdoutController.add(line));

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => _stderrController.add(line));

    unawaited(
      _process!.exitCode.then((code) {
        _exitCodeController.add(code);
        _process = null;
      }),
    );
  }

  @override
  Future<void> stop() async {
    if (_process == null) {
      return;
    }
    await sendCommand('stop');
  }

  @override
  Future<void> restart() async {
    await stop();
    for (var i = 0; i < 50; i++) {
      if (_process == null) {
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
  Future<void> dispose() async {
    await _stdoutController.close();
    await _stderrController.close();
    await _exitCodeController.close();
  }
}
