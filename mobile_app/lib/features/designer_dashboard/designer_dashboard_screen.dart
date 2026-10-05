import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/server_image.dart';
import '../../models/designer_me_model.dart';
import '../../models/order_model.dart';
import '../../models/portfolio_model.dart';
import '../../models/service_model.dart';
import '../auth/auth_provider.dart';
import '../auth/login_screen.dart';
import '../orders/order_chat_screen.dart';
import '../profile/change_password_screen.dart';
import '../profile/edit_profile_screen.dart';
import '../profile/profile_service.dart';
import 'add_portfolio_screen.dart';
import 'payouts_screen.dart';
import 'verification_screen.dart';
import 'add_service_screen.dart';
import 'designer_dashboard_service.dart';

const double _maxContentWidth = 720;

String _formatTsh(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'TSh $buffer';
}

/// Padding ya pembeni inayoweka maudhui katikati kwenye skrini pana (web)
EdgeInsets _pagePadding(
  BuildContext context, {
  double top = 16,
  double bottom = 16,
}) {
  final width = MediaQuery.of(context).size.width;
  final side = width > _maxContentWidth + 32
      ? (width - _maxContentWidth) / 2
      : 16.0;
  return EdgeInsets.fromLTRB(side, top, side, bottom);
}

bool _needsAction(OrderModel o) =>
    o.status == 'PAID' || o.status == 'IN_PROGRESS' || o.status == 'DISPUTED';
bool _waitingCustomer(OrderModel o) => o.status == 'DRAFT_SUBMITTED';
bool _isCompleted(OrderModel o) => o.status == 'COMPLETED';

enum _OrderFilter { all, action, waiting, done }

class DesignerDashboardScreen extends StatefulWidget {
  const DesignerDashboardScreen({super.key});

  @override
  State<DesignerDashboardScreen> createState() =>
      _DesignerDashboardScreenState();
}

class _DesignerDashboardScreenState extends State<DesignerDashboardScreen> {
  static const _titles = [
    'Muhtasari',
    'Oda Zangu',
    'Huduma Zangu',
    'Kazi Zangu',
  ];

  final DesignerDashboardService _service = DesignerDashboardService();

  DesignerMeModel? _profile;
  List<OrderModel> _orders = [];
  List<ServiceModel> _services = [];
  List<PortfolioModel> _portfolio = [];
  bool _loading = true;
  bool _loadFailed = false;
  int _tab = 0;
  _OrderFilter _orderFilter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  // ---------- Data ----------

  Future<void> _loadAll() async {
    setState(() {
      _loading = _profile == null;
      _loadFailed = false;
    });
    try {
      final profile = await _service.getMyProfile();
      final results = await Future.wait([
        _service.getMyOrders(),
        _service.getMyServices(profile.designerId),
        _service.getMyPortfolio(profile.designerId),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _orders = (results[0] as List<OrderModel>)
          ..sort((a, b) => b.id.compareTo(a.id));
        _services = results[1] as List<ServiceModel>;
        _portfolio = results[2] as List<PortfolioModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = _profile == null;
      });
      if (_profile != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imeshindwa kusasisha. Angalia mtandao wako.'),
          ),
        );
      }
    }
  }

  int get _actionCount => _orders.where(_needsAction).length;
  int get _waitingCount => _orders.where(_waitingCustomer).length;
  int get _doneCount => _orders.where(_isCompleted).length;

  double get _earnings =>
      _orders.where(_isCompleted).fold(0.0, (sum, o) => sum + o.netAmount);

  /// Pesa ya oda ambazo bado hazijakamilika (imeshikiliwa na Escrow)
  double get _escrow => _orders
      .where((o) => !_isCompleted(o))
      .fold(0.0, (sum, o) => sum + o.netAmount);

  List<OrderModel> get _filteredOrders {
    switch (_orderFilter) {
      case _OrderFilter.action:
        return _orders.where(_needsAction).toList();
      case _OrderFilter.waiting:
        return _orders.where(_waitingCustomer).toList();
      case _OrderFilter.done:
        return _orders.where(_isCompleted).toList();
      case _OrderFilter.all:
        return _orders;
    }
  }

  // ---------- Vitendo ----------

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

  Future<void> _goToAddService() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddServiceScreen()),
    );
    if (result == true) _loadAll();
  }

  Future<void> _goToAddPortfolio() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddPortfolioScreen()),
    );
    if (result == true) _loadAll();
  }

  Future<void> _openOrderChat(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: order.id,
          // Kwa upande wa mbunifu, "mtu wa upande mwingine" ni mteja
          designerName: order.customerName ?? 'Mteja',
          serviceTitle: order.serviceTitle ?? 'Oda #${order.id}',
        ),
      ),
    );
    _loadAll();
  }

  Future<void> _openEditProfile() async {
    try {
      final profile = await ProfileService().getMe();
      if (!mounted) return;
      final changed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)),
      );
      if (changed == true) _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Imeshindwa kufungua wasifu')),
      );
    }
  }

  Future<void> _openVerification() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
    );
    _loadAll();
  }

  void _openPayouts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PayoutsScreen()),
    );
  }

  void _openChangePassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _showOrders(_OrderFilter filter) {
    setState(() {
      _tab = 1;
      _orderFilter = filter;
    });
  }

  Future<void> _deletePortfolioItem(
    PortfolioModel item,
    BuildContext dialogContext,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: dialogContext,
      builder: (confirmContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Kufuta kazi hii?'),
        content: Text(
          '"${item.title}" itaondolewa kwenye portfolio yako. Wateja hawataiona tena.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, false),
            child: const Text(
              'Ghairi',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(confirmContext, true),
            child: const Text(
              'Futa',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !dialogContext.mounted) return;

    Navigator.pop(dialogContext);
    try {
      await _service.deletePortfolioItem(item.id);
      messenger.showSnackBar(const SnackBar(content: Text('Kazi imefutwa')));
      _loadAll();
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Imeshindwa kufuta kazi. Jaribu tena.')),
      );
    }
  }

  void _showPortfolioItem(PortfolioModel item) {
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: ServerImage(url: item.thumbnailUrl, fit: BoxFit.contain),
              ),
            ),
            Container(
              width: double.infinity,
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (item.description != null &&
                            item.description!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            item.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Futa kazi',
                    onPressed: () => _deletePortfolioItem(item, dialogContext),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- UI kuu ----------

  @override
  Widget build(BuildContext context) {
    final ready = !_loading && !_loadFailed && _profile != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: ready && _tab != 0
          ? AppBar(
              title: Text(_titles[_tab]),
              backgroundColor: AppColors.surface,
              automaticallyImplyLeading: false,
            )
          : null,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : !ready
          ? _buildLoadError()
          : _buildTab(),
      floatingActionButton: ready ? _buildFab() : null,
      bottomNavigationBar: ready ? _buildNavigationBar() : null,
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 1:
        return _buildOrdersTab();
      case 2:
        return _buildServicesTab();
      case 3:
        return _buildPortfolioTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildNavigationBar() {
    final actionCount = _actionCount;
    return NavigationBar(
      selectedIndex: _tab,
      backgroundColor: AppColors.surface,
      indicatorColor: AppColors.accent.withValues(alpha: 0.15),
      onDestinationSelected: (index) => setState(() => _tab = index),
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(
            Icons.dashboard_rounded,
            color: AppColors.accentDark,
          ),
          label: 'Muhtasari',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: actionCount > 0,
            label: Text('$actionCount'),
            child: const Icon(Icons.receipt_long_outlined),
          ),
          selectedIcon: Badge(
            isLabelVisible: actionCount > 0,
            label: Text('$actionCount'),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.accentDark,
            ),
          ),
          label: 'Oda',
        ),
        const NavigationDestination(
          icon: Icon(Icons.design_services_outlined),
          selectedIcon: Icon(
            Icons.design_services_rounded,
            color: AppColors.accentDark,
          ),
          label: 'Huduma',
        ),
        const NavigationDestination(
          icon: Icon(Icons.photo_library_outlined),
          selectedIcon: Icon(
            Icons.photo_library_rounded,
            color: AppColors.accentDark,
          ),
          label: 'Kazi',
        ),
      ],
    );
  }

  Widget? _buildFab() {
    if (_tab != 2 && _tab != 3) return null;
    final isServices = _tab == 2;
    return FloatingActionButton.extended(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      onPressed: isServices ? _goToAddService : _goToAddPortfolio,
      icon: const Icon(Icons.add_rounded),
      label: Text(
        isServices ? 'Ongeza Huduma' : 'Ongeza Kazi',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 52,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            const Text(
              'Imeshindwa kupakia dashibodi',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Angalia mtandao wako kisha ujaribu tena',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _loadAll,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Jaribu tena'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: _handleLogout, child: const Text('Toka')),
          ],
        ),
      ),
    );
  }

  // ---------- Muhtasari ----------

  Widget _buildOverviewTab() {
    final profile = _profile!;
    final actionOrders = _orders.where(_needsAction).take(3).toList();

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildOverviewHeader(profile),
          Padding(
            padding: _pagePadding(context, top: 20, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildStatsGrid(profile),
                const SizedBox(height: 20),
                _buildQuickActions(),
                if (_buildTip() case final tip?) ...[
                  const SizedBox(height: 20),
                  tip,
                ],
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Zinahitaji Hatua Yako',
                  actionLabel: _actionCount > 0
                      ? 'Ona zote ($_actionCount)'
                      : null,
                  onAction: () => _showOrders(_OrderFilter.action),
                ),
                const SizedBox(height: 12),
                if (actionOrders.isEmpty)
                  const _AllClearCard()
                else
                  ...actionOrders.map(
                    (order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DesignerOrderCard(
                        order: order,
                        onTap: () => _openOrderChat(order),
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

  Widget _buildOverviewHeader(DesignerMeModel profile) {
    final topInset = MediaQuery.of(context).padding.top;
    final name = profile.displayName.trim();
    final firstName = name.isEmpty ? 'Mbunifu' : name.split(' ').first;
    final side = _pagePadding(context).left + 4;

    return Container(
      decoration: AppDecorations.primaryGradientBox,
      padding: EdgeInsets.fromLTRB(side, topInset + 16, side, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Colors.white,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habari, $firstName 👋',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (profile.verified)
                      const Row(
                        children: [
                          Icon(
                            Icons.verified_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Mbunifu Aliyethibitishwa',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Inasubiri Uhakiki',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Menyu',
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _openEditProfile();
                    case 'password':
                      _openChangePassword();
                    case 'payouts':
                      _openPayouts();
                    case 'verification':
                      _openVerification();
                    case 'logout':
                      _handleLogout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_rounded),
                      title: Text('Badilisha Wasifu'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'password',
                    child: ListTile(
                      leading: Icon(Icons.lock_reset_rounded),
                      title: Text('Badilisha Nenosiri'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'verification',
                    child: ListTile(
                      leading: Icon(Icons.verified_user_rounded),
                      title: Text('Uhakiki wa Akaunti'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'payouts',
                    child: ListTile(
                      leading: Icon(Icons.account_balance_wallet_rounded),
                      title: Text('Malipo Yangu'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout_rounded, color: Colors.red),
                      title: Text('Toka', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mapato Yako',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatTsh(_earnings),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _HeaderMini(
                        icon: Icons.lock_clock_rounded,
                        label: 'Kwenye Escrow',
                        value: _formatTsh(_escrow),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HeaderMini(
                        icon: Icons.task_alt_rounded,
                        label: 'Zilizokamilika',
                        value: '${profile.completedOrders}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(DesignerMeModel profile) {
    final stats = [
      _StatCard(
        icon: Icons.star_rounded,
        color: AppColors.star,
        value: profile.avgStarRating.toStringAsFixed(1),
        label: 'Ukadiriaji',
      ),
      _StatCard(
        icon: Icons.pending_actions_rounded,
        color: AppColors.statusInProgress,
        value: '$_actionCount',
        label: 'Zinahitaji kazi',
        onTap: () => _showOrders(_OrderFilter.action),
      ),
      _StatCard(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.statusDraftSubmitted,
        value: '$_waitingCount',
        label: 'Zinasubiri mteja',
        onTap: () => _showOrders(_OrderFilter.waiting),
      ),
      _StatCard(
        icon: Icons.insights_rounded,
        color: AppColors.primary,
        value: profile.compositeScore.toStringAsFixed(2),
        label: 'Alama ya ubora',
      ),
    ];

    return GridView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 76,
      ),
      children: stats,
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.add_business_rounded,
            color: AppColors.accent,
            label: 'Ongeza\nHuduma',
            onTap: _goToAddService,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.add_photo_alternate_rounded,
            color: const Color(0xFF8B5CF6),
            label: 'Ongeza\nKazi',
            onTap: _goToAddPortfolio,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_rounded,
            color: AppColors.primary,
            label: 'Oda\nZangu',
            onTap: () => _showOrders(_OrderFilter.all),
          ),
        ),
      ],
    );
  }

  Widget? _buildTip() {
    if (_services.isEmpty) {
      return _TipCard(
        icon: Icons.lightbulb_rounded,
        text: 'Bado hujaweka huduma. Ongeza huduma yako ya kwanza ili wateja waweze kukuagiza.',
        actionLabel: 'Ongeza huduma',
        onAction: _goToAddService,
      );
    }
    if (_portfolio.length < 3) {
      return _TipCard(
        icon: Icons.lightbulb_rounded,
        text:
            'Una kazi ${_portfolio.length} tu kwenye portfolio. '
            'Ongeza angalau 3 ili wateja waone uwezo wako.',
        actionLabel: 'Ongeza kazi',
        onAction: _goToAddPortfolio,
      );
    }
    return null;
  }

  // ---------- Oda ----------

  Widget _buildOrdersTab() {
    final orders = _filteredOrders;

    return Column(
      children: [
        Container(
          width: double.infinity,
          color: AppColors.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: _pagePadding(context, top: 4, bottom: 12),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Zote',
                  count: _orders.length,
                  selected: _orderFilter == _OrderFilter.all,
                  onTap: () => setState(() => _orderFilter = _OrderFilter.all),
                ),
                _FilterChip(
                  label: 'Zinahitaji kazi',
                  count: _actionCount,
                  selected: _orderFilter == _OrderFilter.action,
                  onTap: () =>
                      setState(() => _orderFilter = _OrderFilter.action),
                ),
                _FilterChip(
                  label: 'Zinasubiri mteja',
                  count: _waitingCount,
                  selected: _orderFilter == _OrderFilter.waiting,
                  onTap: () =>
                      setState(() => _orderFilter = _OrderFilter.waiting),
                ),
                _FilterChip(
                  label: 'Zimekamilika',
                  count: _doneCount,
                  selected: _orderFilter == _OrderFilter.done,
                  onTap: () => setState(() => _orderFilter = _OrderFilter.done),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.accent,
            onRefresh: _loadAll,
            child: orders.isEmpty
                ? _EmptyState(
                    icon: Icons.inbox_rounded,
                    title: _orders.isEmpty
                        ? 'Bado hakuna oda'
                        : 'Hakuna oda hapa',
                    subtitle: _orders.isEmpty
                        ? 'Ongeza huduma na kazi za portfolio ili wateja wakupate kwa urahisi'
                        : 'Jaribu kichujio kingine',
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _pagePadding(context),
                    itemCount: orders.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return _DesignerOrderCard(
                        order: order,
                        onTap: () => _openOrderChat(order),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  // ---------- Huduma ----------

  Widget _buildServicesTab() {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadAll,
      child: _services.isEmpty
          ? const _EmptyState(
              icon: Icons.work_outline_rounded,
              title: 'Bado hujaongeza huduma',
              subtitle: 'Bonyeza "Ongeza Huduma" hapo chini kuanza kupokea oda',
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: _pagePadding(context, bottom: 96),
              itemCount: _services.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  _ServiceCard(service: _services[index]),
            ),
    );
  }

  // ---------- Kazi (Portfolio) ----------

  Widget _buildPortfolioTab() {
    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: _loadAll,
      child: _portfolio.isEmpty
          ? const _EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'Bado hujaongeza kazi',
              subtitle:
                  'Wateja huamini zaidi wabunifu wenye sampuli za kazi zao',
            )
          : GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: _pagePadding(context, bottom: 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 240,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.82,
              ),
              itemCount: _portfolio.length,
              itemBuilder: (context, index) {
                final item = _portfolio[index];
                return InkWell(
                  onTap: () => _showPortfolioItem(item),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: AppDecorations.card(radius: 14),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: ServerImage(url: item.thumbnailUrl)),
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// =================== Widgets ndogo ===================

class _HeaderMini extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderMini({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white60, fontSize: 11),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: AppDecorations.card(radius: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: AppDecorations.card(radius: 16),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _TipCard({
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accentDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: const TextStyle(fontSize: 12.5, height: 1.4)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    '$actionLabel →',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentDark,
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
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionHeader({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.accentDark,
              ),
            ),
          ),
      ],
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(radius: 16),
      child: const Row(
        children: [
          Icon(
            Icons.celebration_rounded,
            color: AppColors.statusCompleted,
            size: 28,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Huna oda inayosubiri kazi kwa sasa. Kazi nzuri!',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white70 : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 90),
        Icon(icon, size: 56, color: AppColors.textMuted),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final ServiceModel service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
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
              Icons.design_services_rounded,
              color: AppColors.accent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Siku ${service.deliveryDays}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatTsh(service.price),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppColors.accentDark,
              fontSize: 14.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignerOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _DesignerOrderCard({required this.order, required this.onTap});

  /// Muda uliobaki hadi siku ya kukabidhi (null kama haijulikani au imekamilika)
  ({String text, Color color})? get _deadline {
    if (_isCompleted(order) || order.expectedDeliveryAt == null) return null;
    final due = DateTime.tryParse(order.expectedDeliveryAt!);
    if (due == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(
      due.toLocal().year,
      due.toLocal().month,
      due.toLocal().day,
    );
    final days = dueDay.difference(today).inDays;

    if (days < 0) {
      return (
        text: 'Imechelewa siku ${-days}',
        color: AppColors.statusDisputed,
      );
    }
    if (days == 0) {
      return (text: 'Leo ni siku ya mwisho', color: AppColors.accentDark);
    }
    if (days == 1) return (text: 'Siku 1 imebaki', color: AppColors.accentDark);
    return (text: 'Siku $days zimebaki', color: AppColors.textSecondary);
  }

  @override
  Widget build(BuildContext context) {
    final status = _OrderStatusStyle.of(order.status);
    final customer = order.customerName ?? 'Mteja';
    final deadline = _deadline;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: AppDecorations.card(radius: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(status.icon, color: status.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.serviceTitle ?? 'Oda #${order.id}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${order.id} • $customer',
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
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  if (deadline != null) ...[
                    Icon(Icons.event_rounded, size: 14, color: deadline.color),
                    const SizedBox(width: 4),
                    Text(
                      deadline.text,
                      style: TextStyle(
                        fontSize: 12,
                        color: deadline.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ] else
                    const Text(
                      'Utapokea',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    _formatTsh(order.netAmount),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.statusCompleted,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderStatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const _OrderStatusStyle(this.label, this.color, this.icon);

  static _OrderStatusStyle of(String status) {
    switch (status) {
      case 'PAID':
        return const _OrderStatusStyle(
          'Mpya',
          AppColors.statusPaid,
          Icons.fiber_new_rounded,
        );
      case 'IN_PROGRESS':
        return const _OrderStatusStyle(
          'Inaendelea',
          AppColors.statusInProgress,
          Icons.brush_rounded,
        );
      case 'DRAFT_SUBMITTED':
        return const _OrderStatusStyle(
          'Draft Imetumwa',
          AppColors.statusDraftSubmitted,
          Icons.outbox_rounded,
        );
      case 'COMPLETED':
        return const _OrderStatusStyle(
          'Imekamilika',
          AppColors.statusCompleted,
          Icons.check_circle_rounded,
        );
      case 'DISPUTED':
        return const _OrderStatusStyle(
          'Mgogoro',
          AppColors.statusDisputed,
          Icons.report_problem_rounded,
        );
      default:
        return _OrderStatusStyle(
          status,
          AppColors.textSecondary,
          Icons.receipt_rounded,
        );
    }
  }
}
