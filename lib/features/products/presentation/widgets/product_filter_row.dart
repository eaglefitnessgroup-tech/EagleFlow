import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class ProductFilterRow extends StatelessWidget {
  final bool inStockOnly;
  final bool lowStockOnly;
  final ValueChanged<bool> onInStockToggled;
  final ValueChanged<bool> onLowStockToggled;

  const ProductFilterRow({
    super.key,
    required this.inStockOnly,
    required this.lowStockOnly,
    required this.onInStockToggled,
    required this.onLowStockToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFilterToggle(
              label: 'In Stock',
              isSelected: inStockOnly,
              onTap: () => onInStockToggled(!inStockOnly),
            ),
            _buildFilterToggle(
              label: 'Low Stock',
              isSelected: lowStockOnly,
              onTap: () => onLowStockToggled(!lowStockOnly),
            ),
          ],
        ),
        InkWell(
          onTap: () {
            // Sort placeholder
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sort functionality will be added later'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort, size: 18, color: AppColors.charcoal),
                SizedBox(width: 6),
                Text(
                  'Sort',
                  style: TextStyle(
                    color: AppColors.charcoal,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? AppColors.primaryBlue : AppColors.charcoal,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
