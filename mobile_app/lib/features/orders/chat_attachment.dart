import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../../models/chat_message_model.dart';

const int kMaxAttachmentBytes = 25 * 1024 * 1024;

/// Kupakia na kupakua faili za chat (zinahitaji login, kwa hiyo zinapita kwenye dio)
class ChatAttachments {
  ChatAttachments._();
  static final Map<String, Future<Uint8List>> _cache = {};

  static Future<void> upload({
    required int orderId,
    required PlatformFile file,
    void Function(double progress)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(file.bytes!, filename: file.name),
    });
    await ApiClient().dio.post(
      '/orders/$orderId/attachments',
      data: form,
      onSendProgress: (sent, total) {
        if (total > 0) onProgress?.call(sent / total);
      },
    );
  }

  static Future<Uint8List> bytes(String url) {
    return _cache.putIfAbsent(url, () async {
      try {
        final res = await ApiClient().dio.get<List<int>>(
          url,
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(res.data!);
      } catch (e) {
        _cache.remove(url);
        rethrow;
      }
    });
  }

  static Future<void> open(BuildContext context, ChatMessageModel m) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await bytes(m.attachmentUrl!);
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/${m.attachmentId}_${m.attachmentName}');
      await f.writeAsBytes(data, flush: true);
      final r = await OpenFilex.open(f.path);
      if (r.type != ResultType.done) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Hakuna app ya kufungua "${m.attachmentName}" kwenye simu hii',
            ),
          ),
        );
      }
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Imeshindwa kufungua faili. Jaribu tena.'),
        ),
      );
    }
  }

  static String formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Maudhui ya kiputo: faili (kama lipo) + maandishi
class ChatMessageBody extends StatelessWidget {
  final ChatMessageModel message;
  final Widget text;

  const ChatMessageBody({super.key, required this.message, required this.text});

  @override
  Widget build(BuildContext context) {
    if (!message.hasAttachment) return text;
    final caption = message.message.trim();
    final showText =
        caption.isNotEmpty && caption != '📎 ${message.attachmentName}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        message.isImage
            ? _ImageAttachment(message: message)
            : _FileAttachment(message: message),
        if (showText) ...[const SizedBox(height: 6), text],
      ],
    );
  }
}

class _ImageAttachment extends StatelessWidget {
  final ChatMessageModel message;
  const _ImageAttachment({required this.message});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: ChatAttachments.bytes(message.attachmentUrl!),
      builder: (context, snap) {
        Widget child;
        if (snap.hasData) {
          child = Image.memory(snap.data!, fit: BoxFit.cover);
        } else if (snap.hasError) {
          child = const Center(
            child: Icon(Icons.broken_image_outlined, size: 36),
          );
        } else {
          child = const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return GestureDetector(
          onTap: snap.hasData
              ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => _ImageViewer(
                      bytes: snap.data!,
                      title: message.attachmentName ?? '',
                    ),
                  ),
                )
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              height: 220,
              color: Colors.black12,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _ImageViewer extends StatelessWidget {
  final Uint8List bytes;
  final String title;
  const _ImageViewer({required this.bytes, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(fontSize: 15)),
      ),
      body: Center(
        child: InteractiveViewer(maxScale: 5, child: Image.memory(bytes)),
      ),
    );
  }
}

class _FileAttachment extends StatelessWidget {
  final ChatMessageModel message;
  const _FileAttachment({required this.message});

  IconData get _icon {
    final n = (message.attachmentName ?? '').toLowerCase();
    bool ends(List<String> exts) => exts.any(n.endsWith);
    if (ends(['.pdf'])) {
      return Icons.picture_as_pdf_rounded;
    }
    if (ends(['.zip', '.rar', '.7z'])) {
      return Icons.folder_zip_rounded;
    }
    if (ends(['.ai', '.psd', '.svg', '.eps'])) {
      return Icons.brush_rounded;
    }
    if (ends(['.mp4', '.mov'])) {
      return Icons.movie_rounded;
    }
    if (ends(['.doc', '.docx', '.txt'])) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => ChatAttachments.open(context, message),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icon, size: 30, color: color),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.attachmentName ?? 'Faili',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${ChatAttachments.formatSize(message.attachmentSize)} • Gusa kufungua',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: color?.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
