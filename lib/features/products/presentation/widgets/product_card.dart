import 'package:flutter/material.dart';
import '../../domain/product.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/di/service_locator.dart';
import '../add_edit_product_screen.dart';
import '../product_details_screen.dart';

class ProductCard extends StatefulWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isLoadingStock = true;
  bool _hasStockError = false;
  int _currentStock = 0;

  @override
  void initState() {
    super.initState();
    _fetchStock();
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id) {
      _fetchStock();
    }
  }

  Future<void> _fetchStock() async {
    setState(() {
      _isLoadingStock = true;
      _hasStockError = false;
    });
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
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasStockError = true;
          _isLoadingStock = false;
        });
      }
    }
  }

  String _formatPrice(double price) {
    String priceStr = price.toStringAsFixed(2);
    if (priceStr.endsWith('.00')) {
      priceStr = price.toStringAsFixed(0);
    }
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => const ProductDetailsScreen(),
            settings: RouteSettings(arguments: widget.product),
          ),
        );
        _fetchStock();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Placeholder
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primarySoft.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.border.withValues(alpha: 0.5),
                ),
              ),
              child: _buildProductImage(),
            ),
            const SizedBox(width: 16),
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.brand,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.product.productCode,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AED ${_formatPrice(widget.product.sellingPrice)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      _buildStockIndicator(),
                    ],
                  ),
                  if (ServiceLocator().authController.isAdmin) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (ctx) => AddEditProductScreen(
                                    product: widget.product,
                                  ),
                                ),
                              );
                              _fetchStock();
                            },
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: AppColors.primaryBlue,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              foregroundColor: AppColors.primaryBlue,
                            ),
                            child: const Text(
                              'Edit Product',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    if (widget.product.imageBytes != null &&
        widget.product.imageBytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          widget.product.imageBytes!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.mutedText,
            size: 24,
          ),
        ),
      );
    }
    return const Icon(
      Icons.image_outlined,
      color: AppColors.mutedText,
      size: 24,
    );
  }

  Widget _buildStockIndicator() {
    if (_isLoadingStock) {
      return const Text(
        'Loading...',
        style: TextStyle(
          color: AppColors.mutedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_hasStockError) {
      return const Text(
        'Error',
        style: TextStyle(
          color: AppColors.statusRejectedText,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Color textColor;
    String label;
    bool isOutOfStock = _currentStock <= 0;
    bool isLowStock =
        _currentStock > 0 &&
        _currentStock <=
            (widget.product.minStockLevel > 0
                ? widget.product.minStockLevel
                : 5);

    if (isOutOfStock) {
      textColor = const Color(0xFFB42318);
      label = 'Out of Stock';
    } else if (isLowStock) {
      textColor = AppColors.statusPendingText;
      label = 'Low Stock • $_currentStock';
    } else {
      textColor = AppColors.statusApprovedText;
      label = 'Available • $_currentStock';
    }

    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
