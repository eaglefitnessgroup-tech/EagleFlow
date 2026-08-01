import 'package:flutter/material.dart';
import '../../../../../core/models/company_profile.dart';
import '../quotation_document_theme.dart';

class QuotationDocumentHeader extends StatelessWidget {
  const QuotationDocumentHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = CompanyProfile.defaultProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Image.asset(
              'assets/logos/logo_head_cropped.png',
              width: 180,
              height: 42,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, stackTrace) {
                debugPrint('Header logo failed: $error');
                return const SizedBox(width: 180, height: 42);
              },
            ),
            const SizedBox(width: 16),
            Text(
              profile.website,
              style: QuotationDocumentTheme.small.copyWith(
                color: QuotationDocumentTheme.textMuted,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(
          color: QuotationDocumentTheme.border,
          thickness: 1,
          height: 1,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
