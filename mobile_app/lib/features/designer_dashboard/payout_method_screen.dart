import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import 'payout_service.dart';

class PayoutMethodScreen extends StatefulWidget {
  final MyPayouts current;

  const PayoutMethodScreen({super.key, required this.current});

  @override
  State<PayoutMethodScreen> createState() => _PayoutMethodScreenState();
}

class _PayoutMethodScreenState extends State<PayoutMethodScreen> {
  final _service = PayoutService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final TextEditingController _accountNumberController;
  late final TextEditingController _accountNameController;

  late String _method;
  List<BankOption> _banks = [];
  String? _selectedBic;
  bool _loadingBanks = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.current;
    _method = c.payoutMethod;
    _phoneController = TextEditingController(
      text: (c.payoutPhone ?? '').replaceFirst(RegExp(r'^255'), ''),
    );
    _accountNumberController = TextEditingController(
      text: c.accountNumber ?? '',
    );
    _accountNameController = TextEditingController(text: c.accountName ?? '');
    _selectedBic = c.bankBic;
    _loadBanks();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  Future<void> _loadBanks() async {
    try {
      final banks = await _service.getBanks();
      if (!mounted) return;
      setState(() {
        _banks = banks;
        if (_selectedBic != null && !banks.any((b) => b.bic == _selectedBic))
          _selectedBic = null;
        _loadingBanks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBanks = false);
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_method == 'BANK' && _selectedBic == null) {
      setState(() => _error = 'Chagua benki');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final MyPayouts result;
      if (_method == 'BANK') {
        final bank = _banks.firstWhere((b) => b.bic == _selectedBic);
        result = await _service.setBank(
          bic: bank.bic,
          bankName: bank.name,
          accountNumber: _accountNumberController.text.trim(),
          accountName: _accountNameController.text.trim(),
        );
      } else {
        result = await _service.setMobile(_phoneController.text.trim());
      }
      if (!mounted) return;
      Navigator.pop(context, result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            PayoutService.errorMessage(e) ??
            'Imeshindwa kuhifadhi. Jaribu tena.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Njia ya Kupokea Malipo'),
        backgroundColor: AppColors.surface,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _MethodCard(
                    icon: Icons.phone_android_rounded,
                    title: 'Simu',
                    subtitle: 'M-Pesa, Mixx, Airtel…',
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
                    icon: Icons.account_balance_rounded,
                    title: 'Benki',
                    subtitle: 'Akaunti ya benki',
                    selected: _method == 'BANK',
                    onTap: () => setState(() {
                      _method = 'BANK';
                      _error = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: AppDecorations.card(radius: 16),
              child: _method == 'BANK'
                  ? _buildBankFields()
                  : _buildMobileFields(),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _method == 'BANK'
                          ? 'Malipo ya benki yanaweza kufika papo hapo au ndani ya siku 1–3 za kazi. '
                                'Hakikisha jina la akaunti linafanana kabisa na lililo benki.'
                          : 'Malipo ya simu hufika ndani ya dakika chache baada ya mteja kuthibitisha kazi.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: AppColors.surface,
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Hifadhi',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Namba ya simu'),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.phone_rounded, size: 20),
            prefixText: '+255 ',
            hintText: '712 345 678',
          ),
          validator: (v) {
            var d = (v ?? '').replaceAll(RegExp(r'\D'), '');
            if (d.startsWith('0')) d = d.substring(1);
            return d.length == 9
                ? null
                : 'Weka namba sahihi (tarakimu 9 baada ya +255)';
          },
        ),
      ],
    );
  }

  Widget _buildBankFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Label('Benki'),
        if (_loadingBanks)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          )
        else if (_banks.isEmpty)
          const Text(
            'Imeshindwa kupakia orodha ya benki. Rudi baadaye.',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedBic,
            isExpanded: true,
            hint: const Text('Chagua benki'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.account_balance_rounded, size: 20),
            ),
            items: _banks
                .map(
                  (b) => DropdownMenuItem(
                    value: b.bic,
                    child: Text(b.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              _selectedBic = v;
              _error = null;
            }),
          ),
        const SizedBox(height: 16),
        const _Label('Namba ya akaunti'),
        TextFormField(
          controller: _accountNumberController,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.numbers_rounded, size: 20),
          ),
          validator: (v) {
            final value = (v ?? '').replaceAll(RegExp(r'\s'), '');
            return RegExp(r'^[A-Za-z0-9]{5,30}$').hasMatch(value)
                ? null
                : 'Namba ya akaunti si sahihi';
          },
        ),
        const SizedBox(height: 16),
        const _Label('Jina la akaunti (kama lilivyo benki)'),
        TextFormField(
          controller: _accountNameController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.badge_rounded, size: 20),
            hintText: 'Mfano: BORA MEDIA LTD',
          ),
          validator: (v) =>
              (v ?? '').trim().length >= 3 ? null : 'Andika jina la akaunti',
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
