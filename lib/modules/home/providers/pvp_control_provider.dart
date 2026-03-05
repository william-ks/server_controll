import 'package:flutter_riverpod/flutter_riverpod.dart';

class PvpControlState {
  const PvpControlState({required this.enabled, required this.updating});

  final bool enabled;
  final bool updating;

  PvpControlState copyWith({bool? enabled, bool? updating}) {
    return PvpControlState(
      enabled: enabled ?? this.enabled,
      updating: updating ?? this.updating,
    );
  }

  factory PvpControlState.initial() {
    return const PvpControlState(enabled: true, updating: false);
  }
}

final pvpControlProvider =
    NotifierProvider<PvpControlNotifier, PvpControlState>(
      PvpControlNotifier.new,
    );

class PvpControlNotifier extends Notifier<PvpControlState> {
  @override
  PvpControlState build() {
    return PvpControlState.initial();
  }

  void setDesired(bool enabled) {
    state = state.copyWith(enabled: enabled);
  }
}
