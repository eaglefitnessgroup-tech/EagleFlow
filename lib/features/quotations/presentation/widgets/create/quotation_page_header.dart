import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationPageHeader extends StatelessWidget {
  final String quotationNumber;

  const QuotationPageHeader({super.key, required this.quotationNumber});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.only(top: isMobile ? 8.0 : 0.0),
          child: isMobile
              ? _buildMobileHeader(context)
              : _buildDesktopHeader(context),
        );
      },
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.charcoal),
              onPressed: () => Navigator.of(context).pop(),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Create Quotation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusPendingBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Draft',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.statusPendingText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              quotationNumber,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.charcoal,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Auto Saved',
          style: TextStyle(fontSize: 13, color: AppColors.mutedText),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.charcoal),
          onPressed: () => Navigator.of(context).pop(),
          padding: const EdgeInsets.only(top: 4, right: 8),
          alignment: Alignment.topCenter,
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create Quotation',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.statusPendingBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Draft',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.statusPendingText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    quotationNumber,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.charcoal,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Text(
                    '• Auto Saved',
                    style: TextStyle(fontSize: 13, color: AppColors.mutedText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
