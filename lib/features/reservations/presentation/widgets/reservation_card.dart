import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/reservation.dart';
import 'package:intl/intl.dart';
import '../../../products/presentation/widgets/product_image.dart';
import '../../../products/domain/product.dart';

class ReservationCard extends StatelessWidget {
  final Reservation reservation;
  final VoidCallback? onCancel;

  const ReservationCard({
    super.key,
    required this.reservation,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    // Create a dummy product just for the image fetching since we only stored productId
    final dummyProduct = Product(
      id: reservation.productId,
      productCode: reservation.productCode,
      name: reservation.productName,
      category: '',
      brand: '',
      sellingPrice: 0.0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.border.withValues(alpha: 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: ProductImage(
                  product: dummyProduct,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorIconSize: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            reservation.productName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.charcoal,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.statusApprovedBg,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            reservation.status,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.statusApprovedText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reservation.productCode,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoColumn('Reserved Qty', '${reservation.quantity}'),
              _buildInfoColumn('Reference', reservation.reference.isNotEmpty ? reservation.reference : 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoColumn('Reserved Date', dateFormat.format(reservation.reservedDate)),
              _buildInfoColumn('Expiry Date', dateFormat.format(reservation.expiryDate)),
            ],
          ),
          if (onCancel != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Cancel Reservation',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.mutedText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.charcoal,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
