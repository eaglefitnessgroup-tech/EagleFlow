import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/widgets/product_image.dart';
import '../../../../core/di/service_locator.dart';
import '../../domain/reservation.dart';
import 'package:uuid/uuid.dart';

class ReservationBottomSheet extends StatefulWidget {
  final Product product;

  const ReservationBottomSheet({super.key, required this.product});

  @override
  State<ReservationBottomSheet> createState() => _ReservationBottomSheetState();
}

class _ReservationBottomSheetState extends State<ReservationBottomSheet> {
  int _quantity = 1;
  final TextEditingController _referenceController = TextEditingController();

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Ensuring the bottom sheet handles the keyboard popping up
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Reserve Item',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: AppColors.mutedText),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildProductDetails(),
            const SizedBox(height: 24),
            const Text(
              'Quantity',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            _buildQuantitySelector(),
            const SizedBox(height: 20),
            const Text(
              'Reference',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.charcoal,
              ),
            ),
            const SizedBox(height: 8),
            _buildReferenceField(),
            const SizedBox(height: 32),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primarySoft.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.5),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ProductImage(
              product: widget.product,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorIconSize: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.charcoal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.product.productCode,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStockPill('Physical', widget.product.openingStock),
                    const SizedBox(width: 8),
                    _buildStockPill('Available', widget.product.openingStock),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockPill(String label, int quantity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$quantity',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantitySelector() {
    return Row(
      children: [
        InkWell(
          onTap: _decrementQuantity,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surface,
            ),
            child: const Icon(Icons.remove, size: 20, color: AppColors.charcoal),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 40,
          child: Text(
            '$_quantity',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.charcoal,
            ),
          ),
        ),
        const SizedBox(width: 16),
        InkWell(
          onTap: _incrementQuantity,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.surface,
            ),
            child: const Icon(Icons.add, size: 20, color: AppColors.charcoal),
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceField() {
    return TextField(
      controller: _referenceController,
      decoration: InputDecoration(
        hintText: 'Customer / Enquiry / Quotation',
        hintStyle: const TextStyle(color: AppColors.mutedText),
        filled: true,
        fillColor: AppColors.surface,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              foregroundColor: AppColors.charcoal,
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              final now = DateTime.now();
              final reservation = Reservation(
                id: const Uuid().v4(),
                productId: widget.product.id,
                productName: widget.product.name,
                productCode: widget.product.productCode,
                quantity: _quantity,
                reference: _referenceController.text.trim(),
                reservedDate: now,
                expiryDate: now.add(const Duration(days: 7)),
                reservedBy: ServiceLocator().authController.currentUser?.name ?? 'Unknown User',
              );

              await ServiceLocator().reservationRepository.saveReservation(reservation);

              if (mounted) {
                navigator.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                    content: Text('Reservation saved successfully.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Reserve Item',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
