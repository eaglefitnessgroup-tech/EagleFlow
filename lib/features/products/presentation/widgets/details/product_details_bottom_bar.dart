import 'package:flutter/material.dart';
import '../../../domain/product.dart';
import '../../../../../app/theme/app_colors.dart';

class ProductDetailsBottomBar extends StatelessWidget {
  final Product product;
  final int quantity;
  final VoidCallback onAddToQuotation;

  const ProductDetailsBottomBar({
    super.key,
    required this.product,
    required this.quantity,
    required this.onAddToQuotation,
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
    final double totalPrice = product.sellingPrice * quantity;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: 16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -4),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Price',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AED ${_formatPrice(totalPrice)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ElevatedButton(
                onPressed: onAddToQuotation,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Add to Quotation',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
