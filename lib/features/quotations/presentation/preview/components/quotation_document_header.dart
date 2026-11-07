import 'package:flutter/material.dart';
import '../../../../../core/models/company_profile.dart';
import '../quotation_document_theme.dart';
import '../quotation_layout_spec.dart';

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
              width: QuotationLayoutSpec.documentHeaderLogoWidth,
              height: QuotationLayoutSpec.documentHeaderLogoHeight,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, error, stackTrace) {
                debugPrint('Header logo failed: $error');
                return const SizedBox(
                  width: QuotationLayoutSpec.documentHeaderLogoWidth,
                  height: QuotationLayoutSpec.documentHeaderLogoHeight,
                );
              },
            ),
            const SizedBox(
              width: QuotationLayoutSpec.documentHeaderHorizontalSpacing,
            ),
            Text(
              profile.website,
              style: QuotationDocumentTheme.small.copyWith(
                color: QuotationDocumentTheme.textMuted,
              ),
              textAlign: TextAlign.right,
            ),
          ],
        ),
        const SizedBox(
          height: QuotationLayoutSpec.documentHeaderVerticalSpacing,
        ),
        const Divider(
          color: QuotationDocumentTheme.dividerColor,
          thickness: QuotationDocumentTheme.dividerThickness,
          height: QuotationDocumentTheme.dividerThickness,
        ),
        const SizedBox(
          height: QuotationLayoutSpec.documentHeaderVerticalSpacing,
        ),
      ],
    );
  }
}
