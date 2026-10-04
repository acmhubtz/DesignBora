import 'package:flutter/material.dart';

import '../constants/api_constants.dart';
import '../theme/app_colors.dart';

/// Inaonyesha picha iliyohifadhiwa kwenye backend.
/// Inakubali URL fupi ("/uploads/...") au kamili ("http://...").
class ServerImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;

  const ServerImage({super.key, required this.url, this.fit = BoxFit.cover});

  static String? fullUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final path = url.startsWith('/') ? url : '/$url';
    return '${ApiConstants.serverUrl}$path';
  }

  @override
  Widget build(BuildContext context) {
    final resolved = fullUrl(url);
    if (resolved == null) {
      return const _ImagePlaceholder(icon: Icons.image_rounded);
    }

    return Image.network(
      resolved,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          color: AppColors.primary.withValues(alpha: 0.06),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.accent,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) =>
          const _ImagePlaceholder(icon: Icons.broken_image_rounded),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  final IconData icon;
  const _ImagePlaceholder({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      alignment: Alignment.center,
      child: Icon(icon, size: 36, color: AppColors.textMuted),
    );
  }
}
