import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_decorations.dart';
import '../../models/category_model.dart';
import 'designer_dashboard_service.dart';

String _formatTsh(double amount) {
  final digits = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return 'TSh $buffer';
}

class AddServiceScreen extends StatefulWidget {
  const AddServiceScreen({super.key});

  @override
  State<AddServiceScreen> createState() => _AddServiceScreenState();
}

class _AddServiceScreenState extends State<AddServiceScreen> {
  static const _quickDays = [1, 2, 3, 5, 7];

  final _service = DesignerDashboardService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _daysController = TextEditingController(text: '2');

  List<CategoryModel> _categories = [];
  CategoryModel? _selectedCategory;
  bool _loading = true;
  bool _loadFailed = false;
  bool _submitting = false;
  String? _errorMessage;

  // Ada ya platform (inasomwa kutoka backend; 10% ni ya akiba tu)
  String _feeType = 'PERCENTAGE';
  double _feePercentage = 10;
  double _feeFixed = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final categories = await _service.getAllCategoriesFlat();
      try {
        final fee = await _service.getFeeInfo();
        _feeType = fee.type;
        _feePercentage = fee.percentage;
        _feeFixed = fee.fixed;
      } catch (_) {
        // Tunatumia 10% ya akiba
      }
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  double? get _price =>
      double.tryParse(_priceController.text.replaceAll(',', '').trim());

  double _feeFor(double price) {
    if (_feeType == 'PERCENTAGE') {
      return (price * _feePercentage / 100).roundToDouble();
    }
    return _feeFixed;
  }

  String get _feeLabel => _feeType == 'PERCENTAGE'
      ? 'Ada ya DesignBora (${_feePercentage.toStringAsFixed(_feePercentage % 1 == 0 ? 0 : 1)}%)'
      : 'Ada ya DesignBora';

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      setState(() => _errorMessage = 'Chagua idara ya huduma');
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await _service.createService(
        categoryId: _selectedCategory!.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        price: _price!,
        deliveryDays: int.parse(_daysController.text.trim()),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
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
    return 'Imeshindwa kuongeza huduma. Jaribu tena.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ongeza Huduma'),
        backgroundColor: AppColors.surface,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  const Text('Imeshindwa kupakia idara'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Jaribu tena'),
                  ),
                ],
              ),
            )
          : _buildForm(),
      bottomNavigationBar: _loading || _loadFailed ? null : _buildSubmitBar(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('Idara'),
                DropdownButtonFormField<CategoryModel>(
                  initialValue: _selectedCategory,
                  isExpanded: true,
                  hint: const Text('Chagua idara'),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded, size: 20),
                  ),
                  items: _categories
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (v) => setState(() {
                          _selectedCategory = v;
                          _errorMessage = null;
                        }),
                ),
                const SizedBox(height: 16),
                const _Label('Jina la huduma'),
                TextFormField(
                  controller: _titleController,
                  enabled: !_submitting,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Mfano: Poster ya tukio la kanisa',
                    prefixIcon: Icon(Icons.title_rounded, size: 20),
                  ),
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Jina linahitajika';
                    if (value.length < 5) return 'Jina liwe na maelezo zaidi';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const _Label('Maelezo (hiari)'),
                TextFormField(
                  controller: _descriptionController,
                  enabled: !_submitting,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Eleza unachotoa: idadi ya marekebisho, aina ya mafaili (PNG, PDF, PSD)...',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: AppDecorations.card(radius: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Label('Bei kwa mteja (TSh)'),
                TextFormField(
                  controller: _priceController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: '25000',
                    prefixIcon: Icon(Icons.payments_rounded, size: 20),
                    prefixText: 'TSh ',
                  ),
                  validator: (v) {
                    final price = double.tryParse((v ?? '').trim());
                    if (price == null) return 'Weka bei';
                    if (price < 1000) return 'Bei ya chini ni TSh 1,000';
                    return null;
                  },
                ),
                if ((_price ?? 0) > 0) ...[
                  const SizedBox(height: 12),
                  _buildEarningsPreview(_price!),
                ],
                const SizedBox(height: 18),
                const _Label('Muda wa kukamilisha'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _quickDays.map((d) {
                    final selected = _daysController.text.trim() == '$d';
                    return ChoiceChip(
                      label: Text(d == 1 ? 'Siku 1' : 'Siku $d'),
                      selected: selected,
                      selectedColor: AppColors.accent.withValues(alpha: 0.18),
                      labelStyle: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: selected
                            ? AppColors.accentDark
                            : AppColors.textPrimary,
                      ),
                      onSelected: _submitting
                          ? null
                          : (_) => setState(() => _daysController.text = '$d'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _daysController,
                  enabled: !_submitting,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Au andika idadi ya siku',
                    prefixIcon: Icon(Icons.schedule_rounded, size: 20),
                    suffixText: 'siku',
                  ),
                  validator: (v) {
                    final days = int.tryParse((v ?? '').trim());
                    if (days == null || days < 1) {
                      return 'Weka idadi ya siku (angalau 1)';
                    }
                    if (days > 90) return 'Muda usizidi siku 90';
                    return null;
                  },
                ),
              ],
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
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
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildEarningsPreview(double price) {
    final fee = _feeFor(price);
    final earnings = (price - fee).clamp(0, double.infinity).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.statusCompleted.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.statusCompleted.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        children: [
          _row('Mteja analipa', _formatTsh(price)),
          const SizedBox(height: 6),
          _row(_feeLabel, '- ${_formatTsh(fee)}', muted: true),
          const Divider(height: 18),
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                size: 18,
                color: AppColors.statusCompleted,
              ),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Utapokea',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                _formatTsh(earnings),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColors.statusCompleted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool muted = false}) {
    final style = TextStyle(
      fontSize: 13,
      color: muted ? AppColors.textSecondary : AppColors.textPrimary,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SizedBox(
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
            onPressed: _submitting ? null : _handleSubmit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_business_rounded, size: 20),
            label: Text(
              _submitting ? 'Inahifadhi...' : 'Weka Huduma',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
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
