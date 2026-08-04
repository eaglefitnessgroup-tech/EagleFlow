import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../products/domain/product.dart';
import 'widgets/product_selection_sheet.dart';
import '../../../../core/guards/admin_guard.dart';

class StockOutScreen extends StatefulWidget {
  const StockOutScreen({super.key});

  @override
  State<StockOutScreen> createState() => _StockOutScreenState();
}

class _StockOutScreenState extends State<StockOutScreen> {
  final TextEditingController _productController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  Product? _selectedProduct;
  int? _selectedProductStock;
  bool _isLoadingStock = false;
  String? _selectedReason;
  bool _isDialogShowing = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _productController.dispose();
    _quantityController.dispose();
    _referenceController.dispose();
    _customerController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _showProductSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return const ProductSelectionSheet();
      },
    ).then((selected) {
      if (selected != null && selected is Product) {
        setState(() {
          _selectedProduct = selected;
          _productController.text = selected.name;
          _isLoadingStock = true;
          _quantityController.clear();
        });
        _fetchStockForSelectedProduct();
      }
    });
  }

  Future<void> _fetchStockForSelectedProduct() async {
    if (_selectedProduct == null) return;
    try {
      final stock = await ServiceLocator().stockController.getCurrentStock(
        _selectedProduct!,
      );
      if (mounted) {
        setState(() {
          _selectedProductStock = stock;
          _isLoadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingStock = false;
        });
      }
    }
  }

  void _showConfirmationDialog(
    int quantity,
    int availableStock,
    int remainingStock,
  ) {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    bool isSavingLocal = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Confirm Stock Out',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDialogRow('Product', _selectedProduct!.name),
                  const SizedBox(height: 8),
                  _buildDialogRow('Available Stock', '$availableStock units'),
                  const SizedBox(height: 8),
                  _buildDialogRow(
                    'Quantity Removed',
                    '-$quantity units',
                    valueColor: AppColors.statusRejectedText,
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 8),
                  _buildDialogRow(
                    'Remaining Stock',
                    '$remainingStock units',
                    isBold: true,
                  ),
                  const SizedBox(height: 16),
                  _buildDialogRow('Reason', _selectedReason ?? ''),
                  if (_referenceController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDialogRow(
                      'Reference',
                      _referenceController.text.trim(),
                    ),
                  ],
                  if (_customerController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDialogRow(
                      'Customer',
                      _customerController.text.trim(),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSavingLocal
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppColors.mutedText),
                  ),
                ),
                ElevatedButton(
                  onPressed: isSavingLocal
                      ? null
                      : () async {
                          setStateDialog(() => isSavingLocal = true);

                          final latestStock = await ServiceLocator()
                              .stockController
                              .getCurrentStock(_selectedProduct!);

                          if (latestStock < quantity) {
                            if (!context.mounted) return;
                            setStateDialog(() => isSavingLocal = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error: Only $latestStock units are available now.',
                                ),
                                backgroundColor: AppColors.statusRejectedText,
                              ),
                            );
                            _fetchStockForSelectedProduct();
                            return;
                          }

                          final parts = <String>[];
                          parts.add('Reason: ${_selectedReason!}');
                          if (_referenceController.text.trim().isNotEmpty) {
                            parts.add(_referenceController.text.trim());
                          }
                          if (_customerController.text.trim().isNotEmpty) {
                            parts.add(
                              'Customer: ${_customerController.text.trim()}',
                            );
                          }
                          if (_notesController.text.trim().isNotEmpty) {
                            parts.add('Notes: ${_notesController.text.trim()}');
                          }
                          final reference = parts.join(' | ');

                          final success = await ServiceLocator().stockController
                              .addStockOut(
                                productId: _selectedProduct!.id,
                                quantity: quantity,
                                reference: reference,
                                movementDate: DateTime.now(),
                                createdBy: 'Admin',
                              );

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Stock updated successfully.'),
                                backgroundColor: AppColors.statusApprovedText,
                              ),
                            );
                            _quantityController.clear();
                            _referenceController.clear();
                            _customerController.clear();
                            _notesController.clear();
                            setState(() {
                              _selectedReason = null;
                            });
                            _formKey.currentState?.reset();
                            if (_selectedProduct != null) {
                              _productController.text = _selectedProduct!.name;
                            }
                            _fetchStockForSelectedProduct();
                          } else {
                            setStateDialog(() => isSavingLocal = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Failed to update stock.'),
                                backgroundColor: AppColors.statusRejectedText,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isSavingLocal
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirm'),
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  Widget _buildDialogRow(
    String label,
    String value, {
    Color? valueColor,
    bool isBold = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedText, fontSize: 14),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppColors.charcoal,
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminGuard(
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text(
            'Stock Out',
            style: TextStyle(
              color: AppColors.charcoal,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.background,
          iconTheme: const IconThemeData(color: AppColors.charcoal),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              const Text(
                'PRODUCT DETAILS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.mutedText,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _productController,
                readOnly: true,
                decoration: InputDecoration(
                  hintText: 'Choose a product',
                  hintStyle: const TextStyle(color: AppColors.mutedText),
                  prefixIcon: const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColors.mutedText,
                  ),
                  suffixIcon: const Icon(
                    Icons.keyboard_arrow_down,
                    color: AppColors.mutedText,
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
                  filled: true,
                  fillColor: AppColors.surface,
                ),
                onTap: _showProductSelectionSheet,
              ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 24),
                TextFormField(
                  key: ValueKey('stock_$_selectedProductStock'),
                  initialValue: _isLoadingStock
                      ? 'Loading...'
                      : '${_selectedProductStock ?? 0} units',
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Available Stock',
                    labelStyle: const TextStyle(color: AppColors.mutedText),
                    filled: true,
                    fillColor: Colors.grey.shade100,
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
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This value updates automatically from live stock.',
                  style: TextStyle(fontSize: 12, color: AppColors.mutedText),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Enter a valid quantity greater than 0.';
                    }
                    final numValue = int.tryParse(val.trim());
                    if (numValue == null || numValue <= 0) {
                      return 'Enter a valid quantity greater than 0.';
                    }
                    if (_selectedProductStock != null &&
                        numValue > _selectedProductStock!) {
                      return 'Only ${_selectedProductStock!} units are available.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Quantity Removed *',
                    hintText: 'Enter quantity',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
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
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: _selectedReason,
                  items:
                      [
                        'Sold',
                        'Project Delivery',
                        'Showroom Transfer',
                        'Damaged',
                        'Internal Use',
                        'Stock Correction',
                        'Other',
                      ].map((String reason) {
                        return DropdownMenuItem<String>(
                          value: reason,
                          child: Text(reason),
                        );
                      }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedReason = newValue;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select a reason.';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Reason *',
                    hintText: 'Select reason',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
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
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _quantityController,
                  builder: (context, value, _) {
                    final quantityText = value.text.trim();
                    final quantity = int.tryParse(quantityText);
                    final validQuantity = (quantity != null && quantity > 0)
                        ? quantity
                        : 0;
                    final currentStock = _selectedProductStock ?? 0;
                    final newStock = currentStock - validQuantity;

                    return TextFormField(
                      key: ValueKey('new_stock_$newStock'),
                      initialValue: _isLoadingStock
                          ? 'Loading...'
                          : '$newStock units',
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Remaining Stock',
                        labelStyle: const TextStyle(color: AppColors.mutedText),
                        filled: true,
                        fillColor: Colors.grey.shade100,
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
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _referenceController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9 \-/]'),
                    ),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Reference Number',
                    hintText: 'Enter PO or reference number',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
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
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _customerController,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Customer / Destination',
                    hintText: 'Enter customer or destination',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
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
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _notesController,
                  minLines: 3,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Add any additional details',
                    hintStyle: const TextStyle(color: AppColors.mutedText),
                    alignLabelWithHint: true,
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
                      borderSide: const BorderSide(
                        color: AppColors.primaryBlue,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _quantityController,
                  builder: (context, value, _) {
                    final qty = int.tryParse(value.text.trim());
                    final currentStock = _selectedProductStock ?? 0;
                    final isValid =
                        qty != null &&
                        qty > 0 &&
                        qty <= currentStock &&
                        !_isLoadingStock &&
                        _selectedProduct != null &&
                        _selectedReason != null;

                    return SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: isValid
                            ? () {
                                final current = _selectedProductStock ?? 0;
                                _showConfirmationDialog(
                                  qty,
                                  current,
                                  current - qty,
                                );
                              }
                            : null,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text(
                          'Confirm Stock Out',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: isValid ? 2 : 0,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
