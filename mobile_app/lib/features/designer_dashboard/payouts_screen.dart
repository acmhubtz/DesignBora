import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import 'payout_method_screen.dart';
import 'payout_service.dart';

String _formatTsh(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'TSh $buffer';
}

String _formatPhone(String? phone) {
  if (phone == null || phone.length != 12) return phone ?? '';
  return '+${phone.substring(0, 3)} ${phone.substring(3, 6)} ${phone.substring(6, 9)} ${phone.substring(9)}';
}

class PayoutsScreen extends StatefulWidget {
  const PayoutsScreen({super.key});

  @override
  State<PayoutsScreen> createState() => _PayoutsScreenState();
}

class _PayoutsScreenState extends State<PayoutsScreen> {
  final _service = PayoutService();
  MyPayouts? _data;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _failed = false;
    });
    try {
      final data = await _service.getMine();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = _data == null;
      });
    }
  }

  Future<void> _editMethod() async {
    final current = _data;
    if (current == null) return;
    final updated = await Navigator.push<MyPayouts>(
      context,
      MaterialPageRoute(builder: (_) => PayoutMethodScreen(current: current)),
    );
    if (updated == null || !mounted) return;
    setState(() => _data = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Njia ya kupokea malipo imehifadhiwa'),
        backgroundColor: AppColors.statusCompleted,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Malipo Yangu'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _failed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text('Imeshindwa kupakia malipo'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Jaribu tena'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: AppColors.accent,
              onRefresh: _load,
              child: _buildContent(_data!),
            ),
    );
  }

  Widget _buildContent(MyPayouts data) {
    final String title;
    final String subtitle;
    if (!data.ready) {
      title = 'Weka njia ya kupokea malipo';
      subtitle = 'Malipo yako yanasubiri taarifa hii';
    } else if (data.isBank) {
      title = data.bankName ?? 'Benki';
      subtitle = '${data.accountNumber} • ${data.accountName}';
    } else {
      title = 'Simu';
      subtitle = _formatPhone(data.payoutPhone);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: _editMethod,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: data.ready
                ? AppDecorations.card(radius: 16)
                : BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.accent.withValues(alpha: 0.4),
                    ),
                  ),
            child: Row(
              children: [
                Icon(
                  !data.ready
                      ? Icons.warning_amber_rounded
                      : data.isBank
                      ? Icons.account_balance_rounded
                      : Icons.phone_android_rounded,
                  color: data.ready ? AppColors.primary : AppColors.accentDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  data.ready ? 'Badilisha' : 'Weka',
                  style: const TextStyle(
                    color: AppColors.accentDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'Umelipwa',
                value: _formatTsh(data.totalPaid),
                color: AppColors.statusCompleted,
                icon: Icons.account_balance_wallet_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                label: 'Zinasubiri',
                value: _formatTsh(data.pendingAmount),
                color: AppColors.accentDark,
                icon: Icons.schedule_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const Text(
          'HISTORIA YA MALIPO',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 10),
        if (data.payouts.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppDecorations.card(radius: 16),
            child: const Text(
              'Bado hakuna malipo. Mteja akithibitisha kazi yako, malipo yataonekana hapa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          )
        else
          ...data.payouts.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _PayoutTile(payout: p),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PayoutTile extends StatelessWidget {
  final PayoutItem payout;
  const _PayoutTile({required this.payout});

  ({String label, Color color, IconData icon}) get _style {
    switch (payout.status) {
      case 'PROCESSED':
        return (
          label: 'Imelipwa',
          color: AppColors.statusCompleted,
          icon: Icons.check_circle_rounded,
        );
      case 'PROCESSING':
        return (
          label: 'Inatumwa',
          color: AppColors.statusInProgress,
          icon: Icons.sync_rounded,
        );
      case 'FAILED':
        return (
          label: 'Imeshindwa',
          color: AppColors.statusDisputed,
          icon: Icons.error_rounded,
        );
      default:
        return (
          label: 'Inasubiri',
          color: AppColors.accentDark,
          icon: Icons.schedule_rounded,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(radius: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(style.icon, color: style.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Oda #${payout.orderId}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  style.label,
                  style: TextStyle(
                    fontSize: 12,
                    color: style.color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((payout.destination ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        payout.channel == 'BANK'
                            ? Icons.account_balance_rounded
                            : Icons.phone_android_rounded,
                        size: 12,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          payout.destination!,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if ((payout.failureReason ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    payout.failureReason!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            _formatTsh(payout.amount),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
