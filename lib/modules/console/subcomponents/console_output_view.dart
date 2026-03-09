import 'package:flutter/material.dart';

import '../../../models/console_entry.dart';
import 'console_line_item.dart';

class ConsoleOutputController {
  VoidCallback? _scrollToBottomAndFollow;

  void attach(VoidCallback callback) {
    _scrollToBottomAndFollow = callback;
  }

  void detach(VoidCallback callback) {
    if (_scrollToBottomAndFollow == callback) {
      _scrollToBottomAndFollow = null;
    }
  }

  void scrollToBottomAndFollow() {
    _scrollToBottomAndFollow?.call();
  }
}

class ConsoleOutputView extends StatefulWidget {
  const ConsoleOutputView({super.key, required this.entries, this.controller});

  final List<ConsoleEntry> entries;
  final ConsoleOutputController? controller;

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
    widget.controller?.attach(_scrollToBottomAndFollow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottomAndFollow(animated: false);
    });
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final distance =
        _scrollController.position.maxScrollExtent - _scrollController.offset;
    _stickToBottom = distance <= _bottomThreshold;
  }

  void _scrollToBottomAndFollow({bool animated = true}) {
    _stickToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      final offset = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
        );
        return;
      }
      _scrollController.jumpTo(offset);
    });
  }

  @override
  void didUpdateWidget(covariant ConsoleOutputView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.detach(_scrollToBottomAndFollow);
      widget.controller?.attach(_scrollToBottomAndFollow);
    }
    if (widget.entries.length != oldWidget.entries.length && _stickToBottom) {
      _scrollToBottomAndFollow();
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_scrollToBottomAndFollow);
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B0B0B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
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
