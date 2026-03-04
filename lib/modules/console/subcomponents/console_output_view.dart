import 'package:flutter/material.dart';

import '../../../models/console_entry.dart';
import 'console_line_item.dart';

class ConsoleOutputView extends StatefulWidget {
  const ConsoleOutputView({
    super.key,
    required this.entries,
    required this.autoScroll,
  });

  final List<ConsoleEntry> entries;
  final bool autoScroll;

  @override
  State<ConsoleOutputView> createState() => _ConsoleOutputViewState();
}

class _ConsoleOutputViewState extends State<ConsoleOutputView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant ConsoleOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.autoScroll && widget.entries.length != oldWidget.entries.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: widget.entries.length,
        itemBuilder: (context, index) {
          return ConsoleLineItem(entry: widget.entries[index]);
        },
      ),
    );
  }
}
