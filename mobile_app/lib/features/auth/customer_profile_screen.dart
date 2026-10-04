import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/user_avatar.dart';
import '../../models/profile_model.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_service.dart';
import 'auth_provider.dart';
import 'login_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  final _service = ProfileService();
  ProfileModel? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _service.getMe();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
    );
    if (changed == true) _loadProfile();
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Toka kwenye akaunti?'),
        content: const Text(
          'Utahitaji kuingia tena kwa namba ya simu na nenosiri.',
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
              'Toka',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showEscrowInfo() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Malipo Salama (Escrow)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('1. Unalipa, pesa inashikiliwa na DesignBora.'),
            SizedBox(height: 6),
            Text(
              '2. Mbunifu anafanya kazi na kukutumia draft yenye watermark.',
            ),
            SizedBox(height: 6),
            Text(
              '3. Ukiridhika, unathibitisha, unapakua faili kamili, na mbunifu analipwa.',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = context.watch<AuthProvider>().user?.fullName ?? '';
    final profile = _profile;
    final name = profile?.fullName ?? fallbackName;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wasifu Wangu'),
        backgroundColor: AppColors.surface,
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadProfile,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: AppDecorations.card(radius: 18),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _openEditProfile,
                    child: UserAvatar(
                      name: name,
                      avatarUrl: profile?.avatarUrl,
                      radius: 44,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    name.isNotEmpty ? name : 'Mtumiaji',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (profile != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        profile.phone,
                        if ((profile.email ?? '').isNotEmpty) profile.email!,
                      ].join('  •  '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Mteja',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (_loading) ...[
                    const SizedBox(height: 12),
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Akaunti'),
            Container(
              decoration: AppDecorations.card(radius: 16),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.edit_rounded,
                    color: AppColors.primary,
                    title: 'Badilisha Wasifu na Picha',
                    onTap: profile == null ? null : _openEditProfile,
                  ),
                  const _TileDivider(),
                  _MenuTile(
                    icon: Icons.lock_reset_rounded,
                    color: AppColors.accent,
                    title: 'Badilisha Nenosiri',
                    onTap: _openChangePassword,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SectionLabel('Msaada'),
            Container(
              decoration: AppDecorations.card(radius: 16),
              child: Column(
                children: [
                  _MenuTile(
                    icon: Icons.verified_user_rounded,
                    color: AppColors.statusCompleted,
                    title: 'Jinsi Malipo Salama Yanavyofanya Kazi',
                    onTap: _showEscrowInfo,
                  ),
                  const _TileDivider(),
                  _MenuTile(
                    icon: Icons.info_rounded,
                    color: const Color(0xFF2563EB),
                    title: 'Kuhusu DesignBora',
                    onTap: () => showAboutDialog(
                      context: context,
                      applicationName: 'DesignBora',
                      applicationVersion: '1.0.0',
                      children: const [
                        Text(
                          'Jukwaa linalounganisha wateja na wabunifu bora wa Tanzania.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: AppDecorations.card(radius: 16),
              child: _MenuTile(
                icon: Icons.logout_rounded,
                color: Colors.red,
                title: 'Toka',
                titleColor: Colors.red,
                showArrow: false,
                onTap: _handleLogout,
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'DesignBora v1.0.0',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
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

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 64, color: AppColors.border);
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Color? titleColor;
  final bool showArrow;
  final VoidCallback? onTap;

  const _MenuTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.onTap,
    this.titleColor,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: titleColor,
                ),
              ),
            ),
            if (showArrow)
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
          ],
        ),
      ),
    );
  }
}
