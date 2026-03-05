import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/chunky_tab.dart';

final chunkyTabProvider = NotifierProvider<ChunkyTabNotifier, ChunkyTab>(
  ChunkyTabNotifier.new,
);

class ChunkyTabNotifier extends Notifier<ChunkyTab> {
  @override
  ChunkyTab build() => ChunkyTab.execution;

  void setTab(ChunkyTab tab) {
    state = tab;
  }
}
