import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/console_entry.dart';

class ConsoleLineItem extends StatelessWidget {
  const ConsoleLineItem({super.key, required this.entry});

  final ConsoleEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = switch (entry.source) {
      ConsoleEntrySource.server => const Color(0xFFE5E7EB),
      ConsoleEntrySource.user => scheme.primary,
      ConsoleEntrySource.system => scheme.error,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: const Color(0xFF9CA3AF)),
          children: [
            TextSpan(text: '[${DateFormat.Hms().format(entry.timestamp)}] '),
            TextSpan(text: entry.message, style: TextStyle(color: color, fontFamily: 'Consolas')),
          ],
        ),
      ),
    );
  }
}
