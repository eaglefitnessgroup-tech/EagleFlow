import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../products/domain/product.dart';
import '../../../../../../core/di/service_locator.dart';

class ProductPicker {
  static Future<List<Product>?> show(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return showModalBottomSheet<List<Product>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const _ProductPickerContent(isModal: true),
      );
    } else {
      return showDialog<List<Product>>(
        context: context,
        builder: (context) => const Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(24),
          child: _ProductPickerContent(isModal: false),
        ),
      );
    }
  }
}

class _ProductPickerContent extends StatefulWidget {
  final bool isModal;

  const _ProductPickerContent({required this.isModal});

  @override
  State<_ProductPickerContent> createState() => _ProductPickerContentState();
}

class _ProductPickerContentState extends State<_ProductPickerContent> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedIds = {};

  List<Product> _filteredProducts = [];
  bool _isLoading = true;
  bool _isSubmitting = false;

  Timer? _loadingTimer;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadProducts() {
    setState(() {
      _isLoading = false;
      _onSearchChanged();
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();

    // Only get active products
    final allActiveProducts = ServiceLocator().productMasterController.products
        .where((p) => p.isActive)
        .toList();

    if (query.isEmpty) {
      setState(() {
        _filteredProducts = _sortProducts(allActiveProducts);
      });
      return;
    }

    final filtered = allActiveProducts.where((p) {
      final nameMatches = p.name.toLowerCase().contains(query);
      final codeMatches = p.productCode.toLowerCase().contains(query);
      final brandMatches = p.brand.toLowerCase().contains(query);
      final categoryMatches = p.category.toLowerCase().contains(query);
      return nameMatches || codeMatches || brandMatches || categoryMatches;
    }).toList();

    setState(() {
      _filteredProducts = _sortProducts(filtered);
    });
  }

  List<Product> _sortProducts(List<Product> products) {
    final List<Product> sorted = List.from(products);
    sorted.sort((a, b) {
      final aInStock = a.openingStock > 0;
      final bInStock = b.openingStock > 0;

      if (aInStock && !bInStock) return -1;
      if (!aInStock && bInStock) return 1;

      return a.name.compareTo(b.name);
    });
    return sorted;
  }

  void _toggleSelection(Product product) {
    setState(() {
      if (_selectedIds.contains(product.id)) {
        _selectedIds.remove(product.id);
      } else {
        _selectedIds.add(product.id);
      }
    });
  }

  String _formatCurrency(double amount) {
    String priceStr = amount.toStringAsFixed(2);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final bool isMobile = size.width < 600;

    final content = Container(
      width: isMobile ? double.infinity : 600,
      height: isMobile ? size.height * 0.9 : 800,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(child: _buildList()),
          _buildBottomActionBar(),
        ],
      ),
    );

    // If modal, it sits at the bottom. If dialog, it's centered.
    // The padding for keyboard on modal is handled by isScrollControlled naturally if we use Scaffold or Padding,
    // but a Container inside BottomSheet might need EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom).
    if (widget.isModal) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: content,
      );
    }

    return content;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: AppColors.mutedText),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by name, code, or brand...',
          hintStyle: const TextStyle(color: AppColors.mutedText),
          prefixIcon: const Icon(Icons.search, color: AppColors.mutedText),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryBlue),
          ),
          filled: true,
          fillColor: AppColors.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBlue),
      );
    }

    if (_filteredProducts.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.border),
            SizedBox(height: 16),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Try adjusting your search query',
              style: TextStyle(color: AppColors.mutedText),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredProducts.length,
      itemBuilder: (context, index) {
        final product = _filteredProducts[index];
        final isSelected = _selectedIds.contains(product.id);
        final inStock = product.openingStock > 0;

        return _buildProductTile(product, isSelected, inStock);
      },
    );
  }

  Widget _buildProductTile(Product product, bool isSelected, bool inStock) {
    return GestureDetector(
      onTap: () {
        // Stock confirmation is skipped for step 2.1 as per instruction: "Do NOT implement stock confirmation."
        _toggleSelection(product);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: isSelected,
                onChanged: (val) {
                  _toggleSelection(product);
                },
                activeColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: const BorderSide(color: AppColors.border, width: 1.5),
              ),
            ),
            const SizedBox(width: 12),
            // Image
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: product.imageBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        product.imageBytes!,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, error, stackTrace) {
                          debugPrint('Product image failed: — $error');
                          return const SizedBox.shrink();
                        },
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(width: 16),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.brand} • ${product.productCode}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: inStock
                                ? AppColors.statusApprovedBg
                                : AppColors.background,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            inStock
                                ? '${product.openingStock} in stock'
                                : 'Out of stock',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: inStock
                                  ? AppColors.statusApprovedText
                                  : AppColors.mutedText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'AED ${_formatCurrency(product.sellingPrice)}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActionBar() {
    final int count = _selectedIds.length;
    final String selectedText = count == 1
        ? '1 Product Selected'
        : '$count Products Selected';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedText,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.charcoal,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                foregroundColor: AppColors.charcoal,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: (_selectedIds.isEmpty || _isLoading || _isSubmitting)
                  ? null
                  : () {
                      setState(() {
                        _isSubmitting = true;
                      });
                      final allProducts =
                          ServiceLocator().productMasterController.products;
                      final selectedProducts = allProducts
                          .where((p) => _selectedIds.contains(p.id))
                          .toList();
                      Navigator.of(context).pop(selectedProducts);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                backgroundColor: AppColors.primaryBlue,
                disabledBackgroundColor: AppColors.primaryBlue.withValues(
                  alpha: 0.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Add Selected',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
