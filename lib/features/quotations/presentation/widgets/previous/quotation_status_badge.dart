import 'package:flutter/material.dart';
import '../../../../../../app/theme/app_colors.dart';
import '../../../domain/quotation_status.dart';

class QuotationStatusBadge extends StatelessWidget {
  final QuotationStatus status;

  const QuotationStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case QuotationStatus.draft:
        bgColor = AppColors.statusDraftBg;
        textColor = AppColors.statusDraftText;
        break;
      case QuotationStatus.sent:
        bgColor = AppColors.statusSentBg;
        textColor = AppColors.statusSentText;
        break;
      case QuotationStatus.approved:
        bgColor = AppColors.statusApprovedBg;
        textColor = AppColors.statusApprovedText;
        break;
      case QuotationStatus.rejected:
        bgColor = AppColors.statusRejectedBg;
        textColor = AppColors.statusRejectedText;
        break;
      case QuotationStatus.expired:
        bgColor = AppColors.statusExpiredBg;
        textColor = AppColors.statusExpiredText;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status.displayName,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
