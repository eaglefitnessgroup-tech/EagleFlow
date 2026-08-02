import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/stock_movement.dart';

class StockAdjustmentBottomSheet extends StatefulWidget {
  final String productId;
  final StockMovementType initialType;
  final VoidCallback onSuccess;

  const StockAdjustmentBottomSheet({
    super.key,
    required this.productId,
    required this.initialType,
    required this.onSuccess,
  });

  static void show(
    BuildContext context, {
    required String productId,
    required StockMovementType initialType,
    required VoidCallback onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StockAdjustmentBottomSheet(
        productId: productId,
        initialType: initialType,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<StockAdjustmentBottomSheet> createState() =>
      _StockAdjustmentBottomSheetState();
}

class _StockAdjustmentBottomSheetState
    extends State<StockAdjustmentBottomSheet> {
  late StockMovementType _selectedType;
  final _quantityController = TextEditingController();
  final _referenceController = TextEditingController();
  final _createdByController = TextEditingController(text: 'Admin');
  DateTime _movementDate = DateTime.now();

  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _referenceController.dispose();
    _createdByController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _movementDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _movementDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    final qtyText = _quantityController.text.trim();
    final ref = _referenceController.text.trim();
    final createdBy = _createdByController.text.trim();

    if (qtyText.isEmpty || ref.isEmpty || createdBy.isEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all required fields.';
      });
      return;
    }

    final quantity = int.tryParse(qtyText);
    if (quantity == null || quantity <= 0) {
      setState(() {
        _errorMessage = 'Quantity must be a positive whole number.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final controller = ServiceLocator().stockController;
    bool success = false;

    if (_selectedType == StockMovementType.stockIn) {
      success = await controller.addStockIn(
        productId: widget.productId,
        quantity: quantity,
        reference: ref,
        movementDate: _movementDate,
        createdBy: createdBy,
      );
    } else {
      success = await controller.addStockOut(
        productId: widget.productId,
        quantity: quantity,
        reference: ref,
        movementDate: _movementDate,
        createdBy: createdBy,
      );
    }

    if (success) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedType == StockMovementType.stockIn
                  ? 'Stock In recorded successfully'
                  : 'Stock Out recorded successfully',
            ),
            backgroundColor: AppColors.statusApprovedText,
          ),
        );
        widget.onSuccess();
      }
    } else {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _errorMessage = controller.errorMessage ?? 'An error occurred.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _selectedType == StockMovementType.stockIn
                        ? 'Stock In'
                        : 'Stock Out',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.charcoal,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.statusRejectedBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: AppColors.statusRejectedText,
                      fontSize: 14,
                    ),
                  ),
                ),
              SegmentedButton<StockMovementType>(
                segments: const [
                  ButtonSegment(
                    value: StockMovementType.stockIn,
                    label: Text('Stock In'),
                    icon: Icon(Icons.add_circle_outline),
                  ),
                  ButtonSegment(
                    value: StockMovementType.stockOut,
                    label: Text('Stock Out'),
                    icon: Icon(Icons.remove_circle_outline),
                  ),
                ],
                selected: {_selectedType},
                onSelectionChanged: (Set<StockMovementType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Reference / Reason',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _selectDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Movement Date',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    '${_movementDate.year}-${_movementDate.month.toString().padLeft(2, '0')}-${_movementDate.day.toString().padLeft(2, '0')}',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _createdByController,
                decoration: const InputDecoration(
                  labelText: 'Created By',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Stock Adjustment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
