import 'dart:io';

enum HostPlatform { windows, linux, macos, unknown }

abstract class ServerOsCommandProvider {
  const ServerOsCommandProvider();

  HostPlatform get platform;
  bool get isSupported => platform != HostPlatform.unknown;
  String get defaultJavaCommand => 'java';

  Future<void> killPid(int pid);
  Future<bool> isPidRunning(int pid);
  Future<int?> getPidMemoryMb(int pid);
  Future<List<int>> findMatchingServerProcessIds(String jarFile);

  static ServerOsCommandProvider fromCurrentPlatform() {
    if (Platform.isWindows) {
      return const _WindowsServerOsCommandProvider();
    }
    if (Platform.isLinux) {
      return const _LinuxServerOsCommandProvider();
    }
    if (Platform.isMacOS) {
      return const _LinuxServerOsCommandProvider(platform: HostPlatform.macos);
    }
    return const _UnsupportedServerOsCommandProvider();
  }
}

class _WindowsServerOsCommandProvider extends ServerOsCommandProvider {
  const _WindowsServerOsCommandProvider();

  @override
  HostPlatform get platform => HostPlatform.windows;

  @override
  Future<void> killPid(int pid) async {
    if (pid <= 0) return;
    await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
  }

  @override
  Future<bool> isPidRunning(int pid) async {
    if (pid <= 0) return false;
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      'if (Get-Process -Id $pid -ErrorAction SilentlyContinue) { exit 0 } else { exit 1 }',
    ]);
    return result.exitCode == 0;
  }

  @override
  Future<int?> getPidMemoryMb(int pid) async {
    if (pid <= 0) return null;
    final result = await Process.run('powershell', [
      '-NoProfile',
      '-Command',
      r'$p=Get-Process -Id $args[0] -ErrorAction SilentlyContinue; if($null -eq $p){exit 1}; [int]([math]::Round($p.WorkingSet64/1MB))',
      '$pid',
    ]);
    if (result.exitCode != 0) return null;
    return int.tryParse(result.stdout.toString().trim());
  }

  @override
  Future<List<int>> findMatchingServerProcessIds(String jarFile) async {
    final normalizedJar = jarFile.trim();
    if (normalizedJar.isEmpty) return [];

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
      normalizedJar,
    ]);
    if (result.exitCode != 0) return [];

    return result.stdout
        .toString()
        .split(RegExp(r'\s+'))
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .toList();
  }
}

class _LinuxServerOsCommandProvider extends ServerOsCommandProvider {
  const _LinuxServerOsCommandProvider({this.platform = HostPlatform.linux});

  @override
  final HostPlatform platform;

  @override
  Future<void> killPid(int pid) async {
    if (pid <= 0) return;
    await Process.run('kill', ['-TERM', '$pid']);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (await isPidRunning(pid)) {
      await Process.run('kill', ['-KILL', '$pid']);
    }
  }

  @override
  Future<bool> isPidRunning(int pid) async {
    if (pid <= 0) return false;
    final result = await Process.run('kill', ['-0', '$pid']);
    return result.exitCode == 0;
  }

  @override
  Future<int?> getPidMemoryMb(int pid) async {
    if (pid <= 0) return null;
    if (platform == HostPlatform.linux) {
      final status = File('/proc/$pid/status');
      if (await status.exists()) {
        final content = await status.readAsString();
        for (final line in content.split('\n')) {
          if (!line.startsWith('VmRSS:')) continue;
          final value = line.replaceFirst('VmRSS:', '').trim();
          final kb = int.tryParse(value.split(RegExp(r'\s+')).first);
          if (kb != null && kb > 0) {
            return (kb / 1024).round();
          }
        }
      }
    }

    final result = await Process.run('ps', ['-o', 'rss=', '-p', '$pid']);
    if (result.exitCode != 0) return null;
    final rssKb = int.tryParse(result.stdout.toString().trim());
    if (rssKb == null || rssKb <= 0) return null;
    return (rssKb / 1024).round();
  }

  @override
  Future<List<int>> findMatchingServerProcessIds(String jarFile) async {
    final escapedJar = RegExp.escape(jarFile.trim());
    if (escapedJar.isEmpty) return [];

    if (platform == HostPlatform.linux) {
      final pattern = 'java(w)?\\b.*-jar\\b.*$escapedJar';
      final pgrep = await Process.run('pgrep', ['-f', pattern]);
      if (pgrep.exitCode == 0) {
        final pids = pgrep.stdout
            .toString()
            .split(RegExp(r'\s+'))
            .map((value) => int.tryParse(value.trim()))
            .whereType<int>()
            .toList();
        if (pids.isNotEmpty) {
          return pids;
        }
      }
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
}

class _UnsupportedServerOsCommandProvider extends ServerOsCommandProvider {
  const _UnsupportedServerOsCommandProvider();

  @override
  HostPlatform get platform => HostPlatform.unknown;

  @override
  Future<void> killPid(int pid) {
    throw UnsupportedError('Sistema operacional nao suportado.');
  }

  @override
  Future<bool> isPidRunning(int pid) {
    throw UnsupportedError('Sistema operacional nao suportado.');
  }

  @override
  Future<int?> getPidMemoryMb(int pid) {
    throw UnsupportedError('Sistema operacional nao suportado.');
  }

  @override
  Future<List<int>> findMatchingServerProcessIds(String jarFile) {
    throw UnsupportedError('Sistema operacional nao suportado.');
  }
}
