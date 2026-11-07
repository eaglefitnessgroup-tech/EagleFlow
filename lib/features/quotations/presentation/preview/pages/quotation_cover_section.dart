import 'package:flutter/material.dart';
import '../../../domain/quotation.dart';
import '../quotation_document_theme.dart';
import '../quotation_document_formatters.dart';
import '../../../../../core/models/company_profile.dart';
import '../components/quotation_document_header.dart';
import '../quotation_layout_spec.dart';

class QuotationCoverSection extends StatelessWidget {
  final Quotation quotation;
  final String? salespersonName;

  const QuotationCoverSection({
    super.key,
    required this.quotation,
    this.salespersonName,
  });

  @override
  Widget build(BuildContext context) {
    final profile = CompanyProfile.defaultProfile;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuotationDocumentHeader(),

        // COMPANY DETAILS
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCompanyRow('LICENSE NO', profile.licenseNumber),
                  _buildCompanyRow('LICENSE NAME', profile.legalName),
                  _buildCompanyRow(
                    'ADDRESS',
                    '${profile.addressLine1}\n${profile.addressLine2}',
                    maxLines: 2,
                  ),
                  _buildCompanyRow('MOBILE', profile.mobile),
                  _buildCompanyRow('TELEPHONE', profile.telephone),
                  _buildCompanyRow('TRN', profile.trn),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(
          height: QuotationLayoutSpec.coverCompanyToCustomerSpacing,
        ),

        // CUSTOMER & DOCUMENT INFO
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUOTATION TO', style: QuotationDocumentTheme.smallBold),
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingSpacing,
                  ),
                  Container(
                    width: 130,
                    height: QuotationLayoutSpec.coverCustomerDividerHeight,
                    alignment: Alignment.center,
                    child: Container(
                      width: 130,
                      height: QuotationDocumentTheme.dividerThickness,
                      color: QuotationDocumentTheme.dividerColor,
                    ),
                  ),
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerSpacing,
                  ),
                  _buildCustomerRow(
                    'CUSTOMER',
                    quotation.customerInfo.name.isNotEmpty
                        ? quotation.customerInfo.name
                        : '—',
                  ),
                  _buildCustomerRow(
                    'LOCATION',
                    quotation.customerInfo.projectLocation.isNotEmpty
                        ? quotation.customerInfo.projectLocation
                        : '—',
                  ),
                  _buildCustomerRow(
                    'CONTACT',
                    quotation.customerInfo.phone.isNotEmpty
                        ? quotation.customerInfo.phone
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(
              width: QuotationLayoutSpec.coverCustomerColumnSpacing,
            ),
            SizedBox(
              width: QuotationLayoutSpec.coverDocumentColumnWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingHeight,
                  ),
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerHeadingSpacing,
                  ),
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerHeight,
                  ), // Matches the 1.5px container on the left
                  const SizedBox(
                    height: QuotationLayoutSpec.coverCustomerDividerSpacing,
                  ),
                  _buildCustomerRow(
                    'DATE',
                    QuotationDocumentFormatters.formatDate(
                      quotation.createdDate,
                    ),
                  ),
                  _buildCustomerRow(
                    'QT NO',
                    quotation.displayQuotationNumber.isNotEmpty
                        ? quotation.displayQuotationNumber
                        : '—',
                  ),
                  _buildCustomerRow(
                    'EXPIRED',
                    QuotationDocumentFormatters.formatDate(
                      quotation.validUntil,
                    ),
                  ),
                  _buildCustomerRow(
                    'SALESMAN',
                    (salespersonName != null && salespersonName!.isNotEmpty)
                        ? salespersonName!
                        : (quotation.salespersonId.isNotEmpty
                              ? quotation.salespersonId
                              : '—'),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: QuotationLayoutSpec.coverBottomSpacing),
      ],
    );
  }

  Widget _buildCompanyRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: QuotationLayoutSpec.coverCompanyRowBottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: QuotationLayoutSpec.coverCompanyLabelWidth,
            child: Text(
              label,
              style: QuotationDocumentTheme.small.copyWith(
                fontSize: QuotationLayoutSpec.coverCompanyFontSize,
              ),
            ),
          ),
          Text(
            ' : ',
            style: QuotationDocumentTheme.small.copyWith(
              fontSize: QuotationLayoutSpec.coverCompanyFontSize,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: QuotationDocumentTheme.small.copyWith(
                fontSize: QuotationLayoutSpec.coverCompanyFontSize,
              ),
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: QuotationLayoutSpec.coverCustomerRowBottomPadding,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: QuotationLayoutSpec.coverCustomerLabelWidth,
            child: Text(label, style: QuotationDocumentTheme.small),
          ),
          const Text(' : ', style: QuotationDocumentTheme.small),
          Expanded(
            child: Text(
              value,
              style: QuotationDocumentTheme.smallBold,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
