import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationStatusStrip extends StatelessWidget {
  const QuotationStatusStrip({super.key});

  @override
  Widget build(BuildContext context) {
    // Hide on very small screens
    if (MediaQuery.of(context).size.width < 600) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildStatusItem(Icons.cloud_done_outlined, 'Auto Save Active'),
          const SizedBox(width: 32),
          _buildStatusItem(Icons.restore_outlined, 'Draft Recovery Enabled'),
          const SizedBox(width: 32),
          _buildStatusItem(Icons.lock_outline, 'Secure Connection'),
        ],
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primaryBlue),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.charcoal,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
