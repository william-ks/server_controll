import 'dart:io';

import 'package:flutter/material.dart';

class WhitelistPlayerAvatar extends StatelessWidget {
  const WhitelistPlayerAvatar({super.key, this.iconPath});

  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    if (iconPath == null || iconPath!.isEmpty || !File(iconPath!).existsSync()) {
      return const SizedBox(width: 44, height: 44);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        File(iconPath!),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
      ),
    );
  }
}
