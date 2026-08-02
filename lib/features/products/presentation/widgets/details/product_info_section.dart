import 'package:flutter/material.dart';
import '../../../domain/product.dart';
import '../../../../../app/theme/app_colors.dart';

class ProductInfoSection extends StatelessWidget {
  final Product product;

  const ProductInfoSection({super.key, required this.product});

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
    Color textColor;
    String label;
    bool isOutOfStock = product.openingStock <= 0;
    bool isLowStock =
        product.openingStock > 0 &&
        product.openingStock <=
            (product.minStockLevel > 0 ? product.minStockLevel : 5);

    if (isOutOfStock) {
      textColor = const Color(0xFFB42318);
      label = 'Out of Stock';
    } else if (isLowStock) {
      textColor = AppColors.statusPendingText;
      label = 'Low Stock • ${product.openingStock}';
    } else {
      textColor = AppColors.statusApprovedText;
      label = 'Available • ${product.openingStock}';
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
