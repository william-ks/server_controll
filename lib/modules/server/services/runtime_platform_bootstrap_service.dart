import '../../../database/app_database.dart';
import 'server_os_command_provider.dart';

class RuntimePlatformBootstrapService {
  RuntimePlatformBootstrapService({ServerOsCommandProvider? osProvider})
    : _osProvider = osProvider ?? ServerOsCommandProvider.fromCurrentPlatform();

  final ServerOsCommandProvider _osProvider;

  Future<void> applyStartupPlatformValidation() async {
    final db = AppDatabase.instance;
    await db.setSetting(
      'runtime_host_platform',
      _platformLabel(_osProvider.platform),
    );

    final javaCommand = (await db.getSetting('java_command'))?.trim();
    final normalizedJavaCommand = _normalizeJavaCommand(javaCommand);
    if (normalizedJavaCommand != null) {
      await db.setSetting('java_command', normalizedJavaCommand);
    }
  }

  String _platformLabel(HostPlatform platform) {
    return switch (platform) {
      HostPlatform.windows => 'windows',
      HostPlatform.linux => 'linux',
      HostPlatform.macos => 'macos',
      HostPlatform.unknown => 'unknown',
    };
  }

  String? _normalizeJavaCommand(String? currentValue) {
    final normalized = currentValue?.trim() ?? '';
    if (normalized.isEmpty) {
      return _osProvider.defaultJavaCommand;
    }

    final lower = normalized.toLowerCase();
    final isPosix =
        _osProvider.platform == HostPlatform.linux ||
        _osProvider.platform == HostPlatform.macos;
    if (isPosix && lower.endsWith('.exe')) {
      return _osProvider.defaultJavaCommand;
    }

    return null;
  }
}
