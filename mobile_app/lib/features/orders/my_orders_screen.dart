import 'package:flutter/material.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../models/order_model.dart';
import 'order_chat_screen.dart';

enum _OrderFilter { all, active, completed }

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  final ApiClient _apiClient = ApiClient();
  List<OrderModel> _orders = [];
  bool _loading = true;
  String? _errorMessage;
  _OrderFilter _filter = _OrderFilter.all;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = _orders.isEmpty;
      _errorMessage = null;
    });
    try {
      final response = await _apiClient.dio.get('/orders/mine/customer');
      final List data = response.data['data'];
      if (!mounted) return;
      setState(() {
        _orders = data.map((json) => OrderModel.fromJson(json)).toList()
          ..sort((a, b) => b.id.compareTo(a.id)); // Mpya kwanza
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Imeshindwa kupakia oda zako';
        _loading = false;
      });
    }
  }

  List<OrderModel> get _filteredOrders {
    switch (_filter) {
      case _OrderFilter.active:
        return _orders.where((o) => o.status != 'COMPLETED').toList();
      case _OrderFilter.completed:
        return _orders.where((o) => o.status == 'COMPLETED').toList();
      case _OrderFilter.all:
        return _orders;
    }
  }

  int _countFor(_OrderFilter filter) {
    switch (filter) {
      case _OrderFilter.active:
        return _orders.where((o) => o.status != 'COMPLETED').length;
      case _OrderFilter.completed:
        return _orders.where((o) => o.status == 'COMPLETED').length;
      case _OrderFilter.all:
        return _orders.length;
    }
  }

  Future<void> _openChat(OrderModel order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderChatScreen(
          orderId: order.id,
          designerName: order.designerName ?? 'Mbunifu',
          serviceTitle: order.serviceTitle ?? 'Oda #${order.id}',
        ),
      ),
    );
    // Hali ya oda inaweza kuwa imebadilika ndani ya chat
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Oda Zangu'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Column(
              children: [
                if (_orders.isNotEmpty) _buildFilterBar(),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.accent,
                    onRefresh: _loadOrders,
                    child: _buildList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Row(
        children: [
          _FilterChip(
            label: 'Zote',
            count: _countFor(_OrderFilter.all),
            selected: _filter == _OrderFilter.all,
            onTap: () => setState(() => _filter = _OrderFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Zinaendelea',
            count: _countFor(_OrderFilter.active),
            selected: _filter == _OrderFilter.active,
            onTap: () => setState(() => _filter = _OrderFilter.active),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: 'Zimekamilika',
            count: _countFor(_OrderFilter.completed),
            selected: _filter == _OrderFilter.completed,
            onTap: () => setState(() => _filter = _OrderFilter.completed),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    // ListView inatumika hata kwenye hali tupu/kosa ili "vuta kushusha" ifanye kazi
    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          _MessageState(
            icon: Icons.wifi_off_rounded,
            title: _errorMessage!,
            subtitle: 'Angalia mtandao wako kisha ujaribu tena',
            actionLabel: 'Jaribu tena',
            onAction: _loadOrders,
          ),
        ],
      );
    }

    final orders = _filteredOrders;
    if (orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          _MessageState(
            icon: Icons.receipt_long_rounded,
            title: _orders.isEmpty
                ? 'Bado hujafanya oda yoyote'
                : 'Hakuna oda hapa',
            subtitle: _orders.isEmpty
                ? 'Tafuta mbunifu kwenye Huduma na uagize kazi yako ya kwanza'
                : 'Jaribu kichujio kingine',
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = orders[index];
        return _OrderCard(order: order, onTap: () => _openChat(order));
      },
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
    return Flexible(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
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

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  String? get _deliveryText {
    if (order.expectedDeliveryAt == null) return null;
    final date = DateTime.tryParse(order.expectedDeliveryAt!);
    if (date == null) return null;
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final status = _OrderStatusStyle.of(order.status);
    final designer = order.designerName ?? 'Mbunifu';
    final delivery = _deliveryText;

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
                        order.serviceTitle != null
                            ? '#${order.id} • $designer'
                            : designer,
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
                  if (delivery != null) ...[
                    const Icon(
                      Icons.event_rounded,
                      size: 14,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delivery,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ] else
                    const Text(
                      'Bonyeza kufungua chat',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  const Spacer(),
                  Text(
                    'TSh ${order.grossAmount.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.accentDark,
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
          'Imelipwa',
          AppColors.statusPaid,
          Icons.payments_rounded,
        );
      case 'IN_PROGRESS':
        return const _OrderStatusStyle(
          'Inaendelea',
          AppColors.statusInProgress,
          Icons.brush_rounded,
        );
      case 'DRAFT_SUBMITTED':
        return const _OrderStatusStyle(
          'Draft Tayari',
          AppColors.statusDraftSubmitted,
          Icons.visibility_rounded,
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

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          Icon(icon, size: 52, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
