import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/server_image.dart';
import '../../models/draft_model.dart';
import 'draft_widgets.dart';
import 'order_service.dart';

enum DraftPreviewResult { confirm }

class DraftPreviewScreen extends StatefulWidget {
  final int orderId;
  final DraftModel draft;
  final bool isDesigner;
  final bool orderCompleted;

  const DraftPreviewScreen({
    super.key,
    required this.orderId,
    required this.draft,
    required this.isDesigner,
    required this.orderCompleted,
  });

  @override
  State<DraftPreviewScreen> createState() => _DraftPreviewScreenState();
}

class _DraftPreviewScreenState extends State<DraftPreviewScreen> {
  final OrderService _orderService = OrderService();
  bool _downloading = false;

  DraftModel get _draft => widget.draft;
  bool get _darkMode => _draft.hasPreview && (_draft.isImage || _draft.isVideo);

  Future<void> _download() async {
    setState(() => _downloading = true);
    await downloadDraftOriginal(context, _orderService, widget.orderId, _draft);
    if (mounted) setState(() => _downloading = false);
  }

  void _openPdf() {
    final url = ServerImage.fullUrl(_draft.watermarkedFileUrl);
    if (url != null) openExternalUrl(context, url);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (_draft.hasPreview && _draft.isImage) {
      body = _buildImagePreview();
    } else if (_draft.hasPreview && _draft.isVideo) {
      body = _VideoPreview(
        url: ServerImage.fullUrl(_draft.watermarkedFileUrl)!,
      );
    } else {
      body = _buildFileInfo();
    }

    return Scaffold(
      backgroundColor: _darkMode ? Colors.black : AppColors.background,
      appBar: AppBar(
        backgroundColor: _darkMode ? Colors.black : AppColors.surface,
        foregroundColor: _darkMode ? Colors.white : null,
        title: Text('Draft v${_draft.versionNo}'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                _draft.detailsLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: _darkMode ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: _buildActions(),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: ServerImage(
              url: _draft.watermarkedFileUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _draft.extension == 'jpg' ||
                        _draft.extension == 'jpeg' ||
                        _draft.extension == 'png'
                    ? 'Bana au scroll kukuza picha'
                    : 'Preview ya ${_draft.typeLabel} • Bana kukuza',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo() {
    final String message;
    if (widget.orderCompleted) {
      message = 'Oda imekamilika. Faili kamili (bila watermark) liko tayari kupakuliwa.';
    } else if (_draft.isPdf && _draft.hasPreview) {
      message = _draft.extension == 'pdf'
          ? 'PDF hii ina watermark ya "DesignBora - PREVIEW". Ifungue uikague kabla ya kuthibitisha.'
          : 'Faili la ${_draft.typeLabel} limebadilishwa kuwa PDF yenye watermark ili uweze kulikagua.';
    } else if (_draft.isArchive) {
      message = _draft.archiveEntries.isEmpty
          ? 'Faili la ZIP. Orodha ya faili zilizomo haikuweza kusomwa.'
          : 'Faili hili la ZIP lina faili ${_draft.archiveEntries.length}. Utazipakua zote baada ya kuthibitisha.';
    } else if (widget.isDesigner) {
      message =
          'Faili la aina hii halina preview. Mteja atalipakua baada ya kuthibitisha. '
          'Ni vizuri kutuma pia picha ya mfano ili mteja aone kazi.';
    } else {
      message =
          'Faili la aina hii halina preview. Utalipakua likiwa kamili baada ya kuthibitisha. '
          'Kama unahitaji kuona kazi kwanza, mwombe mbunifu akutumie picha ya mfano kwenye chat.';
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: AppDecorations.card(radius: 20),
              child: Column(
                children: [
                  FileTypeIcon(extension: _draft.extension, size: 84),
                  const SizedBox(height: 16),
                  Text(
                    'Draft v${_draft.versionNo}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _draft.detailsLabel,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_draft.isPdf &&
                      _draft.hasPreview &&
                      !widget.orderCompleted) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _openPdf,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text(
                          'Fungua Preview',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                  if (_draft.isArchive && _draft.archiveEntries.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'FAILI ZILIZOMO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._draft.archiveEntries.map((entry) {
                      final name = entry.name;
                      final ext = name.contains('.')
                          ? name.split('.').last
                          : '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5),
                        child: Row(
                          children: [
                            FileTypeIcon(extension: ext, size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12.5),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              formatFileSize(entry.size) ?? '',
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildActions() {
    final Widget button;

    if (widget.orderCompleted) {
      button = ElevatedButton.icon(
        style: _buttonStyle(AppColors.primary),
        onPressed: _downloading ? null : _download,
        icon: _downloading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.download_rounded, size: 20),
        label: const Text(
          'Pakua Faili Kamili',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else if (!widget.isDesigner) {
      button = ElevatedButton.icon(
        style: _buttonStyle(AppColors.statusCompleted),
        onPressed: () => Navigator.pop(context, DraftPreviewResult.confirm),
        icon: const Icon(Icons.check_circle_rounded, size: 20),
        label: const Text(
          'Nimeridhika, Thibitisha',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      );
    } else {
      return null;
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: _darkMode ? Colors.black : AppColors.surface,
        child: SizedBox(height: 50, child: button),
      ),
    );
  }

  ButtonStyle _buttonStyle(Color color) {
    return ElevatedButton.styleFrom(
      backgroundColor: color,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

/// Kicheza video ya preview (sekunde 30, yenye watermark)
class _VideoPreview extends StatefulWidget {
  final String url;
  const _VideoPreview({required this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final VideoPlayerController _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Imeshindwa kucheza video ya preview.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }
    if (!_controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        VideoProgressIndicator(
          _controller,
          allowScrubbing: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          colors: const VideoProgressColors(
            playedColor: AppColors.accent,
            bufferedColor: Colors.white24,
            backgroundColor: Colors.white12,
          ),
        ),
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: _controller,
          builder: (context, value, _) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    iconSize: 44,
                    color: Colors.white,
                    onPressed: () => value.isPlaying
                        ? _controller.pause()
                        : _controller.play(),
                    icon: Icon(
                      value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_fill_rounded,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Preview ya sekunde 30 • yenye watermark',
                    style: TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
