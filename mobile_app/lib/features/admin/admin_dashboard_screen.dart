import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/utils/verification_labels.dart';
import '../../core/widgets/user_avatar.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import 'admin_designer_screen.dart';
import 'admin_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _service = AdminService();

  AdminStats? _stats;
  List<AdminDesigner> _designers = [];
  String _status = 'PENDING';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _stats == null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _service.getStats(),
        _service.getDesigners(_status),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as AdminStats;
        _designers = results[1] as List<AdminDesigner>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            AdminService.errorMessage(e) ??
            'Imeshindwa kupakia. Angalia mtandao.';
      });
    }
  }

  void _setStatus(String status) {
    if (status == _status) return;
    setState(() => _status = status);
    _load();
  }

  Future<void> _openDesigner(AdminDesigner designer) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDesignerScreen(designer: designer),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Toka kwenye akaunti ya admin?'),
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

  @override
  Widget build(BuildContext context) {
    final stats = _stats;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Admin • DesignBora'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'Sasisha',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Toka',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Row(
              children: [
                _StatusTab(
                  label: 'Wanasubiri',
                  count: stats?.pending,
                  color: AppColors.accentDark,
                  selected: _status == 'PENDING',
                  onTap: () => _setStatus('PENDING'),
                ),
                const SizedBox(width: 8),
                _StatusTab(
                  label: 'Wamethibitishwa',
                  count: stats?.verified,
                  color: AppColors.statusCompleted,
                  selected: _status == 'VERIFIED',
                  onTap: () => _setStatus('VERIFIED'),
                ),
                const SizedBox(width: 8),
                _StatusTab(
                  label: 'Wamekataliwa',
                  count: stats?.rejected,
                  color: AppColors.statusDisputed,
                  selected: _status == 'REJECTED',
                  onTap: () => _setStatus('REJECTED'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent),
                  )
                : RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _load,
                    child: _buildList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 100),
          const Icon(
            Icons.error_outline_rounded,
            size: 48,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 12),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    if (_designers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 100),
          Icon(Icons.inbox_rounded, size: 52, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text(
            'Hakuna wabunifu hapa',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _designers.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final d = _designers[index];
        final style = verificationStyle(d.verificationStatus);
        return InkWell(
          onTap: () => _openDesigner(d),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: AppDecorations.card(radius: 16),
            child: Row(
              children: [
                UserAvatar(
                  name: d.fullName,
                  avatarUrl: d.avatarUrl,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d.fullName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${accountTypeLabel(d.accountType)} • +${d.phone.replaceAll('+', '')}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            d.documents.isEmpty
                                ? Icons.warning_amber_rounded
                                : Icons.description_rounded,
                            size: 14,
                            color: d.documents.isEmpty
                                ? AppColors.accentDark
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            d.documents.isEmpty
                                ? 'Hajapakia nyaraka'
                                : 'Nyaraka ${d.documents.length}',
                            style: TextStyle(
                              fontSize: 12,
                              color: d.documents.isEmpty
                                  ? AppColors.accentDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: style.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    style.label,
                    style: TextStyle(
                      color: style.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusTab extends StatelessWidget {
  final String label;
  final int? count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _StatusTab({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.12)
                : AppColors.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                count?.toString() ?? '-',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
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
