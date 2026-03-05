import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../database/app_database.dart';
import '../models/whitelist_player.dart';
import '../repositories/whitelist_repository.dart';

class WhitelistSyncService {
  WhitelistSyncService(this._repository);

  final WhitelistRepository _repository;

  Future<List<WhitelistPlayer>> syncFromServerFile() async {
    final serverDir = await AppDatabase.instance.getSetting('server_dir') ??
        '${Directory.current.parent.path}${Platform.pathSeparator}server_copy';
    final whitelistPath = await AppDatabase.instance.getSetting('whitelist_path') ?? 'whitelist.json';

    final file = File(p.join(serverDir, whitelistPath));
    if (!await file.exists()) {
      return _repository.getAll();
    }

    final raw = await file.readAsString();
    final dynamic parsed = jsonDecode(raw);
    if (parsed is! List) {
      return _repository.getAll();
    }

    final localPlayers = await _repository.getAll();
    final localByNickname = {
      for (final player in localPlayers) player.nickname.toLowerCase(): player,
    };
    final serverUuids = <String>{};
    final serverNames = <String>{};

    for (final item in parsed.whereType<Map>()) {
      final nickname = (item['name'] as String?)?.trim();
      if (nickname == null || nickname.isEmpty) {
        continue;
      }
      final uuid = item['uuid'] as String?;
      if (uuid != null && uuid.trim().isNotEmpty) {
        serverUuids.add(uuid.trim().toLowerCase());
      }
      serverNames.add(nickname.toLowerCase());
      final existing = localByNickname[nickname.toLowerCase()];
      final now = DateTime.now();
      final player = (existing ??
              WhitelistPlayer(
                nickname: nickname,
                uuid: uuid,
                iconPath: null,
                isPending: false,
                isAdded: true,
                createdAt: now,
                updatedAt: now,
              ))
          .copyWith(
            uuid: uuid ?? existing?.uuid,
            isPending: false,
            isAdded: true,
            updatedAt: now,
          );

      await _repository.upsertByNickname(player);
    }

    final refreshed = await _repository.getAll();
    for (final player in refreshed) {
      final uuid = player.uuid?.trim();
      final hasUuidInServerFile = uuid != null && uuid.isNotEmpty && serverUuids.contains(uuid.toLowerCase());
      final hasNameInServerFile = serverNames.contains(player.nickname.toLowerCase());

      final shouldBePending = !hasUuidInServerFile || !hasNameInServerFile;
      if (player.isPending != shouldBePending || player.isAdded == shouldBePending) {
        await _repository.upsertByNickname(
          player.copyWith(
            isPending: shouldBePending,
            isAdded: !shouldBePending,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }

    return _repository.getAll();
  }

  Future<void> syncPendingToServer({
    required bool isServerOnline,
    required Future<void> Function(String command) sendCommand,
  }) async {
    if (!isServerOnline) {
      return;
    }

    final pending = await _repository.pending();
    for (final player in pending) {
      await sendCommand('whitelist add ${player.nickname}');
      await _repository.upsertByNickname(
        player.copyWith(
          isPending: false,
          isAdded: true,
          updatedAt: DateTime.now(),
        ),
      );
    }

    await syncFromServerFile();
  }

  Future<String?> persistIcon({required String nickname, required String sourcePath}) async {
    final ext = p.extension(sourcePath).toLowerCase();
    final safeExt = (ext.isEmpty || ext.length > 6) ? '.png' : ext;
    final appDir = await getApplicationSupportDirectory();
    final iconsDir = Directory(p.join(appDir.path, 'whitelist_icons'));
    if (!await iconsDir.exists()) {
      await iconsDir.create(recursive: true);
    }

    final normalized = nickname.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
    final safeName = normalized.isEmpty ? 'player_${DateTime.now().millisecondsSinceEpoch}' : normalized;
    final targetPath = p.join(iconsDir.path, '$safeName$safeExt');
    await File(sourcePath).copy(targetPath);
    return targetPath;
  }
}


