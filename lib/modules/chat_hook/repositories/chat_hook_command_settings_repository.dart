import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../services/chat_command_registry.dart';

final chatHookCommandSettingsRepositoryProvider =
    Provider<ChatHookCommandSettingsRepository>(
      (_) => ChatHookCommandSettingsRepository(),
    );

class ChatHookCommandSettingsRepository {
  Future<ChatCommandPermissionPolicy> getPermission({
    required String command,
    required ChatCommandPermissionPolicy fallback,
  }) async {
    final raw = await AppDatabase.instance.getSetting(_key(command));
    return ChatCommandPermissionPolicyX.fromStorageValue(raw) ?? fallback;
  }

  Future<void> setPermission({
    required String command,
    required ChatCommandPermissionPolicy permission,
  }) async {
    await AppDatabase.instance.setSetting(
      _key(command),
      permission.storageValue,
    );
  }

  String _key(String command) => 'chat_hook_permission_${command.trim().toLowerCase()}';
}
