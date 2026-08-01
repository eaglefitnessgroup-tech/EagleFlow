import 'package:flutter/material.dart';
import '../../../../../core/models/company_profile.dart';
import '../quotation_document_theme.dart';
import '../components/quotation_document_header.dart';

class QuotationInfoPage extends StatelessWidget {
  const QuotationInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const QuotationDocumentHeader(),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'BANK ACCOUNT DETAILS',
                style: QuotationDocumentTheme.smallBold.copyWith(
                  color: QuotationDocumentTheme.navy,
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 55,
                height: 1.5,
                color: QuotationDocumentTheme.navy,
              ),
              const SizedBox(height: 8),

              Table(
                columnWidths: const {
                  0: FlexColumnWidth(1),
                  1: FlexColumnWidth(1),
                },
                border: TableBorder(
                  verticalInside: BorderSide(
                    color: Colors.grey.shade300,
                    width: 1,
                  ),
                ),
                children: [
                  _buildTableRow(
                    'BANK NAME',
                    'Mashreq Bank',
                    'FAB / First Abu Dhabi Bank',
                  ),
                  _buildTableRow(
                    'ACCOUNT NAME',
                    CompanyProfile.defaultProfile.legalName,
                    CompanyProfile.defaultProfile.legalName,
                  ),
                  _buildTableRow(
                    'ACCOUNT NUMBER',
                    '014529018440',
                    '1103948839201',
                  ),
                  _buildTableRow(
                    'IBAN NUMBER',
                    'AE82 0330 0014 5290 1844 0',
                    'AE12 0240 0011 0394 8839 201',
                  ),
                  _buildTableRow('SWIFT CODE', 'MASHAEAD', 'NBADAEAD'),
                  _buildTableRow('CURRENCY', 'AED', 'AED'),
                ],
              ),

              const SizedBox(height: 24),
              Text('Terms & Conditions', style: QuotationDocumentTheme.h2),
              const SizedBox(height: 12),

              _buildTermsSection(
                'Payment Terms',
                '• 50% advance payment required to confirm the order.\n'
                    '• 50% balance payment required prior to delivery/installation.',
              ),
              _buildTermsSection(
                'Accepted Payment Methods',
                '• Bank Transfer (Details provided above).\n'
                    '• Cheque (Subject to clearance before delivery).',
              ),
              _buildTermsSection(
                'Additional Payment Options',
                '• Credit Card payments are subject to a 2.5% surcharge.\n'
                    '• Post-dated cheques are not accepted unless pre-approved in writing.',
              ),
              _buildTermsSection(
                'Delivery and Installation',
                '• Standard delivery timeline is 7-14 working days from receipt of advance payment.\n'
                    '• Site must be ready and cleared for installation prior to our team\'s arrival.\n'
                    '• Additional charges apply for hoisting or delivery above ground floor without service elevator access.',
              ),
              _buildTermsSection(
                'Product Warranty / Services',
                '• All equipment carries a standard 1-year warranty against manufacturing defects.\n'
                    '• Warranty does not cover normal wear and tear, misuse, or damage caused by improper maintenance.\n'
                    '• First preventative maintenance visit is complimentary within the first 6 months.',
              ),
              _buildTermsSection(
                'Returns and Refunds',
                '• Custom orders and special import items cannot be cancelled or refunded.\n'
                    '• Standard items may be returned within 7 days in original, unopened packaging, subject to a 20% restocking charge.',
              ),
              _buildTermsSection(
                'Acknowledgement & Acceptance',
                '• By issuing a Purchase Order against this quotation, the buyer agrees to all stated terms and conditions.\n'
                    '• Quotation is valid for 15 days from the date of issue.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  TableRow _buildTableRow(String label, String leftValue, String rightValue) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0, bottom: 6.0),
          child: _buildSingleBankCell(label, leftValue),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16.0, bottom: 6.0),
          child: _buildSingleBankCell(label, rightValue),
        ),
      ],
    );
  }

  Widget _buildSingleBankCell(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 95, // Fixed width for labels
          child: Text(
            label,
            style: QuotationDocumentTheme.small.copyWith(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ),
        Text(
          ':  ',
          style: QuotationDocumentTheme.smallBold.copyWith(
            color: QuotationDocumentTheme.navy,
            fontSize: 9,
            height: 1.2,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: QuotationDocumentTheme.smallBold.copyWith(
              color: Colors.black87,
              fontSize: 9,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: QuotationDocumentTheme.smallBold),
          const SizedBox(height: 2),
          Text(
            content,
            style: QuotationDocumentTheme.small.copyWith(
              fontSize: 9.6,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
