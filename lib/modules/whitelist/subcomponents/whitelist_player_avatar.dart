import 'dart:io';

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class WhitelistPlayerAvatar extends StatelessWidget {
  const WhitelistPlayerAvatar({super.key, this.iconPath});

  final String? iconPath;

  @override
  Widget build(BuildContext context) {
    final fileExists = iconPath != null && iconPath!.isNotEmpty && File(iconPath!).existsSync();

    return CircleAvatar(
      radius: 22,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: fileExists
          ? ClipOval(
              child: Image.file(
                File(iconPath!),
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.person_rounded, color: AppColors.neutral),
    );
  }
}
