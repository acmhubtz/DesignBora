import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../designer_dashboard/designer_dashboard_screen.dart';
import '../navigation/main_navigation_screen.dart';
import 'auth_provider.dart';

enum _RegisterStep { chooseRole, chooseAccountType, fillForm }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  _RegisterStep _step = _RegisterStep.chooseRole;
  String? _selectedRole;
  String? _selectedAccountType;

  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController(text: '+255');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _companyNameController = TextEditingController();
  final _companyRegController = TextEditingController();
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  String? _formError;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _companyNameController.dispose();
    _companyRegController.dispose();
    super.dispose();
  }

  // ---------- Mantiki ya hatua ----------

  int get _totalSteps => _selectedRole == 'CUSTOMER' ? 2 : 3;

  int get _currentStepNumber {
    switch (_step) {
      case _RegisterStep.chooseRole:
        return 1;
      case _RegisterStep.chooseAccountType:
        return 2;
      case _RegisterStep.fillForm:
        return _totalSteps;
    }
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _formError = null;
      if (role == 'CUSTOMER') {
        _selectedAccountType = null;
        _step = _RegisterStep.fillForm;
      } else {
        _step = _RegisterStep.chooseAccountType;
      }
    });
  }

  void _selectAccountType(String type) {
    setState(() {
      _selectedAccountType = type;
      _formError = null;
      _step = _RegisterStep.fillForm;
    });
  }

  void _goBack() {
    setState(() {
      _formError = null;
      if (_step == _RegisterStep.fillForm && _selectedRole == 'DESIGNER') {
        _step = _RegisterStep.chooseAccountType;
      } else {
        _step = _RegisterStep.chooseRole;
      }
    });
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    setState(() => _formError = null);

    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      setState(
        () => _formError = 'Tafadhali kubali Vigezo na Masharti ili kuendelea',
      );
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      fullName: _fullNameController.text.trim(),
      phone: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      password: _passwordController.text,
      role: _selectedRole!,
      accountType: _selectedAccountType,
      companyName: _selectedAccountType == 'COMPANY'
          ? _companyNameController.text.trim()
          : null,
      companyRegNumber: _selectedAccountType == 'COMPANY'
          ? _companyRegController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (success) {
      final role = authProvider.user?.role;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'DESIGNER'
              ? const DesignerDashboardScreen()
              : const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } else {
      setState(
        () => _formError = authProvider.errorMessage ?? 'Usajili umeshindikana',
      );
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _step == _RegisterStep.chooseRole,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: AppColors.authBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _step != _RegisterStep.chooseRole
                ? _goBack
                : () => Navigator.pop(context),
          ),
          title: const Text(
            'DesignBora',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  children: [
                    _StepIndicator(
                      current: _currentStepNumber,
                      total: _totalSteps,
                    ),
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
                          key: ValueKey(_step),
                          child: _buildStepContent(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case _RegisterStep.chooseRole:
        return _buildChooseRoleStep();
      case _RegisterStep.chooseAccountType:
        return _buildChooseAccountTypeStep();
      case _RegisterStep.fillForm:
        return _buildFormStep();
    }
  }

  Widget _buildChooseRoleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Anza Sasa',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Chagua jinsi utakavyotumia DesignBora',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _ChoiceCard(
          icon: Icons.search_rounded,
          color: AppColors.primary,
          title: 'Natafuta Huduma',
          subtitle: 'Mimi ni mteja, nataka kuajiri wabunifu',
          onTap: () => _selectRole('CUSTOMER'),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.brush_rounded,
          color: AppColors.accent,
          title: 'Natoa Huduma',
          subtitle: 'Mimi ni mbunifu, nataka kupata wateja',
          onTap: () => _selectRole('DESIGNER'),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Una akaunti tayari? ',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text(
                'Ingia',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChooseAccountTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Aina ya Akaunti',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Unajisajili kama mtu binafsi au kampuni?',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _ChoiceCard(
          icon: Icons.person_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'Mtu Binafsi',
          subtitle: 'Nafanya kazi peke yangu kama freelancer',
          onTap: () => _selectAccountType('INDIVIDUAL'),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.apartment_rounded,
          color: const Color(0xFF059669),
          title: 'Kampuni',
          subtitle: 'Ninawakilisha studio au kampuni ya ubunifu',
          onTap: () => _selectAccountType('COMPANY'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_rounded, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Baada ya usajili utahitaji kupakia hati za uthibitisho (kitambulisho au leseni ya biashara).',
                  style: TextStyle(fontSize: 12, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFormStep() {
    final subtitle = _selectedRole == 'CUSTOMER'
        ? 'Mteja'
        : _selectedAccountType == 'COMPANY'
        ? 'Mbunifu • Kampuni'
        : 'Mbunifu • Mtu Binafsi';

    return Form(
      key: _formKey,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Fungua Akaunti',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentDark,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 22),

            const _FieldLabel('Jina Kamili'),
            TextFormField(
              controller: _fullNameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(
                hintText: 'Neema Mrosso',
                prefixIcon: Icon(Icons.person_rounded, size: 20),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Jina linahitajika' : null,
            ),
            const SizedBox(height: 16),

            if (_selectedAccountType == 'COMPANY') ...[
              const _FieldLabel('Jina la Kampuni'),
              TextFormField(
                controller: _companyNameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Bora Media Ltd',
                  prefixIcon: Icon(Icons.apartment_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Jina la kampuni linahitajika'
                    : null,
              ),
              const SizedBox(height: 16),
              const _FieldLabel('Namba ya Usajili (BRELA)'),
              TextFormField(
                controller: _companyRegController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'BRELA-2024-1234',
                  prefixIcon: Icon(Icons.badge_rounded, size: 20),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Namba ya usajili inahitajika'
                    : null,
              ),
              const SizedBox(height: 16),
            ],

            const _FieldLabel('Namba ya Simu'),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(
                hintText: '+255 712 345 678',
                prefixIcon: Icon(Icons.phone_rounded, size: 20),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 10) {
                  return 'Weka namba sahihi ya simu';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Barua Pepe (hiari)'),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(
                hintText: 'neema@gmail.com',
                prefixIcon: Icon(Icons.email_rounded, size: 20),
              ),
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isNotEmpty && !value.contains('@')) {
                  return 'Barua pepe si sahihi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            const _FieldLabel('Nenosiri'),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _handleSubmit(),
              decoration: InputDecoration(
                hintText: 'Angalau herufi 6',
                prefixIcon: const Icon(Icons.lock_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.length < 6) {
                  return 'Nenosiri liwe angalau herufi 6';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() {
                _agreedToTerms = !_agreedToTerms;
                if (_agreedToTerms) _formError = null;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreedToTerms,
                      activeColor: AppColors.accent,
                      onChanged: (v) => setState(() {
                        _agreedToTerms = v ?? false;
                        if (_agreedToTerms) _formError = null;
                      }),
                    ),
                    const Expanded(
                      child: Text(
                        'Nakubali Vigezo na Masharti ya DesignBora',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_formError != null) ...[
              const SizedBox(height: 12),
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
                        _formError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            Consumer<AuthProvider>(
              builder: (context, authProvider, _) {
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
                    onPressed: authProvider.isLoading ? null : _handleSubmit,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Fungua Akaunti',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(total, (i) {
            final active = i < current;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                margin: EdgeInsets.only(right: i == total - 1 ? 0 : 6),
                decoration: BoxDecoration(
                  color: active ? AppColors.accent : Colors.white24,
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
            'Hatua $current kati ya $total',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

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
