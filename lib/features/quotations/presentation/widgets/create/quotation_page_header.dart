import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';

class QuotationPageHeader extends StatelessWidget {
  final String quotationNumber;
  final bool showBack;
  final VoidCallback? onBack;

  const QuotationPageHeader({
    super.key,
    required this.quotationNumber,
    this.showBack = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Padding(
          padding: EdgeInsets.only(top: isMobile ? 8.0 : 0.0),
          child: _buildHeader(context, isMobile),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, bool isMobile) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (showBack)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              key: const Key('create-quotation-back-button'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back, color: AppColors.charcoal),
              tooltip: 'Back',
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New Quotation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.charcoal,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Create a quotation and send it to your customer.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.mutedText,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          Row(
            children: [
              const Text(
                'Quotations',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.0),
                child: Icon(Icons.chevron_right, size: 16, color: AppColors.mutedText),
              ),
              const Text(
                'New Quotation',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
