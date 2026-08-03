import 'package:flutter/material.dart';
import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/di/service_locator.dart';
import '../../../domain/product.dart';
import '../../../../stock/domain/stock_movement.dart';
import '../../../../stock/presentation/widgets/stock_adjustment_bottom_sheet.dart';

class ProductStockSection extends StatelessWidget {
  final Product product;
  final int currentStock;
  final bool isLoading;
  final bool hasError;
  final VoidCallback onRetry;
  final VoidCallback onStockAdjusted;

  const ProductStockSection({
    super.key,
    required this.product,
    required this.currentStock,
    required this.isLoading,
    required this.hasError,
    required this.onRetry,
    required this.onStockAdjusted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Stock',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 16),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (hasError)
            Center(
              child: Column(
                children: [
                  const Text('Failed to load stock data.'),
                  TextButton(onPressed: onRetry, child: const Text('Retry')),
                ],
              ),
            )
          else
            _buildStockDetails(context),
        ],
      ),
    );
  }

  Widget _buildStockDetails(BuildContext context) {
    String statusText;
    Color statusColor;

    if (currentStock <= 0) {
      statusText = 'Out of Stock';
      statusColor = AppColors.statusRejectedText;
    } else if (currentStock <= product.minStockLevel) {
      statusText = 'Low Stock';
      statusColor = AppColors.statusPendingText;
    } else {
      statusText = 'In Stock';
      statusColor = AppColors.statusApprovedText;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStat(
              'Current Stock',
              currentStock.toString(),
              isHighlight: true,
            ),
            _buildStat('Status', statusText, valueColor: statusColor),
          ],
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12.0),
          child: Divider(height: 1, color: AppColors.border),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStat('Opening Stock', product.openingStock.toString()),
            _buildStat('Minimum Stock', product.minStockLevel.toString()),
          ],
        ),
        if (ServiceLocator().authController.isAdmin) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    StockAdjustmentBottomSheet.show(
                      context,
                      productId: product.id,
                      initialType: StockMovementType.stockIn,
                      onSuccess: onStockAdjusted,
                    );
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  label: const Text('Stock In'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusApprovedText,
                    side: const BorderSide(color: AppColors.statusApprovedText),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    StockAdjustmentBottomSheet.show(
                      context,
                      productId: product.id,
                      initialType: StockMovementType.stockOut,
                      onSuccess: onStockAdjusted,
                    );
                  },
                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                  label: const Text('Stock Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusRejectedText,
                    side: const BorderSide(color: AppColors.statusRejectedText),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStat(
    String label,
    String value, {
    Color? valueColor,
    bool isHighlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.mutedText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 20 : 16,
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.charcoal,
          ),
        ),
      ],
    );
  }
}
