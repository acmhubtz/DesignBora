import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Dirisha la kuandika maandishi. Linamiliki TextEditingController yake
/// na kuifuta kwa wakati sahihi (baada ya dirisha kufungwa kabisa).
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String confirmLabel = 'Sawa',
  Color? confirmColor,
  int maxLines = 1,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextInputDialog(
      title: title,
      hint: hint,
      confirmLabel: confirmLabel,
      confirmColor: confirmColor,
      maxLines: maxLines,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  final String title;
  final String? hint;
  final String confirmLabel;
  final Color? confirmColor;
  final int maxLines;

  const _TextInputDialog({
    required this.title,
    required this.hint,
    required this.confirmLabel,
    required this.confirmColor,
    required this.maxLines,
  });

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.maxLines,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: widget.hint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Ghairi',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(
            widget.confirmLabel,
            style: TextStyle(
              color: widget.confirmColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
