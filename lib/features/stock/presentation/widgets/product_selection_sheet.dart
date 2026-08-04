import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../../products/domain/product.dart';

class ProductSelectionSheet extends StatefulWidget {
  const ProductSelectionSheet({super.key});

  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ServiceLocator().productMasterController;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Select Product',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.mutedText),
                ),
              ],
            ),
          ),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: AppColors.mutedText,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
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
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Product List
          Expanded(
            child: ListenableBuilder(
              listenable: controller,
              builder: (context, _) {
                if (controller.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (controller.error != null) {
                  return Center(
                    child: Text(
                      controller.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                var products = controller.products;

                if (_searchQuery.isNotEmpty) {
                  products = products.where((p) {
                    return p.name.toLowerCase().contains(_searchQuery) ||
                        p.productCode.toLowerCase().contains(_searchQuery);
                  }).toList();
                }

                if (products.isEmpty) {
                  return const Center(
                    child: Text(
                      'No products found.',
                      style: TextStyle(color: AppColors.mutedText),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _ProductRow(
                      product: product,
                      onTap: () {
                        Navigator.pop(context, product);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductRow({required this.product, required this.onTap});

  @override
  State<_ProductRow> createState() => _ProductRowState();
}

class _ProductRowState extends State<_ProductRow> {
  int _currentStock = 0;
  bool _isLoadingStock = true;

  @override
  void initState() {
    super.initState();
    _fetchStock();
  }

  @override
  void didUpdateWidget(_ProductRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _fetchStock();
    }
  }

  Future<void> _fetchStock() async {
    setState(() => _isLoadingStock = true);
    try {
      final stock = await ServiceLocator().stockController.getCurrentStock(
        widget.product,
      );
      if (mounted) {
        setState(() {
          _currentStock = stock;
          _isLoadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingStock = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.inventory_2,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.product.productCode.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${widget.product.productCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'In Stock',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
                const SizedBox(height: 2),
                _isLoadingStock
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        '$_currentStock',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.charcoal,
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
