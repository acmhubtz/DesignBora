import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/server_image.dart';
import '../../models/draft_model.dart';
import 'order_service.dart';

IconData fileIconFor(String extension) {
  switch (extension.toLowerCase()) {
    case 'pdf':
      return Icons.picture_as_pdf_rounded;
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'webp':
    case 'gif':
      return Icons.image_rounded;
    case 'mp4':
    case 'mov':
    case 'avi':
    case 'mkv':
      return Icons.movie_rounded;
    case 'zip':
    case 'rar':
    case '7z':
      return Icons.folder_zip_rounded;
    case 'doc':
    case 'docx':
    case 'txt':
      return Icons.description_rounded;
    case 'psd':
    case 'ai':
    case 'svg':
    case 'eps':
    case 'fig':
    case 'cdr':
      return Icons.brush_rounded;
    default:
      return Icons.insert_drive_file_rounded;
  }
}

Color fileColorFor(String extension) {
  switch (fileIconFor(extension)) {
    case Icons.picture_as_pdf_rounded:
      return const Color(0xFFDC2626);
    case Icons.image_rounded:
      return const Color(0xFF2563EB);
    case Icons.movie_rounded:
      return const Color(0xFF8B5CF6);
    case Icons.folder_zip_rounded:
      return const Color(0xFFD97706);
    case Icons.brush_rounded:
      return AppColors.accent;
    default:
      return AppColors.primary;
  }
}

/// Ikoni ya aina ya faili ndani ya kisanduku chenye rangi
class FileTypeIcon extends StatelessWidget {
  final String extension;
  final double size;

  const FileTypeIcon({super.key, required this.extension, this.size = 48});

  @override
  Widget build(BuildContext context) {
    final color = fileColorFor(extension);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: Icon(fileIconFor(extension), color: color, size: size * 0.5),
    );
  }
}

/// Picha ndogo ya draft: picha halisi (yenye watermark) au ikoni ya aina ya faili
class DraftThumbnail extends StatelessWidget {
  final DraftModel draft;
  final double size;

  const DraftThumbnail({super.key, required this.draft, this.size = 64});

  @override
  Widget build(BuildContext context) {
    if (draft.isImage && draft.hasPreview) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: ServerImage(url: draft.watermarkedFileUrl),
        ),
      );
    }
    return FileTypeIcon(extension: draft.extension, size: size);
  }
}

/// Inafungua URL kwenye tabo/app nyingine
Future<void> openExternalUrl(BuildContext context, String url) async {
  final messenger = ScaffoldMessenger.of(context);
  final ok = await launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
    webOnlyWindowName: '_blank',
  );
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Imeshindwa kufungua faili')),
    );
  }
}

/// Inapakua faili la asili (inafanya kazi tu oda ikiwa COMPLETED)
Future<void> downloadDraftOriginal(
  BuildContext context,
  OrderService service,
  int orderId,
  DraftModel draft,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final info = await service.getDraftDownload(orderId, draft.id);
    final url = ServerImage.fullUrl(info.url);
    if (url == null) throw Exception('URL tupu');
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Imeshindwa kufungua faili')),
      );
    }
  } catch (e) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Imeshindwa kupakua faili. Jaribu tena.')),
    );
  }
}
