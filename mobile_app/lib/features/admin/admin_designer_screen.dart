import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/utils/verification_labels.dart';
import '../../core/widgets/server_image.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/widgets/user_avatar.dart';
import '../orders/draft_widgets.dart';
import 'admin_service.dart';

class AdminDesignerScreen extends StatefulWidget {
  final AdminDesigner designer;

  const AdminDesignerScreen({super.key, required this.designer});

  @override
  State<AdminDesignerScreen> createState() => _AdminDesignerScreenState();
}

class _AdminDesignerScreenState extends State<AdminDesignerScreen> {
  final _service = AdminService();
  bool _working = false;
  int? _openingDocId;

  AdminDesigner get _d => widget.designer;

  Future<void> _openDocument(AdminDocument doc) async {
    setState(() => _openingDocId = doc.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final relative = await _service.documentLink(doc.id);
      final url = ServerImage.fullUrl(relative);
      if (!mounted || url == null) return;
      await openExternalUrl(context, url);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AdminService.errorMessage(e) ?? 'Imeshindwa kufungua nyaraka',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _openingDocId = null);
    }
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Kumthibitisha ${_d.fullName}?'),
        content: Text(
          _d.documents.isEmpty
              ? 'Mbunifu huyu HAJAPAKIA nyaraka yoyote. Una uhakika unataka kumthibitisha?'
              : 'Hakikisha umekagua nyaraka zake zote. Atapata alama ya "Amethibitishwa" kwa wateja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(
              'Ghairi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Thibitisha',
              style: TextStyle(
                color: AppColors.statusCompleted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() => _service.approve(_d.designerId), 'Mbunifu amethibitishwa');
  }

  Future<void> _reject() async {
    final reason = await showTextInputDialog(
      context,
      title: 'Sababu ya kukataa',
      hint: 'Mfano: Picha ya kitambulisho haisomeki. Pakia picha iliyo wazi.',
      confirmLabel: 'Kataa',
      confirmColor: Colors.red,
      maxLines: 3,
    );
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Andika sababu ili mbunifu ajue cha kurekebisha'),
        ),
      );
      return;
    }
    await _run(
      () => _service.reject(_d.designerId, reason),
      'Mbunifu amekataliwa',
    );
  }

  Future<void> _run(
    Future<void> Function() action,
    String successMessage,
  ) async {
    setState(() => _working = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(successMessage),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _working = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            AdminService.errorMessage(e) ?? 'Imeshindwa. Jaribu tena.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = verificationStyle(_d.verificationStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Uhakiki wa Mbunifu'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.card(radius: 18),
            child: Column(
              children: [
                UserAvatar(
                  name: _d.fullName,
                  avatarUrl: _d.avatarUrl,
                  radius: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  _d.fullName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(style.icon, size: 14, color: style.color),
                      const SizedBox(width: 4),
                      Text(
                        style.label,
                        style: TextStyle(
                          color: style.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Simu',
                  value: '+${_d.phone.replaceAll('+', '')}',
                ),
                _InfoRow(label: 'Barua pepe', value: _d.email ?? '-'),
                _InfoRow(
                  label: 'Aina ya akaunti',
                  value: accountTypeLabel(_d.accountType),
                ),
                if (_d.accountType == 'COMPANY') ...[
                  _InfoRow(label: 'Kampuni', value: _d.companyName ?? '-'),
                  _InfoRow(
                    label: 'Namba ya BRELA',
                    value: _d.companyRegNumber ?? '-',
                  ),
                ],
                if ((_d.verificationNote ?? '').isNotEmpty)
                  _InfoRow(
                    label: 'Sababu ya awali',
                    value: _d.verificationNote!,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'NYARAKA ZA UTHIBITISHO',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          if (_d.documents.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.accentDark,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text('Mbunifu huyu bado hajapakia nyaraka yoyote.'),
                  ),
                ],
              ),
            )
          else
            ..._d.documents.map((doc) {
              final docStyle = verificationStyle(doc.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: AppDecorations.card(radius: 14),
                  child: Row(
                    children: [
                      FileTypeIcon(extension: doc.extension, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              documentTypeLabel(doc.documentType),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              docStyle.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: docStyle.color,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _openingDocId == doc.id
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.accent,
                              ),
                            )
                          : TextButton.icon(
                              onPressed: () => _openDocument(doc),
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 16,
                              ),
                              label: const Text('Fungua'),
                            ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: Row(
            children: [
              if (_d.verificationStatus != 'REJECTED')
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _working ? null : _reject,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text(
                        'Kataa',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              if (_d.verificationStatus != 'REJECTED' &&
                  _d.verificationStatus != 'VERIFIED')
                const SizedBox(width: 12),
              if (_d.verificationStatus != 'VERIFIED')
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.statusCompleted,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _working ? null : _approve,
                      icon: _working
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.verified_rounded, size: 18),
                      label: const Text(
                        'Thibitisha',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
