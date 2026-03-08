import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutoBackupStatusState {
  const AutoBackupStatusState({
    required this.running,
    this.lastError,
    this.lastFailureAt,
  });

  final bool running;
  final String? lastError;
  final DateTime? lastFailureAt;

  AutoBackupStatusState copyWith({
    bool? running,
    String? lastError,
    DateTime? lastFailureAt,
    bool clearError = false,
  }) {
    return AutoBackupStatusState(
      running: running ?? this.running,
      lastError: clearError ? null : (lastError ?? this.lastError),
      lastFailureAt: lastFailureAt ?? this.lastFailureAt,
    );
  }

  factory AutoBackupStatusState.initial() {
    return const AutoBackupStatusState(running: false);
  }
}

final autoBackupStatusProvider =
    NotifierProvider<AutoBackupStatusNotifier, AutoBackupStatusState>(
      AutoBackupStatusNotifier.new,
    );

class AutoBackupStatusNotifier extends Notifier<AutoBackupStatusState> {
  @override
  AutoBackupStatusState build() {
    return AutoBackupStatusState.initial();
  }

  void setRunning(bool value) {
    state = state.copyWith(running: value);
  }

  void markFailure(String message) {
    state = state.copyWith(
      running: false,
      lastError: message.trim(),
      lastFailureAt: DateTime.now(),
    );
  }

  void clearFailure() {
    state = state.copyWith(clearError: true);
  }
}
