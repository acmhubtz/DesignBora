import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../models/category_model.dart';
import '../auth/auth_provider.dart';
import 'catalog_service.dart';
import 'search_results_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CatalogService _catalogService = CatalogService();
  final _searchController = TextEditingController();

  List<CategoryModel> _categories = [];
  bool _loadingCategories = true;
  bool _categoriesFailed = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _loadingCategories = _categories.isEmpty;
      _categoriesFailed = false;
    });
    try {
      final categories = await _catalogService.getTopCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingCategories = false;
        _categoriesFailed = true;
      });
    }
  }

  void _goToSearch({
    String? categorySlug,
    String? categoryName,
    String? query,
  }) {
    FocusScope.of(context).unfocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          categorySlug: categorySlug,
          initialQuery: query,
          title: categoryName ?? query ?? 'Matokeo',
        ),
      ),
    );
  }

  void _submitSearch() {
    final value = _searchController.text.trim();
    if (value.isNotEmpty) _goToSearch(query: value);
  }

  IconData _iconForCategory(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('video')) return Icons.videocam_rounded;
    if (lower.contains('logo')) return Icons.auto_awesome_rounded;
    if (lower.contains('poster')) return Icons.image_rounded;
    if (lower.contains('flyer')) return Icons.description_rounded;
    if (lower.contains('banner')) return Icons.panorama_rounded;
    if (lower.contains('photo')) return Icons.camera_alt_rounded;
    return Icons.brush_rounded;
  }

  Color _colorForIndex(int index) {
    const colors = [
      AppColors.primary,
      AppColors.accent,
      Color(0xFF8B5CF6),
      Color(0xFF059669),
      Color(0xFF2563EB),
      Color(0xFFDC2626),
    ];
    return colors[index % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: _loadCategories,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHero(),
              Transform.translate(
                offset: const Offset(0, -24),
                child: _buildCategorySection(),
              ),
              _buildHowItWorks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final fullName = context.watch<AuthProvider>().user?.fullName ?? '';
    final firstName = fullName.trim().isEmpty
        ? null
        : fullName.trim().split(' ').first;

    return Container(
      width: double.infinity,
      decoration: AppDecorations.primaryGradientBox,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'B',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'DesignBora',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (firstName != null) ...[
                Text(
                  'Habari, $firstName 👋',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              const Text(
                'Pata Kazi za Ubunifu\nTanzania',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Soko salama la kuajiri wabunifu wa picha na video wa hapa nyumbani.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 22),
              _buildSearchBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppDecorations.floatingShadow,
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _searchController,
        builder: (context, value, _) {
          final hasText = value.text.trim().isNotEmpty;
          return TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _submitSearch(),
            decoration: InputDecoration(
              hintText: 'Tafuta logo, poster, au video...',
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.textSecondary,
              ),
              suffixIcon: hasText
                  ? Padding(
                      padding: const EdgeInsets.all(6),
                      child: Material(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: _submitSearch,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategorySection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Idara Maarufu',
            subtitle: 'Chagua aina ya kazi unayohitaji',
          ),
          const SizedBox(height: 16),
          if (_loadingCategories)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            )
          else if (_categoriesFailed)
            _InlineMessage(
              icon: Icons.wifi_off_rounded,
              text: 'Imeshindwa kupakia idara',
              actionLabel: 'Jaribu tena',
              onAction: _loadCategories,
            )
          else if (_categories.isEmpty)
            const _InlineMessage(
              icon: Icons.category_outlined,
              text: 'Bado hakuna idara zilizowekwa',
            )
          else
            GridView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return _CategoryTile(
                  icon: _iconForCategory(cat.name),
                  color: _colorForIndex(index),
                  name: cat.name,
                  onTap: () => _goToSearch(
                    categorySlug: cat.slug,
                    categoryName: cat.name,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.card(radius: 18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Jinsi Inavyofanya Kazi',
            subtitle: 'Hatua tatu rahisi, pesa yako ikiwa salama',
          ),
          SizedBox(height: 16),
          _HowStep(
            icon: Icons.search_rounded,
            color: AppColors.primary,
            title: 'Tafuta mbunifu',
            text: 'Linganisha kazi zao, bei na maoni ya wateja wengine.',
          ),
          _HowStep(
            icon: Icons.lock_rounded,
            color: AppColors.accent,
            title: 'Lipa kwa usalama',
            text: 'Pesa inashikiliwa na DesignBora hadi kazi ikamilike.',
          ),
          _HowStep(
            icon: Icons.download_done_rounded,
            color: AppColors.statusCompleted,
            title: 'Pokea kazi yako',
            text: 'Kagua draft, thibitisha, kisha pakua faili kamili.',
            last: true,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            subtitle,
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

class _CategoryTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String name;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.icon,
    required this.color,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final bool last;

  const _HowStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    height: 1.35,
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

class _InlineMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _InlineMessage({
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onAction,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 18,
                  color: AppColors.accent,
                ),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
