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

        const SizedBox(height: 32),

        // CUSTOMER & DOCUMENT INFO
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('QUOTATION TO', style: QuotationDocumentTheme.smallBold),
                  const SizedBox(height: 4),
                  Container(
                    width: 130,
                    height: 1.5,
                    color: QuotationDocumentTheme.navy,
                  ),
                  const SizedBox(height: 8),
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
            const SizedBox(width: 32),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('', style: QuotationDocumentTheme.smallBold),
                  const SizedBox(height: 4),
                  const SizedBox(
                    height: 1.5,
                  ), // Matches the 1.5px container on the left
                  const SizedBox(height: 8),
                  _buildCustomerRow(
                    'DATE',
                    QuotationDocumentFormatters.formatDate(
                      quotation.createdDate,
                    ),
                  ),
                  _buildCustomerRow(
                    'QT NO',
                    quotation.quotationNumber.isNotEmpty
                        ? quotation.quotationNumber
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
                    quotation.salespersonName.isNotEmpty
                        ? quotation.salespersonName
                        : '—',
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompanyRow(String label, String value, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: QuotationDocumentTheme.small),
          ),
          const Text(' : ', style: QuotationDocumentTheme.small),
          Expanded(
            child: Text(
              value,
              style: QuotationDocumentTheme.small,
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
      padding: const EdgeInsets.only(bottom: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
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
