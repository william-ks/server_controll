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

    final javaCommand = (await db.getSetting('java_command'))?.trim() ?? '';
    if (javaCommand.isEmpty) {
      await db.setSetting('java_command', _osProvider.defaultJavaCommand);
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
}
