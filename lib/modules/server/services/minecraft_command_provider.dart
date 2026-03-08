abstract class MinecraftCommandProvider {
  const MinecraftCommandProvider();

  static const MinecraftCommandProvider vanilla =
      _VanillaMinecraftCommandProvider();

  String stopServer();
  String listPlayers();
  String saveAll({bool flush = false});
  String say(String message, {String? prefix});
  String kick(String target, String message);
  String whitelistAdd(String nickname);
  String whitelistRemove(String nickname);
  String op(String nickname);
  String deop(String nickname);
  String ban(String nickname, {String? reason});
  String pardon(String nickname);
  String gamerulePvp(bool enabled);
  String timeSetDay();

  String chunkyProgress();
  String chunkyCancel();
  String chunkyPause();
  String chunkyContinue();
  String chunkyStart();
  String chunkyWorld(String world);
  String chunkyCenter(Object x, Object z);
  String chunkyRadius({
    required int radius,
    required String shape,
    required String mode,
  });
  String chunkyShape(String shape);
  String chunkyPattern(String pattern);
}

class _VanillaMinecraftCommandProvider extends MinecraftCommandProvider {
  const _VanillaMinecraftCommandProvider();

  @override
  String stopServer() => 'stop';

  @override
  String listPlayers() => 'list';

  @override
  String saveAll({bool flush = false}) => flush ? 'save-all flush' : 'save-all';

  @override
  String say(String message, {String? prefix}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'say';
    }
    if (prefix == null || prefix.trim().isEmpty) {
      return 'say $trimmed';
    }
    return 'say ${prefix.trim()} $trimmed';
  }

  @override
  String kick(String target, String message) {
    final safeTarget = target.trim();
    final safeMessage = message.trim();
    if (safeMessage.isEmpty) {
      return 'kick $safeTarget';
    }
    return 'kick $safeTarget $safeMessage';
  }

  @override
  String whitelistAdd(String nickname) => 'whitelist add ${nickname.trim()}';

  @override
  String whitelistRemove(String nickname) => 'whitelist remove ${nickname.trim()}';

  @override
  String op(String nickname) => 'op ${nickname.trim()}';

  @override
  String deop(String nickname) => 'deop ${nickname.trim()}';

  @override
  String ban(String nickname, {String? reason}) {
    final safeNickname = nickname.trim();
    final safeReason = reason?.trim() ?? '';
    if (safeReason.isEmpty) {
      return 'ban $safeNickname';
    }
    return 'ban $safeNickname $safeReason';
  }

  @override
  String pardon(String nickname) => 'pardon ${nickname.trim()}';

  @override
  String gamerulePvp(bool enabled) =>
      enabled ? '/gamerule pvp true' : '/gamerule pvp false';

  @override
  String timeSetDay() => 'time set day';

  @override
  String chunkyProgress() => 'chunky progress';

  @override
  String chunkyCancel() => 'chunky cancel';

  @override
  String chunkyPause() => 'chunky pause';

  @override
  String chunkyContinue() => 'chunky continue';

  @override
  String chunkyStart() => 'chunky start';

  @override
  String chunkyWorld(String world) => 'chunky world ${world.trim()}';

  @override
  String chunkyCenter(Object x, Object z) => 'chunky center $x $z';

  @override
  String chunkyRadius({
    required int radius,
    required String shape,
    required String mode,
  }) {
    final lowerShape = shape.toLowerCase();
    final useDouble = switch (mode) {
      'double' => true,
      'single' => false,
      _ => lowerShape == 'rectangle' || lowerShape == 'ellipse',
    };
    if (useDouble) {
      return 'chunky radius $radius $radius';
    }
    return 'chunky radius $radius';
  }

  @override
  String chunkyShape(String shape) => 'chunky shape ${shape.trim()}';

  @override
  String chunkyPattern(String pattern) => 'chunky pattern ${pattern.trim()}';
}
