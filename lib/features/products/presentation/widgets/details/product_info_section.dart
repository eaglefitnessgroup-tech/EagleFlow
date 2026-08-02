import 'package:flutter/material.dart';
import '../../../domain/product.dart';
import '../../../../../app/theme/app_colors.dart';

class ProductInfoSection extends StatelessWidget {
  final Product product;
  final int currentStock;
  final bool isLoading;
  final bool hasError;

  const ProductInfoSection({
    super.key,
    required this.product,
    required this.currentStock,
    required this.isLoading,
    required this.hasError,
  });

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          product.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.charcoal,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'AED ${_formatPrice(product.sellingPrice)}',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.primaryBlue,
          ),
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.brand,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.mutedText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              product.productCode,
              style: const TextStyle(fontSize: 14, color: AppColors.mutedText),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildStockIndicator(),
      ],
    );
  }

  Widget _buildStockIndicator() {
    if (isLoading) {
      return const Text(
        'Loading stock...',
        style: TextStyle(
          color: AppColors.mutedText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (hasError) {
      return const Text(
        'Stock calculation failed',
        style: TextStyle(
          color: AppColors.statusRejectedText,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    Color textColor;
    String label;
    bool isOutOfStock = currentStock <= 0;
    bool isLowStock =
        currentStock > 0 &&
        currentStock <= (product.minStockLevel > 0 ? product.minStockLevel : 5);

    if (isOutOfStock) {
      textColor = const Color(0xFFB42318);
      label = 'Out of Stock';
    } else if (isLowStock) {
      textColor = AppColors.statusPendingText;
      label = 'Low Stock • $currentStock';
    } else {
      textColor = AppColors.statusApprovedText;
      label = 'Available • $currentStock';
    }

    return Text(
      label,
      style: TextStyle(
        color: textColor,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
