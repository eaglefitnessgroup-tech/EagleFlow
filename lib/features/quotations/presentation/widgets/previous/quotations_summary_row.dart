import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationsSummaryRow extends StatelessWidget {
  final int totalCount;
  final int draftCount;
  final int sentCount;
  final int acceptedCount;

  const QuotationsSummaryRow({
    super.key,
    required this.totalCount,
    required this.draftCount,
    required this.sentCount,
    required this.acceptedCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        if (isMobile) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total',
                      totalCount,
                      Icons.description_outlined,
                      AppColors.charcoal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Draft',
                      draftCount,
                      Icons.edit_note,
                      AppColors.statusDraftText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Sent',
                      sentCount,
                      Icons.send_outlined,
                      AppColors.statusSentText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      'Accepted',
                      acceptedCount,
                      Icons.check_circle_outline,
                      AppColors.statusApprovedText,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                'Total Quotations',
                totalCount,
                Icons.description_outlined,
                AppColors.charcoal,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Draft',
                draftCount,
                Icons.edit_note,
                AppColors.statusDraftText,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Sent',
                sentCount,
                Icons.send_outlined,
                AppColors.statusSentText,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSummaryCard(
                'Accepted',
                acceptedCount,
                Icons.check_circle_outline,
                AppColors.statusApprovedText,
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
