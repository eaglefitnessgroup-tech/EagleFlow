import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../quotation_document_theme.dart';
import '../quotation_document_formatters.dart';
import '../../../../../core/models/company_profile.dart';
import '../components/quotation_document_header.dart';

class QuotationCoverSection extends StatelessWidget {
  final Quotation quotation;

  const QuotationCoverSection({super.key, required this.quotation});

  @override
  Widget build(BuildContext context) {
    final profile = CompanyProfile.defaultProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuotationDocumentHeader(rightTitle: 'QUOTATION'),

        // QUOTATION & COMPANY INFO
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'TL Name:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(profile.name, style: QuotationDocumentTheme.body),
                  const SizedBox(height: 4),

                  Text(
                    'TL / License No.:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(profile.licenseNo, style: QuotationDocumentTheme.body),
                  const SizedBox(height: 4),

                  Text(
                    'TRN:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(profile.trn, style: QuotationDocumentTheme.body),
                  const SizedBox(height: 4),

                  Text(
                    'Address:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(
                    profile.address,
                    style: QuotationDocumentTheme.body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  Text(
                    'Email:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(profile.email, style: QuotationDocumentTheme.body),
                  const SizedBox(height: 4),

                  Text(
                    'Telephone:',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  Text(profile.mobile, style: QuotationDocumentTheme.body),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'DOCUMENT INFO',
                    style: QuotationDocumentTheme.smallBold.copyWith(
                      color: QuotationDocumentTheme.gold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Date: ${QuotationDocumentFormatters.formatDate(quotation.createdDate)}',
                    style: QuotationDocumentTheme.body,
                  ),
                  Text(
                    'Valid Until: ${QuotationDocumentFormatters.formatDate(quotation.validUntil)}',
                    style: QuotationDocumentTheme.body,
                  ),
                  Text(
                    'Ref No: ${quotation.quotationNumber.isNotEmpty ? quotation.quotationNumber : "—"}',
                    style: QuotationDocumentTheme.body,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // CUSTOMER INFO
        Text(
          'PREPARED FOR',
          style: QuotationDocumentTheme.smallBold.copyWith(
            color: QuotationDocumentTheme.gold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          quotation.customerInfo.name.isNotEmpty
              ? quotation.customerInfo.name
              : '—',
          style: QuotationDocumentTheme.h2,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Company: ${quotation.customerInfo.company.isNotEmpty ? quotation.customerInfo.company : "—"}',
          style: QuotationDocumentTheme.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Contact: ${quotation.customerInfo.phone.isNotEmpty ? quotation.customerInfo.phone : "—"}',
          style: QuotationDocumentTheme.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Email: ${quotation.customerInfo.email.isNotEmpty ? quotation.customerInfo.email : "—"}',
          style: QuotationDocumentTheme.body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          'Project / Location: ${quotation.customerInfo.projectLocation.isNotEmpty ? quotation.customerInfo.projectLocation : "—"}',
          style: QuotationDocumentTheme.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        const SizedBox(height: 8),
      ],
    );
  }
}
