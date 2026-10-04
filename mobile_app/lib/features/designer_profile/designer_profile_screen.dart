import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../core/widgets/server_image.dart';
import '../../models/portfolio_model.dart';
import '../../models/service_model.dart';
import '../../models/review_model.dart';
import '../orders/order_confirmation_screen.dart';
import 'designer_service.dart';

class DesignerProfileScreen extends StatefulWidget {
  final int designerId;
  final String designerName;
  final bool verified;
  final double avgStarRating;

  const DesignerProfileScreen({
    super.key,
    required this.designerId,
    required this.designerName,
    required this.verified,
    required this.avgStarRating,
  });

  @override
  State<DesignerProfileScreen> createState() => _DesignerProfileScreenState();
}

class _DesignerProfileScreenState extends State<DesignerProfileScreen>
    with SingleTickerProviderStateMixin {
  final DesignerService _designerService = DesignerService();
  late TabController _tabController;

  List<PortfolioModel> _portfolio = [];
  List<ServiceModel> _services = [];
  List<ReviewModel> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    try {
      final results = await Future.wait([
        _designerService.getPortfolio(widget.designerId),
        _designerService.getServices(widget.designerId),
        _designerService.getReviews(widget.designerId),
      ]);
      if (!mounted) return;
      setState(() {
        _portfolio = results[0] as List<PortfolioModel>;
        _services = results[1] as List<ServiceModel>;
        _reviews = results[2] as List<ReviewModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _goToOrderConfirmation(ServiceModel service) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderConfirmationScreen(
          service: service,
          designerName: widget.designerName,
        ),
      ),
    );
  }

  /// Mteja anabonyeza kazi ya portfolio -> anaona picha kubwa na maelezo yake
  void _showPortfolioItem(PortfolioModel item) {
    final hasDescription =
        item.description != null && item.description!.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: InteractiveViewer(
                      maxScale: 4,
                      child: ServerImage(
                        url: item.thumbnailUrl,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text(
                'Bana kwa vidole viwili kukuza picha',
                style: TextStyle(fontSize: 11, color: AppColors.textMuted),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          widget.designerName.isNotEmpty
                              ? widget.designerName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.designerName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      if (widget.verified) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: AppColors.statusCompleted,
                          size: 15,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'MAELEZO YA KAZI',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hasDescription
                        ? item.description!.trim()
                        : 'Mbunifu hakuandika maelezo ya kazi hii.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: hasDescription
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontStyle: hasDescription
                          ? FontStyle.normal
                          : FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _tabController.animateTo(1);
                      },
                      icon: const Icon(Icons.design_services_rounded, size: 20),
                      label: const Text(
                        'Angalia Huduma za Mbunifu Huyu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Wasifu wa Mbunifu'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : Column(
              children: [
                _buildHeader(),
                Container(
                  color: AppColors.surface,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.accent,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                    tabs: const [
                      Tab(text: 'Kazi'),
                      Tab(text: 'Huduma'),
                      Tab(text: 'Maoni'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPortfolioTab(),
                      _buildServicesTab(),
                      _buildReviewsTab(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: AppColors.surface,
      child: Column(
        children: [
          CircleAvatar(
            radius: 38,
            backgroundColor: AppColors.primary,
            child: Text(
              widget.designerName.isNotEmpty
                  ? widget.designerName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  widget.designerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.verified) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.verified_rounded,
                  color: AppColors.statusCompleted,
                  size: 20,
                ),
              ],
            ],
          ),
          if (widget.verified) ...[
            const SizedBox(height: 4),
            const Text(
              'Mbunifu Aliyethibitishwa',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.statusCompleted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.star_rounded,
                    iconColor: AppColors.star,
                    value: widget.avgStarRating.toStringAsFixed(1),
                    label: 'Ukadiriaji',
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _StatItem(
                    icon: Icons.chat_bubble_rounded,
                    iconColor: AppColors.primary,
                    value: '${_reviews.length}',
                    label: 'Maoni',
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.border),
                Expanded(
                  child: _StatItem(
                    icon: Icons.work_rounded,
                    iconColor: AppColors.accent,
                    value: '${_services.length}',
                    label: 'Huduma',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioTab() {
    if (_portfolio.isEmpty) {
      return const _EmptyState(
        icon: Icons.photo_library_outlined,
        message: 'Bado hakuna sampuli za kazi',
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 240,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.82,
      ),
      itemCount: _portfolio.length,
      itemBuilder: (context, index) {
        final item = _portfolio[index];
        final hasDescription =
            item.description != null && item.description!.trim().isNotEmpty;
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
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasDescription
                            ? item.description!.trim()
                            : 'Gusa kuona zaidi',
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
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildServicesTab() {
    if (_services.isEmpty) {
      return const _EmptyState(
        icon: Icons.work_off_outlined,
        message: 'Bado hakuna huduma zilizowekwa',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _services.length,
      separatorBuilder: (context, index) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final service = _services[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.card(radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Siku ${service.deliveryDays} za kukamilika',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'TSh ${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentDark,
                        fontSize: 17,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _goToOrderConfirmation(service),
                    icon: const Icon(Icons.shopping_bag_rounded, size: 16),
                    label: const Text(
                      'Agiza',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    if (_reviews.isEmpty) {
      return const _EmptyState(
        icon: Icons.rate_review_outlined,
        message: 'Bado hakuna maoni',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final review = _reviews[index];
        final hasComment = review.comment != null && review.comment!.isNotEmpty;
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: AppDecorations.card(radius: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...List.generate(5, (i) {
                    return Icon(
                      i < review.starRating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: AppColors.star,
                      size: 18,
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    '${review.starRating}/5',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                hasComment ? review.comment! : 'Mteja hakuandika maoni',
                style: TextStyle(
                  fontSize: 13,
                  color: hasComment ? null : AppColors.textMuted,
                  fontStyle: hasComment ? FontStyle.normal : FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
