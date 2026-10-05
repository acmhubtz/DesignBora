import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  static const _resendSeconds = 60;

  final ApiClient _apiClient = ApiClient();
  final _phoneController = TextEditingController(text: '+255');
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _codeRequested = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  int _secondsLeft = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Weka namba sahihi ya simu');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _apiClient.dio.post(
        '/auth/forgot-password',
        data: {'phone': phone},
      );
      if (!mounted) return;

      final devCode = response.data['data']?['devCode'];
      setState(() {
        _codeRequested = true;
        _loading = false;
        _codeController.clear();
      });
      _startCountdown();

      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('(Majaribio) Code yako ni: $devCode'),
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _extractError(e);
      });
    }
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (_codeController.text.trim().length != 6) {
      setState(() => _error = 'Weka code ya tarakimu 6 uliyopokea');
      return;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _error = 'Nenosiri jipya liwe angalau herufi 6');
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Manenosiri hayafanani');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _apiClient.dio.post(
        '/auth/reset-password',
        data: {
          'phone': _phoneController.text.trim(),
          'code': _codeController.text.trim(),
          'newPassword': _passwordController.text,
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenosiri limebadilishwa! Sasa ingia kwa nenosiri jipya.',
          ),
          backgroundColor: AppColors.statusCompleted,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _extractError(e);
      });
    }
  }

  String _extractError(Object e) {
    try {
      final data = (e as dynamic).response?.data;
      if (data != null && data['message'] != null) {
        return data['message'].toString();
      }
    } catch (_) {}
    return 'Hitilafu imetokea. Angalia mtandao na ujaribu tena.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'Umesahau Nenosiri?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  _StepIndicator(step: _codeRequested ? 2 : 1),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: AppColors.authCard,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: KeyedSubtree(
                        key: ValueKey(_codeRequested),
                        child: _codeRequested
                            ? _buildResetStep()
                            : _buildPhoneStep(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.lock_reset_rounded,
            color: AppColors.accent,
            size: 28,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Badilisha nenosiri',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Weka namba ya simu uliyosajilia. Tutakutumia code ya tarakimu 6.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 22),
        const _Label('Namba ya Simu'),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          enabled: !_loading,
          onSubmitted: (_) => _requestCode(),
          decoration: const InputDecoration(
            hintText: '+255 712 345 678',
            prefixIcon: Icon(Icons.phone_rounded, size: 20),
          ),
        ),
        _buildError(),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Tuma Code',
          loading: _loading,
          onPressed: _requestCode,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text(
            'Rudi kwenye kuingia',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildResetStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Weka code na nenosiri jipya',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Tumetuma code kwenda ${_phoneController.text.trim()}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _codeController,
          enabled: !_loading,
          autofocus: true,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: 10,
          ),
          decoration: const InputDecoration(
            hintText: '000000',
            counterText: '',
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.center,
          child: _secondsLeft > 0
              ? Text(
                  'Tuma code tena baada ya sekunde $_secondsLeft',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                )
              : TextButton(
                  onPressed: _loading ? null : _requestCode,
                  child: const Text(
                    'Tuma code tena',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const _Label('Nenosiri Jipya'),
        TextField(
          controller: _passwordController,
          enabled: !_loading,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: 'Angalau herufi 6',
            prefixIcon: const Icon(Icons.lock_rounded, size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                _obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _Label('Rudia Nenosiri Jipya'),
        TextField(
          controller: _confirmController,
          enabled: !_loading,
          obscureText: _obscure,
          onSubmitted: (_) => _resetPassword(),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.lock_outline_rounded, size: 20),
          ),
        ),
        _buildError(),
        const SizedBox(height: 20),
        _PrimaryButton(
          label: 'Badilisha Nenosiri',
          loading: _loading,
          onPressed: _resetPassword,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _loading
              ? null
              : () {
                  _timer?.cancel();
                  setState(() {
                    _codeRequested = false;
                    _secondsLeft = 0;
                    _error = null;
                    _codeController.clear();
                  });
                },
          child: const Text(
            'Badilisha namba ya simu',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    if (_error == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
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
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(2, (i) {
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: EdgeInsets.only(right: i == 0 ? 6 : 0),
                decoration: BoxDecoration(
                  color: i < step ? AppColors.accent : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            step == 1
                ? 'Hatua 1 kati ya 2 • Namba ya simu'
                : 'Hatua 2 kati ya 2 • Code na nenosiri jipya',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: loading ? null : onPressed,
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
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
