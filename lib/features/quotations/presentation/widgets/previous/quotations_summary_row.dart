import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationsSummaryRow extends StatelessWidget {
  final int totalCount;
  final int recentCount;

  const QuotationsSummaryRow({
    super.key,
    required this.totalCount,
    required this.recentCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                isMobile ? 'Total' : 'Total Quotations',
                totalCount,
                Icons.description_outlined,
                AppColors.charcoal,
              ),
            ),
            SizedBox(width: isMobile ? 12 : 16),
            Expanded(
              child: _buildSummaryCard(
                'Recent Quotations',
                recentCount,
                Icons.history,
                AppColors.primaryBlue,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    String title,
    int count,
    IconData icon,
    Color iconColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
