import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../domain/quotation_line_item.dart';
import '../../../application/quotation_calculator.dart';

class QuotationProductTile extends StatefulWidget {
  final QuotationLineItem item;
  final VoidCallback onRemove;
  final ValueChanged<int> onQuantityChanged;
  final ValueChanged<double> onUnitPriceChanged;
  final ValueChanged<double> onDiscountChanged;

  const QuotationProductTile({
    super.key,
    required this.item,
    required this.onRemove,
    required this.onQuantityChanged,
    required this.onUnitPriceChanged,
    required this.onDiscountChanged,
  });

  @override
  State<QuotationProductTile> createState() => _QuotationProductTileState();
}

class _QuotationProductTileState extends State<QuotationProductTile> {
  late TextEditingController _qtyController;
  late TextEditingController _priceController;
  late TextEditingController _discountController;

  final FocusNode _qtyFocus = FocusNode();
  final FocusNode _priceFocus = FocusNode();
  final FocusNode _discountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qtyController = TextEditingController(
      text: widget.item.quantity.toString(),
    );
    _priceController = TextEditingController(
      text: widget.item.unitPrice.toStringAsFixed(2),
    );
    _discountController = TextEditingController(
      text: widget.item.discount.toStringAsFixed(2),
    );

    _qtyFocus.addListener(_onQtyFocusChange);
    _priceFocus.addListener(_onPriceFocusChange);
    _discountFocus.addListener(_onDiscountFocusChange);
  }

  @override
  void didUpdateWidget(QuotationProductTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_qtyFocus.hasFocus &&
        oldWidget.item.quantity != widget.item.quantity) {
      _qtyController.text = widget.item.quantity.toString();
    }
    if (!_priceFocus.hasFocus &&
        oldWidget.item.unitPrice != widget.item.unitPrice) {
      _priceController.text = widget.item.unitPrice.toStringAsFixed(2);
    }
    if (!_discountFocus.hasFocus &&
        oldWidget.item.discount != widget.item.discount) {
      _discountController.text = widget.item.discount.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _qtyFocus.removeListener(_onQtyFocusChange);
    _priceFocus.removeListener(_onPriceFocusChange);
    _discountFocus.removeListener(_onDiscountFocusChange);
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _discountFocus.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _onQtyFocusChange() {
    if (!_qtyFocus.hasFocus) {
      final val = int.tryParse(_qtyController.text) ?? 1;
      final clamped = val < 1 ? 1 : val;
      _qtyController.text = clamped.toString();
      widget.onQuantityChanged(clamped);
    }
  }

  void _onPriceFocusChange() {
    if (!_priceFocus.hasFocus) {
      final val = double.tryParse(_priceController.text) ?? 0.0;
      final clamped = val < 0 ? 0.0 : val;
      _priceController.text = clamped.toStringAsFixed(2);
      widget.onUnitPriceChanged(clamped);
    }
  }

  void _onDiscountFocusChange() {
    if (!_discountFocus.hasFocus) {
      final val = double.tryParse(_discountController.text) ?? 0.0;
      final clamped = val.clamp(0.0, 100.0);
      _discountController.text = clamped.toStringAsFixed(2);
      widget.onDiscountChanged(clamped);
    }
  }

  String _formatCurrency(double amount) {
    String priceStr = amount.toStringAsFixed(2);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return priceStr.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return _buildMobileCard();
        } else {
          return _buildDesktopRow();
        }
      },
    );
  }

  Widget _buildMobileCard() {
    final double lineTotal = QuotationCalculator.calculateLineTotal(
      widget.item.unitPrice,
      widget.item.quantity,
      widget.item.discount,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.name,
                      maxLines: 2,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.item.brand} • ${widget.item.productCode}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.statusApprovedBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'In Stock',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.statusApprovedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black38, size: 20),
                onPressed: widget.onRemove,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildEditableField(
                  'Qty',
                  _qtyController,
                  _qtyFocus,
                  TextInputType.number,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildEditableField(
                  'Discount (%)',
                  _discountController,
                  _discountFocus,
                  const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: AppColors.border),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unit Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 32,
                      width: 100,
                      child: TextField(
                        controller: _priceController,
                        focusNode: _priceFocus,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.charcoal,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 0,
                          ),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    Text(
                      'AED ${_formatCurrency(lineTotal)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    TextInputType keyboardType,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 14, color: AppColors.charcoal),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primaryBlue),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRow() {
    final double lineTotal = QuotationCalculator.calculateLineTotal(
      widget.item.unitPrice,
      widget.item.quantity,
      widget.item.discount,
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _buildImage(),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                Text(
                  '${widget.item.brand} • ${widget.item.productCode}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedText,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TextField(
              controller: _priceController,
              focusNode: _priceFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: AppColors.charcoal, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _qtyController,
              focusNode: _qtyFocus,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: AppColors.charcoal, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _discountController,
              focusNode: _discountFocus,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              style: const TextStyle(color: AppColors.charcoal, fontSize: 14),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 8,
                ),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AED ${_formatCurrency(lineTotal)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: widget.onRemove,
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: widget.item.imagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                widget.item.imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint(
                    'Product image failed: ${widget.item.imagePath} — $error',
                  );
                  return const SizedBox.shrink();
                },
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
