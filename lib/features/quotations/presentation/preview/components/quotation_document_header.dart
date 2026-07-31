import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../../core/models/company_profile.dart';
import '../quotation_document_theme.dart';

class QuotationDocumentHeader extends StatelessWidget {
  final String rightTitle;

  const QuotationDocumentHeader({super.key, required this.rightTitle});

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
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/logos/eagleflow_logo.svg',
                    height: 48,
                    placeholderBuilder: (context) => Text(
                      profile.brandName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: QuotationDocumentTheme.navy,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Flexible(
                    child: Text(
                      profile.brandName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: QuotationDocumentTheme.navy,
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Text(rightTitle, style: QuotationDocumentTheme.h1),
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
