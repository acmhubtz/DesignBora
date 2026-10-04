import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'server_image.dart';

/// Picha ya wasifu: picha mpya (bytes) > picha ya server > herufi ya kwanza ya jina
class UserAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final Uint8List? bytes;
  final double radius;
  final Color background;
  final Color foreground;

  const UserAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.bytes,
    this.radius = 24,
    this.background = AppColors.primary,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    Widget? image;
    if (bytes != null) {
      image = Image.memory(
        bytes!,
        fit: BoxFit.cover,
        width: size,
        height: size,
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      image = SizedBox(
        width: size,
        height: size,
        child: ServerImage(url: avatarUrl),
      );
    }

    if (image != null) {
      return ClipOval(child: image);
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: background,
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          color: foreground,
          fontSize: radius * 0.8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
