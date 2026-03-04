import 'dart:io';

import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class WhitelistPlayerAvatar extends StatelessWidget {
  const WhitelistPlayerAvatar({super.key, this.iconPath, this.radius = 22});

  final String? iconPath;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final fileExists = iconPath != null && iconPath!.isNotEmpty && File(iconPath!).existsSync();

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: fileExists
          ? ClipOval(
              child: Image.file(
                File(iconPath!),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
              ),
            )
          : const Icon(Icons.person_rounded, color: AppColors.neutral),
    );
  }
}
