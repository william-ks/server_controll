enum ChunkyTaskStatus { draft, selected, running, paused, completed, cancelled }

extension ChunkyTaskStatusX on ChunkyTaskStatus {
  String get storageValue => name;

  String get label => switch (this) {
    ChunkyTaskStatus.draft => 'RASCUNHO',
    ChunkyTaskStatus.selected => 'SELECIONADA',
    ChunkyTaskStatus.running => 'EM EXECUCAO',
    ChunkyTaskStatus.paused => 'PAUSADA',
    ChunkyTaskStatus.completed => 'CONCLUIDA',
    ChunkyTaskStatus.cancelled => 'CANCELADA',
  };

  static ChunkyTaskStatus fromStorage(String raw) {
    for (final value in ChunkyTaskStatus.values) {
      if (value.storageValue == raw) {
        return value;
      }
    }
    return ChunkyTaskStatus.draft;
  }
}

class ChunkyWorldOption {
  const ChunkyWorldOption({required this.id, required this.label});

  final String id;
  final String label;
}

const List<ChunkyWorldOption> chunkyWorldOptions = <ChunkyWorldOption>[
  ChunkyWorldOption(id: 'overworld', label: 'Overworld'),
  ChunkyWorldOption(id: 'the_nether', label: 'Nether'),
  ChunkyWorldOption(id: 'the_end', label: 'The End'),
];

String chunkyWorldLabel(String worldId) {
  for (final option in chunkyWorldOptions) {
    if (option.id == worldId) {
      return option.label;
    }
  }
  return worldId;
}
