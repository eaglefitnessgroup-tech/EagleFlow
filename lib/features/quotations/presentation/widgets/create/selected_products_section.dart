import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../products/domain/product.dart';
import '../../../domain/quotation_line_item.dart';
import 'quotation_product_tile.dart';
import 'product_picker.dart';
import 'custom_product_form.dart';

class SelectedProductsSection extends StatefulWidget {
  final List<QuotationLineItem> items;
  final void Function(String, int) onQuantityChanged;
  final void Function(String, double) onUnitPriceChanged;
  final void Function(String, double) onDiscountChanged;
  final void Function(String) onRemove;
  final void Function(List<Product>) onProductsAdded;
  final void Function(QuotationLineItem) onCustomItemAdded;
  final void Function(String, QuotationLineItem) onCustomItemUpdated;

  const SelectedProductsSection({
    super.key,
    required this.items,
    required this.onQuantityChanged,
    required this.onUnitPriceChanged,
    required this.onDiscountChanged,
    required this.onRemove,
    required this.onProductsAdded,
    required this.onCustomItemAdded,
    required this.onCustomItemUpdated,
  });

  @override
  State<SelectedProductsSection> createState() =>
      _SelectedProductsSectionState();
}

class _SelectedProductsSectionState extends State<SelectedProductsSection> {
  bool _isPickerOpen = false;

  Future<void> _openProductPicker(BuildContext context) async {
    if (_isPickerOpen) return;
    _isPickerOpen = true;
    try {
      final products = await ProductPicker.show(context);
      if (!context.mounted) return;
      if (products != null && products.isNotEmpty) {
        widget.onProductsAdded(products);
      }
    } finally {
      _isPickerOpen = false;
    }
  }

  Future<void> _openCustomProductForm(
    BuildContext context, {
    QuotationLineItem? initialItem,
  }) async {
    final newItem = await CustomProductForm.show(
      context,
      initialItem: initialItem,
    );
    if (!context.mounted || newItem == null) return;

    if (initialItem == null) {
      widget.onCustomItemAdded(newItem);
    } else {
      widget.onCustomItemUpdated(initialItem.id, newItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Container(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMobile ? 'Products' : 'Selected Products',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.charcoal,
                    ),
                  ),
                  if (!isMobile)
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: () => _openProductPicker(context),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Product'),
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          onPressed: () => _openCustomProductForm(context),
                          icon: const Icon(Icons.add, size: 20),
                          label: const Text('Add Custom Item'),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _buildDesktopHeader(context),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  return QuotationProductTile(
                    key: ValueKey(item.id),
                    item: item,
                    onQuantityChanged: (qty) =>
                        widget.onQuantityChanged(item.id, qty),
                    onUnitPriceChanged: (price) =>
                        widget.onUnitPriceChanged(item.id, price),
                    onDiscountChanged: (disc) =>
                        widget.onDiscountChanged(item.id, disc),
                    onRemove: () => widget.onRemove(item.id),
                    onEdit: item.isCustom
                        ? () =>
                              _openCustomProductForm(context, initialItem: item)
                        : null,
                  );
                },
              ),
              if (isMobile) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openProductPicker(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Product'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: AppColors.charcoal,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openCustomProductForm(context),
                    icon: const Icon(Icons.add_box_outlined, size: 20),
                    label: const Text('Add Custom Item'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      foregroundColor: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return const SizedBox.shrink(); // Hide on mobile
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              SizedBox(width: 64), // For image space
              Expanded(
                flex: 3,
                child: Text(
                  'Product & Code',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Unit Price',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Qty',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Discount (%)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Line Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
              ),
              SizedBox(width: 48), // For remove button space
            ],
          ),
        );
      },
    );
  }
}
