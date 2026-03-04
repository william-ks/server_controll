import 'package:flutter/material.dart';

import '../../../models/console_entry.dart';
import 'console_line_item.dart';

class ConsoleOutputView extends StatefulWidget {
  const ConsoleOutputView({
    super.key,
    required this.entries,
  });

  final List<ConsoleEntry> entries;

  @override
  State<ConsoleOutputView> createState() => _ConsoleOutputViewState();
}

class _ConsoleOutputViewState extends State<ConsoleOutputView> {
  static const double _bottomThreshold = 48;
  final ScrollController _scrollController = ScrollController();
  bool _stickToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final distance = _scrollController.position.maxScrollExtent - _scrollController.offset;
    _stickToBottom = distance <= _bottomThreshold;
  }

  @override
  void didUpdateWidget(covariant ConsoleOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.entries.length != oldWidget.entries.length && _stickToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(10),
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
