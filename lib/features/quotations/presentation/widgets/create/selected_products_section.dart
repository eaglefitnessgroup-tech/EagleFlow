import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../../../../core/di/service_locator.dart';
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
  final TextEditingController _autocompleteController = TextEditingController();
  final FocusNode _autocompleteFocusNode = FocusNode();

  @override
  void dispose() {
    _autocompleteController.dispose();
    _autocompleteFocusNode.dispose();
    super.dispose();
  }

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
                  Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: AppColors.charcoal, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isMobile ? 'Items' : 'Quotation Items',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                  if (!isMobile)
                    Row(
                      children: [
                        _buildAutocompleteField(),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () => _openProductPicker(context),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Add Item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                          ),
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
                  child: ElevatedButton.icon(
                    onPressed: () => _openProductPicker(context),
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Add Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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

  Widget _buildAutocompleteField() {
    return SizedBox(
      width: 250,
      child: RawAutocomplete<Product>(
        textEditingController: _autocompleteController,
        focusNode: _autocompleteFocusNode,
        optionsBuilder: (TextEditingValue textEditingValue) {
          final query = textEditingValue.text.trim().toLowerCase();
          if (query.isEmpty) {
            return const Iterable<Product>.empty();
          }

          final allActiveProducts = ServiceLocator()
              .productMasterController
              .products
              .where((p) => p.isActive);

          final scoredProducts = <_ScoredProduct>[];

          for (final p in allActiveProducts) {
            final code = p.productCode.toLowerCase();
            final name = p.name.toLowerCase();
            final brand = p.brand.toLowerCase();
            final category = p.category.toLowerCase();

            if (code == query) {
              scoredProducts.add(_ScoredProduct(p, 0));
            } else if (code.startsWith(query)) {
              scoredProducts.add(_ScoredProduct(p, 1));
            } else if (name.startsWith(query)) {
              scoredProducts.add(_ScoredProduct(p, 2));
            } else if (name.contains(query)) {
              scoredProducts.add(_ScoredProduct(p, 3));
            } else if (code.contains(query)) {
              scoredProducts.add(_ScoredProduct(p, 4));
            } else if (brand.contains(query) || category.contains(query)) {
              scoredProducts.add(_ScoredProduct(p, 5));
            }
          }

          scoredProducts.sort((a, b) {
            if (a.score != b.score) return a.score.compareTo(b.score);
            return a.product.name.compareTo(b.product.name);
          });

          return scoredProducts.take(8).map((sp) => sp.product);
        },
        displayStringForOption: (Product option) => option.name,
        onSelected: (Product selection) {
          widget.onProductsAdded([selection]);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autocompleteController.clear();
            _autocompleteFocusNode.requestFocus();
          });
        },
        fieldViewBuilder: (BuildContext context,
            TextEditingController textEditingController,
            FocusNode focusNode,
            VoidCallback onFieldSubmitted) {
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            onSubmitted: (String value) {
              onFieldSubmitted();
            },
            decoration: InputDecoration(
              hintText: 'Search product by name, code...',
              hintStyle: const TextStyle(color: AppColors.mutedText, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AppColors.mutedText, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
          );
        },
        optionsViewBuilder: (BuildContext context,
            AutocompleteOnSelected<Product> onSelected,
            Iterable<Product> options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, color: AppColors.border),
                  itemBuilder: (BuildContext context, int index) {
                    final Product option = options.elementAt(index);
                    return InkWell(
                      onTap: () {
                        onSelected(option);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              option.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.charcoal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    option.productCode,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.mutedText),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  'AED ${option.sellingPrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ScoredProduct {
  final Product product;
  final int score;

  _ScoredProduct(this.product, this.score);
}
