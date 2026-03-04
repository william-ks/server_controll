import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/console_entry.dart';
import '../../../modules/server/providers/server_runtime_provider.dart';

class ConsoleState {
  const ConsoleState({required this.entries});

  final List<ConsoleEntry> entries;

  ConsoleState copyWith({
    List<ConsoleEntry>? entries,
  }) {
    return ConsoleState(entries: entries ?? this.entries);
  }

  factory ConsoleState.initial() {
    return const ConsoleState(entries: []);
  }
}

final consoleProvider = NotifierProvider<ConsoleNotifier, ConsoleState>(ConsoleNotifier.new);

class ConsoleNotifier extends Notifier<ConsoleState> {
  StreamSubscription<String>? _stdoutSub;
  StreamSubscription<String>? _stderrSub;

  @override
  ConsoleState build() {
    final service = ref.read(serverProcessServiceProvider);
    _stdoutSub = service.stdoutLines.listen((line) => _append(ConsoleEntrySource.server, line));
    _stderrSub = service.stderrLines.listen((line) => _append(ConsoleEntrySource.system, line));

    ref.onDispose(() {
      unawaited(_stdoutSub?.cancel());
      unawaited(_stderrSub?.cancel());
    });

    return ConsoleState.initial();
  }

  Future<void> sendCommand(String command) async {
    final trimmed = command.trim();
    if (trimmed.isEmpty) {
      return;
    }

    _append(ConsoleEntrySource.user, trimmed);
    await ref.read(serverRuntimeProvider.notifier).sendCommand(trimmed);
  }

  void _append(ConsoleEntrySource source, String message) {
    final next = List<ConsoleEntry>.from(state.entries)
      ..add(ConsoleEntry(source: source, timestamp: DateTime.now(), message: message));

    final maxLines = 1500;
    if (next.length > maxLines) {
      next.removeRange(0, next.length - maxLines);
    }

    state = state.copyWith(entries: next);
  }
}
