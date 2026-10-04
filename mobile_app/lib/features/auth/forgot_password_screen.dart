import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final ApiClient _apiClient = ApiClient();

  final _phoneController = TextEditingController(text: '+255');
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _codeRequested = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMessage = 'Weka namba sahihi ya simu');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
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
      });

      if (devCode != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('(Majaribio) Code yako ni: $devCode'),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _extractError(e);
      });
    }
  }

  Future<void> _resetPassword() async {
    if (_codeController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Weka code uliyopokea');
      return;
    }
    if (_newPasswordController.text.length < 6) {
      setState(() => _errorMessage = 'Nenosiri jipya liwe angalau herufi 6');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      await _apiClient.dio.post(
        '/auth/reset-password',
        data: {
          'phone': _phoneController.text.trim(),
          'code': _codeController.text.trim(),
          'newPassword': _newPasswordController.text,
        },
      );

      if (!mounted) return;
      setState(() => _loading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Nenosiri limebadilishwa! Sasa ingia na nenosiri jipya.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = _extractError(e);
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
    return 'Hitilafu imetokea. Jaribu tena.';
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
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: AppColors.authCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _codeRequested
                          ? 'Weka Code na Nenosiri Jipya'
                          : 'Weka Namba Yako ya Simu',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeRequested
                          ? 'Tumekutumia code kwa SMS (au angalia arifa hapo juu kwa majaribio)'
                          : 'Tutakutumia code ya kubadilisha nenosiri',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 24),

                    const Text(
                      'Namba ya Simu',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      enabled: !_codeRequested,
                      decoration: const InputDecoration(
                        hintText: '+255 712 345 678',
                      ),
                    ),

                    if (_codeRequested) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Code',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: '123456'),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Nenosiri Jipya',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _newPasswordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ],

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _loading
                          ? null
                          : (_codeRequested ? _resetPassword : _requestCode),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _codeRequested
                                  ? 'Badilisha Nenosiri'
                                  : 'Tuma Code',
                            ),
                    ),

                    if (_codeRequested) ...[
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _loading
                            ? null
                            : () => setState(() {
                                _codeRequested = false;
                                _codeController.clear();
                                _errorMessage = null;
                              }),
                        child: const Text('Badilisha namba ya simu'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
