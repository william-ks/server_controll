import '../../../database/app_database.dart';

class ConfigFilesSettings {
  const ConfigFilesSettings({
    required this.serverPath,
    required this.ramMinGb,
    required this.ramMaxGb,
    required this.fileServerName,
    required this.javaCommand,
    required this.jvmArgs,
    required this.autoRestartOnCrash,
    required this.restartWaitSeconds,
  });

  final String serverPath;
  final String ramMinGb;
  final String ramMaxGb;
  final String fileServerName;
  final String javaCommand;
  final String jvmArgs;
  final bool autoRestartOnCrash;
  final String restartWaitSeconds;

  factory ConfigFilesSettings.defaults() {
    return const ConfigFilesSettings(
      serverPath: '',
      ramMinGb: '2',
      ramMaxGb: '8',
      fileServerName: '',
      javaCommand: '',
      jvmArgs: '',
      autoRestartOnCrash: true,
      restartWaitSeconds: '10',
    );
  }

  static Future<ConfigFilesSettings> fromDatabase(AppDatabase db) async {
    final serverPath = await db.getSetting('server_path') ?? await db.getSetting('server_dir') ?? '';
    final fileServerName = await db.getSetting('file_server_name') ?? await db.getSetting('jar_file') ?? '';
    final javaCommand = await db.getSetting('java_command') ?? '';
    final jvmArgs = await db.getSetting('jvm_args') ?? '';
    final ramMinRaw = await db.getSetting('ram_min_gb') ?? _extractGb(await db.getSetting('xms')) ?? '2';
    final ramMaxRaw = await db.getSetting('ram_max_gb') ?? _extractGb(await db.getSetting('xmx')) ?? '8';
    final autoRestartRaw = await db.getSetting('auto_restart_on_crash') ?? '1';
    final restartWaitRaw = await db.getSetting('restart_wait_seconds') ?? '10';

    return ConfigFilesSettings(
      serverPath: serverPath,
      ramMinGb: ramMinRaw,
      ramMaxGb: ramMaxRaw,
      fileServerName: fileServerName,
      javaCommand: javaCommand,
      jvmArgs: jvmArgs,
      autoRestartOnCrash: autoRestartRaw != '0',
      restartWaitSeconds: restartWaitRaw,
    );
  }

  static String? _extractGb(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toUpperCase();
    if (normalized.isEmpty) return null;
    if (normalized.endsWith('G')) {
      return normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
