import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../models/category_model.dart';
import 'catalog_service.dart';
import 'search_results_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final CatalogService _catalogService = CatalogService();
  List<CategoryModel> _topCategories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _catalogService.getTopCategories();
      if (!mounted) return;
      setState(() {
        _topCategories = categories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _openCategory(CategoryModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SearchResultsScreen(
          categorySlug: category.slug,
          title: category.name,
        ),
      ),
    );
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
      appBar: AppBar(
        title: const Text('Huduma Zetu'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Chagua Aina ya Huduma',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Tafuta wataalamu bora kwa mahitaji yako',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                ...List.generate(_topCategories.length, (index) {
                  final category = _topCategories[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ServiceCategoryCard(
                      icon: _iconForCategory(category.name),
                      name: category.name,
                      color: _colorForIndex(index),
                      onTap: () => _openCategory(category),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class _ServiceCategoryCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final Color color;
  final VoidCallback onTap;

  const _ServiceCategoryCard({
    required this.icon,
    required this.name,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: AppDecorations.card(radius: 16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Angalia wabunifu wote',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.textSecondary,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
