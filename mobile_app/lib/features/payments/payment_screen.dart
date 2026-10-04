import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/server_image.dart';
import '../orders/draft_widgets.dart';
import '../orders/order_chat_screen.dart';
import 'payment_service.dart';

String _formatTsh(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'TSh $buffer';
}

class MobileNetwork {
  final String code;
  final String name;
  final Color color;
  final List<String> prefixes; // tarakimu 2 za mwanzo baada ya 0 / 255

  const MobileNetwork(this.code, this.name, this.color, this.prefixes);
}

const mobileNetworks = [
  MobileNetwork('MPESA', 'M-Pesa', Color(0xFFE60000), ['74', '75', '76']),
  MobileNetwork('MIXX', 'Mixx by Yas', Color(0xFF1D4ED8), [
    '65',
    '67',
    '71',
    '77',
  ]),
  MobileNetwork('AIRTEL', 'Airtel Money', Color(0xFFDC2626), [
    '68',
    '69',
    '78',
  ]),
  MobileNetwork('HALOPESA', 'HaloPesa', Color(0xFFF97316), ['61', '62']),
  MobileNetwork('TPESA', 'T-Pesa', Color(0xFF0EA5E9), ['73']),
];

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final double amount;
  final String serviceTitle;
  final String designerName;

  const PaymentScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.serviceTitle,
    required this.designerName,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentService _service = PaymentService();
  final _phoneController = TextEditingController();

  String _method = 'MOBILE';
  MobileNetwork? _network;
  bool _networkChosenManually = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  /// Tarakimu 9 baada ya +255
  String get _digits {
    var d = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('255')) d = d.substring(3);
    if (d.startsWith('0')) d = d.substring(1);
    return d;
  }

  bool get _phoneValid => _digits.length == 9;

  void _onPhoneChanged(String _) {
    setState(() {
      _error = null;
      if (!_networkChosenManually && _digits.length >= 2) {
        final prefix = _digits.substring(0, 2);
        for (final n in mobileNetworks) {
          if (n.prefixes.contains(prefix)) _network = n;
        }
      }
    });
  }

  Future<void> _pay() async {
    FocusScope.of(context).unfocus();

    if (_method == 'MOBILE') {
      if (_network == null) {
        setState(() => _error = 'Chagua mtandao wako wa simu');
        return;
      }
      if (!_phoneValid) {
        setState(
          () => _error = 'Weka namba sahihi ya simu (tarakimu 9 baada ya +255)',
        );
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final payment = await _service.initiate(
        orderId: widget.orderId,
        method: _method,
        provider: _method == 'MOBILE' ? _network!.code : null,
        phone: _method == 'MOBILE' ? '255$_digits' : null,
      );
      if (!mounted) return;
      setState(() => _submitting = false);

      String? checkoutUrl;
      if (_method == 'CARD') {
        checkoutUrl = ServerImage.fullUrl(payment.checkoutUrl);
        if (checkoutUrl != null) await openExternalUrl(context, checkoutUrl);
        if (!mounted) return;
      }

      final success = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PaymentWaitingDialog(
          paymentId: payment.id,
          service: _service,
          network: _method == 'MOBILE' ? _network : null,
          phone: '+255 $_digits',
          checkoutUrl: checkoutUrl,
        ),
      );
      if (success == true && mounted) _onPaid();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error =
            _extractError(e) ?? 'Imeshindwa kuanzisha malipo. Jaribu tena.';
      });
    }
  }

  void _onPaid() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Malipo yamekamilika! Mbunifu ameanza kazi yako.'),
        backgroundColor: AppColors.statusCompleted,
      ),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: widget.orderId,
          designerName: widget.designerName,
          serviceTitle: widget.serviceTitle,
        ),
      ),
    );
  }

  String? _extractError(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return null;
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Malipo'),
        backgroundColor: AppColors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummary(),
          const SizedBox(height: 20),
          const _Label('NJIA YA MALIPO'),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.phone_android_rounded,
                  title: 'Simu',
                  subtitle: 'Mitandao yote',
                  selected: _method == 'MOBILE',
                  onTap: () => setState(() {
                    _method = 'MOBILE';
                    _error = null;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MethodCard(
                  icon: Icons.credit_card_rounded,
                  title: 'Kadi',
                  subtitle: 'Visa / Mastercard',
                  selected: _method == 'CARD',
                  onTap: () => setState(() {
                    _method = 'CARD';
                    _error = null;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (_method == 'MOBILE')
            _buildMobileSection()
          else
            _buildCardSection(),
          if (_error != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                size: 16,
                color: AppColors.statusCompleted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Pesa yako inashikiliwa salama (Escrow) hadi uridhike na kazi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.statusCompleted.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: _buildPayBar(),
    );
  }

  Widget _buildSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.serviceTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Oda #${widget.orderId} • ${widget.designerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatTsh(widget.amount),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.accentDark,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('NAMBA YA SIMU'),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            onChanged: _onPhoneChanged,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.phone_rounded, size: 20),
              prefixText: '+255 ',
              hintText: '712 345 678',
            ),
          ),
          const SizedBox(height: 16),
          const _Label('MTANDAO'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mobileNetworks.map((n) {
              return _NetworkChip(
                network: n,
                selected: _network?.code == n.code,
                onTap: () => setState(() {
                  _network = n;
                  _networkChosenManually = true;
                  _error = null;
                }),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_rounded, size: 18, color: AppColors.primary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Utapokea ujumbe wa mtandao wako kwenye simu. Weka namba yako ya siri hapo. '
                    'DesignBora haitakuuliza namba yako ya siri kamwe.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(radius: 16),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Malipo salama ya kadi',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Utapelekwa kwenye ukurasa salama wa mtoa huduma wa malipo kuweka taarifa za '
                  'kadi yako (Visa au Mastercard). Taarifa za kadi haziingii kwenye DesignBora.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Jumla',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    _formatTsh(widget.amount),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.accentDark,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _submitting ? null : _pay,
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.lock_rounded, size: 18),
                label: const Text(
                  'Lipa Sasa',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =================== Pop-up ya kusubiri uthibitisho ===================

class _PaymentWaitingDialog extends StatefulWidget {
  final int paymentId;
  final PaymentService service;
  final MobileNetwork? network; // null = kadi
  final String phone;
  final String? checkoutUrl;

  const _PaymentWaitingDialog({
    required this.paymentId,
    required this.service,
    required this.network,
    required this.phone,
    required this.checkoutUrl,
  });

  @override
  State<_PaymentWaitingDialog> createState() => _PaymentWaitingDialogState();
}

class _PaymentWaitingDialogState extends State<_PaymentWaitingDialog> {
  static const _timeoutSeconds = 120;

  Timer? _pollTimer;
  Timer? _tickTimer;
  int _secondsLeft = _timeoutSeconds;
  String _state = 'PENDING'; // PENDING | FAILED | TIMEOUT
  String? _message;
  bool _checking = false;

  bool get _isCard => widget.network == null;
  Color get _color => widget.network?.color ?? AppColors.primary;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _stopTimers();
        setState(() {
          _state = 'TIMEOUT';
          _message =
              'Muda umeisha bila uthibitisho. Kama pesa imekatwa, oda itaonekana '
              'kuwa imelipwa kwenye "Oda Zangu" baada ya muda mfupi.';
        });
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
  }

  Future<void> _check() async {
    if (_checking || _state != 'PENDING') return;
    _checking = true;
    try {
      final payment = await widget.service.getPayment(widget.paymentId);
      if (!mounted) return;
      if (payment.isSuccess) {
        _stopTimers();
        Navigator.pop(context, true);
      } else if (payment.isFailed) {
        _stopTimers();
        setState(() {
          _state = 'FAILED';
          _message = payment.failureReason ?? 'Malipo hayakufanikiwa.';
        });
      }
    } catch (_) {
      // Tatizo la mtandao la muda - tutajaribu tena baada ya sekunde 3
    } finally {
      _checking = false;
    }
  }

  String get _timeLabel {
    final m = _secondsLeft ~/ 60;
    final s = (_secondsLeft % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        content: _state == 'PENDING' ? _buildPending() : _buildFinished(),
        actions: _state == 'PENDING'
            ? [
                if (widget.checkoutUrl != null)
                  TextButton(
                    onPressed: () =>
                        openExternalUrl(context, widget.checkoutUrl!),
                    child: const Text('Fungua ukurasa tena'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Ghairi',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ]
            : [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Sawa',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
      ),
    );
  }

  Widget _buildPending() {
    final steps = _isCard
        ? [
            'Ukurasa salama wa malipo umefunguka',
            'Weka taarifa za kadi yako hapo',
            'Rudi hapa - tutathibitisha moja kwa moja',
          ]
        : [
            'Utapokea ujumbe wa ${widget.network!.name} kwenye ${widget.phone}',
            'Weka namba yako ya siri kwenye ujumbe huo',
            'Subiri hapa - tutathibitisha moja kwa moja',
          ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(strokeWidth: 3, color: _color),
              ),
              Icon(
                _isCard
                    ? Icons.credit_card_rounded
                    : Icons.phonelink_ring_rounded,
                size: 34,
                color: _color,
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _isCard ? 'Kamilisha malipo ya kadi' : 'Angalia simu yako',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        ...steps.asMap().entries.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${entry.key + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    style: const TextStyle(fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Muda uliobaki: $_timeLabel',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildFinished() {
    final isTimeout = _state == 'TIMEOUT';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isTimeout ? Icons.timer_off_rounded : Icons.cancel_rounded,
          size: 64,
          color: isTimeout ? AppColors.accentDark : AppColors.statusDisputed,
        ),
        const SizedBox(height: 14),
        Text(
          isTimeout ? 'Muda umeisha' : 'Malipo hayakufanikiwa',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          _message ?? '',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// =================== Widgets ndogo ===================

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 2),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.accent : AppColors.textSecondary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.accent,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  final MobileNetwork network;
  final bool selected;
  final VoidCallback onTap;

  const _NetworkChip({
    required this.network,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
        decoration: BoxDecoration(
          color: selected
              ? network.color.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? network.color : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: network.color,
              child: Text(
                network.name[0],
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              network.name,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: selected ? network.color : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
